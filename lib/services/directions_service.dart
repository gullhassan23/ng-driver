import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Result of a Google Routes API driving route request.
class DirectionsRoute {
  const DirectionsRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceText,
    required this.durationText,
  });

  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;
  final String distanceText;
  final String durationText;
}

/// Thrown when Routes cannot produce a usable route.
class DirectionsException implements Exception {
  DirectionsException(this.message, {this.status});

  final String message;
  final String? status;

  @override
  String toString() => message;
}

class _CachedDirectionsRoute {
  const _CachedDirectionsRoute(this.route, this.cachedAt);

  final DirectionsRoute route;
  final DateTime cachedAt;
}

/// Fetches driving routes via the Google Routes API (`computeRoutes`).
///
/// Requires the **Routes API** enabled on the Cloud project for [AppConfig]
/// / the injected API key — not the legacy Directions API.
class DirectionsService {
  DirectionsService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKeyOverride = apiKey;

  final http.Client _client;
  final String? _apiKeyOverride;

  static const String _computeRoutesPath = '/directions/v2:computeRoutes';
  static const String _fieldMask =
      'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,'
      'routes.legs.distanceMeters,routes.legs.duration,'
      'routes.legs.polyline.encodedPolyline';

  /// Short-lived in-memory cache so preview → active ride can reuse geometry.
  static const Duration routeCacheTtl = Duration(seconds: 75);
  static const int _maxCacheEntries = 8;
  final Map<String, _CachedDirectionsRoute> _routeCache = {};

  String get _apiKey {
    final key = (_apiKeyOverride ?? AppConfig.googleMapsApiKey).trim();
    if (key.isEmpty) {
      throw DirectionsException(
        'Maps is not configured. Contact support if this continues.',
      );
    }
    return key;
  }

