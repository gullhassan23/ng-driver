import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Outcome of checking device GPS + runtime location permission.
enum LocationReadiness {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

/// Checks device location services and runtime permission for going online.
class LocationService {
  /// Temporary: hardcode driver GPS to downtown Seattle for polyline / accept
  /// testing. Release builds always use real GPS.
  static bool get useStaticSeattleLocation =>
      kDebugMode && _debugUseStaticSeattleLocation;

  static const bool _debugUseStaticSeattleLocation = false;

  /// Downtown Seattle — used when [useStaticSeattleLocation] is true / fallback.
  static const LatLng seattleLatLng = LatLng(47.6062, -122.3321);

  /// Last successful fix from this process (quick seed for map camera).
  static LatLng? _cachedPosition;
  static DateTime? _cachedAt;

  /// Most recent known position from [getPositionQuick] / [getCurrentPosition]
  /// / [cachePosition]. Used to seed map camera without waiting on GPS.
  LatLng? get cachedPosition =>
      useStaticSeattleLocation ? seattleLatLng : _cachedPosition;

  /// Age of [cachedPosition], or null when unknown.
  Duration? get cachedPositionAge {
    if (useStaticSeattleLocation) return Duration.zero;
    final at = _cachedAt;
    if (at == null || _cachedPosition == null) return null;
    return DateTime.now().difference(at);
  }

  /// True when cache exists and is newer than [maxAge].
  bool hasFreshCache({Duration maxAge = const Duration(seconds: 60)}) {
    final age = cachedPositionAge;
    return age != null && age <= maxAge;
  }

  void cachePosition(LatLng position) {
    if (useStaticSeattleLocation) return;
    _cachedPosition = position;
    _cachedAt = DateTime.now();
  }

  static Position get _seattlePosition => Position(
        latitude: seattleLatLng.latitude,
        longitude: seattleLatLng.longitude,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  /// Checks services + permission. Requests permission only when soft-denied
  /// and [requestIfDenied] is true. Never re-prompts when already granted.
  Future<LocationReadiness> ensureReadyForOnline({
    bool requestIfDenied = true,
  }) async {
    if (useStaticSeattleLocation) return LocationReadiness.ready;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationReadiness.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();

    if (requestIfDenied && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationReadiness.permissionDeniedForever;
    }

    if (permission == LocationPermission.denied) {
      return LocationReadiness.permissionDenied;
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      return LocationReadiness.ready;
    }

    return LocationReadiness.permissionDenied;
  }

  /// Current device position when permission/services allow it.
  Future<LatLng?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    bool requestIfDenied = true,
  }) async {
    if (useStaticSeattleLocation) return seattleLatLng;

    final readiness = await ensureReadyForOnline(
      requestIfDenied: requestIfDenied,
    );
    if (readiness != LocationReadiness.ready) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      cachePosition(latLng);
      return latLng;
    } catch (_) {
      return cachedPosition;
    }
  }

  /// Fast position for accept flows: last-known first, then a short
  /// medium-accuracy fix. Returns null instead of hanging on GPS.
  ///
  /// When [maxCacheAge] is set, cached/last-known older than that are skipped
  /// in favor of a fresh fix (still falls back to stale cache if GPS fails).
  Future<LatLng?> getPositionQuick({
    Duration timeout = const Duration(seconds: 2),
    Duration maxCacheAge = const Duration(seconds: 60),
  }) async {
    if (useStaticSeattleLocation) return seattleLatLng;

    if (_cachedPosition != null && hasFreshCache(maxAge: maxCacheAge)) {
      final readiness = await ensureReadyForOnline(requestIfDenied: false);
      if (readiness == LocationReadiness.ready) return _cachedPosition;
    }

    final readiness = await ensureReadyForOnline(requestIfDenied: false);
    if (readiness != LocationReadiness.ready) return null;

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final age = DateTime.now().difference(last.timestamp);
        if (age <= maxCacheAge) {
          final latLng = LatLng(last.latitude, last.longitude);
          cachePosition(latLng);
          return latLng;
        }
      }
    } catch (_) {}

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(timeout);
      final latLng = LatLng(position.latitude, position.longitude);
      cachePosition(latLng);
      return latLng;
    } catch (_) {
      return cachedPosition;
    }
  }

  /// Live position updates for navigation (caller must cancel the subscription).
  ///
  /// On Android, starts a location foreground service so tracking continues
  /// while the driver backgrounds the app during an active trip.
  Stream<Position> positionStream({
    int distanceFilterMeters = 15,
    bool enableBackground = false,
  }) {
    if (useStaticSeattleLocation) {
      return Stream.periodic(
        const Duration(seconds: 5),
        (_) => _seattlePosition,
      ).asBroadcastStream();
    }

    late final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android && enableBackground) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'NG Town Driver',
          notificationText: 'Sharing your location during the trip',
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS &&
        enableBackground) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: distanceFilterMeters,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      );
    }

    return Geolocator.getPositionStream(locationSettings: settings);
  }

  Future<bool> isPermanentlyDenied() async {
    if (useStaticSeattleLocation) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.deniedForever;
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Reverse-geocodes [position] via Google Geocoding API.
  /// Returns an empty string when the lookup fails.
  Future<String> reverseGeocodeAddress(LatLng position) async {
    final apiKey = AppConfig.googleMapsApiKey;
    if (apiKey.isEmpty) return '';

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'latlng': '${position.latitude},${position.longitude}',
          'key': apiKey,
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return '';

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') return '';

      final results = body['results'] as List<dynamic>? ?? const [];
      if (results.isEmpty) return '';

      final first = results.first as Map<String, dynamic>;
      return (first['formatted_address'] as String?)?.trim() ?? '';
    } catch (error) {
      if (kDebugMode) {
        debugPrint('reverseGeocodeAddress failed: $error');
      }
      return '';
    }
  }
}
