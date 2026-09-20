import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Result of a Google Directions API driving route request.
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

/// Thrown when Directions cannot produce a usable route.
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

/// Fetches driving routes via the Google Directions API (not a fake polyline).
class DirectionsService {
  DirectionsService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKeyOverride = apiKey;

  final http.Client _client;
  final String? _apiKeyOverride;

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
    final query = <String, String>{
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'driving',
      'key': _apiKey,
    };
    if (waypoints.isNotEmpty) {
      query['waypoints'] = waypoints
          .map((w) => '${w.latitude},${w.longitude}')
          .join('|');
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      query,
    );

    final response = await _client.get(uri).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw DirectionsException(
          'Route request timed out. Check your connection and try again.',
        );
      },
    );
    if (response.statusCode != 200) {
      throw DirectionsException(
        'Directions request failed (HTTP ${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String? ?? 'UNKNOWN';

    if (status != 'OK') {
      final errorMessage = body['error_message'] as String?;
      if (kDebugMode) {
        debugPrint('Directions API status=$status error=$errorMessage');
      }
      throw DirectionsException(
        _messageForStatus(status, errorMessage),
        status: status,
      );
    }

    final routes = body['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw DirectionsException(
        'No routes returned for this trip.',
        status: status,
      );
    }

    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>? ?? const [];

    // Prefer dense per-step polylines so multi-stop routes follow roads
    // near waypoints. Overview is a lossy simplification that draws chords.
    var points = pointsFromLegs(legs);
    if (points.length < 2) {
      final overview = route['overview_polyline'] as Map<String, dynamic>?;
      final encoded = overview?['points'] as String?;
      if (encoded == null || encoded.isEmpty) {
        throw DirectionsException(
          'Route response did not include an encoded polyline.',
          status: status,
        );
      }
      points = decodePolyline(encoded);
    }
    if (points.length < 2) {
      throw DirectionsException(
        'Decoded route polyline is empty.',
        status: status,
      );
    }

    var distanceMeters = 0;
    var durationSeconds = 0;
    var distanceText = '';
    var durationText = '';

    for (final raw in legs) {
      if (raw is! Map) continue;
      final leg = Map<String, dynamic>.from(raw);
      final distance = leg['distance'] as Map<String, dynamic>?;
      final duration = leg['duration'] as Map<String, dynamic>?;
      final meters = (distance?['value'] as num?)?.round() ?? 0;
      final seconds = (duration?['value'] as num?)?.round() ?? 0;
      distanceMeters += meters;
      durationSeconds += seconds;
      if (legs.length == 1) {
        distanceText = (distance?['text'] as String?) ?? '';
        durationText = (duration?['text'] as String?) ?? '';
      }
    }
    if (legs.length > 1) {
      distanceText = _formatDistance(distanceMeters);
      durationText = _formatDuration(durationSeconds);
    }

    return DirectionsRoute(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      distanceText: distanceText,
      durationText: durationText,
    );
  }

  /// Concatenates decoded `legs[].steps[].polyline.points` in order.
  ///
  /// Duplicate consecutive points at step/leg boundaries are dropped.
  /// Returns an empty list when no usable step polylines are present.
  static List<LatLng> pointsFromLegs(List<dynamic> legs) {
    final points = <LatLng>[];

    for (final rawLeg in legs) {
      if (rawLeg is! Map) continue;
      final leg = Map<String, dynamic>.from(rawLeg);
      final steps = leg['steps'] as List<dynamic>? ?? const [];

      for (final rawStep in steps) {
        if (rawStep is! Map) continue;
        final step = Map<String, dynamic>.from(rawStep);
        final polyline = step['polyline'] as Map<String, dynamic>?;
        final encoded = polyline?['points'] as String?;
        if (encoded == null || encoded.isEmpty) continue;

        final stepPoints = decodePolyline(encoded);
        for (final point in stepPoints) {
          if (points.isNotEmpty &&
              points.last.latitude == point.latitude &&
              points.last.longitude == point.longitude) {
            continue;
          }
          points.add(point);
        }
      }
    }

    return points;
  }

  String _messageForStatus(String status, String? errorMessage) {
    switch (status) {
      case 'REQUEST_DENIED':
        return errorMessage ??
            'Directions API denied this key. Enable Directions API and allow this app.';
      case 'OVER_QUERY_LIMIT':
        return 'Directions quota exceeded. Try again later.';
      case 'ZERO_RESULTS':
        return 'No driving route found between these points.';
      case 'INVALID_REQUEST':
        return errorMessage ?? 'Invalid Directions request.';
      case 'NOT_FOUND':
        return 'Origin or destination could not be geocoded.';
      default:
        return errorMessage ?? 'Directions failed ($status).';
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