  /// Cache key for origin → destination (+ ordered waypoints).
  static String routeCacheKey({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) {
    String fmt(LatLng p) =>
        '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';
    final wp = waypoints.map(fmt).join('|');
    return '${fmt(origin)}>${fmt(destination)}${wp.isEmpty ? '' : '|$wp'}';
  }

  /// Clears cached routes (e.g. after a phase change that needs a fresh path).
  void clearRouteCache() => _routeCache.clear();

  /// Requests a driving route from [origin] to [destination].
  ///
  /// Optional [waypoints] are visited in order (never optimized).
  /// Distance and duration are the **sum of all legs**.
  ///
  /// Successful responses are cached briefly so accept-after-preview does not
  /// re-hit the network for the same geometry.
  Future<DirectionsRoute> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    bool bypassCache = false,
  }) async {
    final cacheKey = routeCacheKey(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
    );

    if (!bypassCache) {
      final cached = _routeCache[cacheKey];
      if (cached != null &&
          DateTime.now().difference(cached.cachedAt) < routeCacheTtl) {
        return cached.route;
      }
    }

    final route = await _fetchDrivingRoute(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
    );
    _putRouteCache(cacheKey, route);
    return route;
  }

  void _putRouteCache(String key, DirectionsRoute route) {
    if (_routeCache.length >= _maxCacheEntries) {
      final oldestKey = _routeCache.entries
          .reduce((a, b) => a.value.cachedAt.isBefore(b.value.cachedAt) ? a : b)
          .key;
      _routeCache.remove(oldestKey);
    }
    _routeCache[key] = _CachedDirectionsRoute(route, DateTime.now());
  }

  Future<DirectionsRoute> _fetchDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    final body = <String, dynamic>{
      'origin': _waypoint(origin),
      'destination': _waypoint(destination),
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
      'computeAlternativeRoutes': false,
      'languageCode': 'en-US',
      'units': 'IMPERIAL',
    };
    if (waypoints.isNotEmpty) {
      body['intermediates'] = waypoints.map(_waypoint).toList();
    }

    final uri = Uri.https('routes.googleapis.com', _computeRoutesPath);

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': _fieldMask,
          },
          body: jsonEncode(body),
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw DirectionsException(
              'Route request timed out. Check your connection and try again.',
            );
          },
        );

    if (response.statusCode != 200) {
      throw DirectionsException(
        _messageForHttpError(response.statusCode, response.body),
        status: 'HTTP_${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw DirectionsException('Unexpected Routes API response.');
    }

    final routes = decoded['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw DirectionsException(
        'No driving route found between these points.',
        status: 'ZERO_RESULTS',
      );
    }

    final route = routes.first;
    if (route is! Map) {
      throw DirectionsException('Unexpected Routes API route shape.');
    }
    final routeMap = Map<String, dynamic>.from(route);
    final legs = routeMap['legs'] as List<dynamic>? ?? const [];

    // Prefer dense per-leg polylines when present; overview is a simplification.
    var points = pointsFromLegs(legs);
    if (points.length < 2) {
      final polyline = routeMap['polyline'] as Map<String, dynamic>?;
      final encoded = polyline?['encodedPolyline'] as String?;
      if (encoded == null || encoded.isEmpty) {
        throw DirectionsException(
          'Route response did not include an encoded polyline.',
        );
      }
      points = decodePolyline(encoded);
    }
    if (points.length < 2) {
      throw DirectionsException('Decoded route polyline is empty.');
    }

    var distanceMeters = 0;
    var durationSeconds = 0;

    for (final raw in legs) {
      if (raw is! Map) continue;
      final leg = Map<String, dynamic>.from(raw);
      distanceMeters += (leg['distanceMeters'] as num?)?.round() ?? 0;
      durationSeconds += parseDurationSeconds(leg['duration']);
    }

    if (distanceMeters <= 0) {
      distanceMeters = (routeMap['distanceMeters'] as num?)?.round() ?? 0;
    }
    if (durationSeconds <= 0) {
      durationSeconds = parseDurationSeconds(routeMap['duration']);
    }

    return DirectionsRoute(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      distanceText: _formatDistance(distanceMeters),
      durationText: _formatDuration(durationSeconds),
    );
  }

  static Map<String, dynamic> _waypoint(LatLng point) {
    return {
      'location': {
        'latLng': {
          'latitude': point.latitude,
          'longitude': point.longitude,
        },
      },
    };
  }

  /// Concatenates decoded `legs[].polyline.encodedPolyline` in order.
  ///
  /// Duplicate consecutive points at leg boundaries are dropped.
  /// Returns an empty list when no usable leg polylines are present.
  static List<LatLng> pointsFromLegs(List<dynamic> legs) {
    final points = <LatLng>[];

    for (final rawLeg in legs) {
      if (rawLeg is! Map) continue;
      final leg = Map<String, dynamic>.from(rawLeg);
      final polyline = leg['polyline'] as Map<String, dynamic>?;
      final encoded = polyline?['encodedPolyline'] as String?;
      if (encoded == null || encoded.isEmpty) continue;

      final legPoints = decodePolyline(encoded);
      for (final point in legPoints) {
        if (points.isNotEmpty &&
            points.last.latitude == point.latitude &&
            points.last.longitude == point.longitude) {
          continue;
        }
        points.add(point);
      }
    }

    return points;
  }

  /// Parses Routes API duration values (`"165s"`, int seconds, or num).
  static int parseDurationSeconds(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.round();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.endsWith('s')) {
        return double.tryParse(trimmed.substring(0, trimmed.length - 1))
                ?.round() ??
            0;
      }
      return double.tryParse(trimmed)?.round() ?? 0;
    }
    return 0;
  }

  String _messageForHttpError(int statusCode, String body) {
    String? apiMessage;
    String? status;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          apiMessage = error['message'] as String?;
          status = error['status'] as String?;
        }
      }
    } catch (_) {
      // Ignore malformed error bodies; use status-based fallback below.
    }

    if (kDebugMode && (apiMessage != null || status != null)) {
      debugPrint('Routes API HTTP $statusCode status=$status error=$apiMessage');
    }

    switch (statusCode) {
      case 400:
        return apiMessage ?? 'Invalid route request.';
      case 403:
        return apiMessage ??
            'Routes API denied this key. Enable Routes API and allow this app.';
      case 404:
        return apiMessage ?? 'No driving route found between these points.';
      case 429:
        return 'Routes quota exceeded. Try again later.';
      default:
        if (apiMessage != null && apiMessage.isNotEmpty) return apiMessage;
        return 'Route request failed (HTTP $statusCode).';
    }
  }

  static String _formatDistance(int meters) {
    if (meters <= 0) return '';
    final miles = meters / 1609.34;
    if (miles < 0.1) return '$meters m';
    return '${miles.toStringAsFixed(1)} mi';
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '${minutes.clamp(1, 59)} min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (remainder == 0) return '${hours}h';
    return '${hours}h $remainder min';
  }

  /// Decodes a Google encoded polyline into [LatLng] points.
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
