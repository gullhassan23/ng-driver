import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ngtowncardriver/services/directions_service.dart';

void main() {
  group('DirectionsService.pointsFromLegs', () {
    test('concatenates leg polylines and drops boundary duplicates', () {
      final legA = encodePolyline(const [
        LatLng(47.60, -122.33),
        LatLng(47.61, -122.34),
      ]);
      final legB = encodePolyline(const [
        LatLng(47.61, -122.34), // duplicate of previous leg end
        LatLng(47.62, -122.35),
        LatLng(47.63, -122.36),
      ]);
      final legC = encodePolyline(const [
        LatLng(47.63, -122.36),
        LatLng(47.64, -122.37),
      ]);

      final points = DirectionsService.pointsFromLegs([
        {
          'polyline': {'encodedPolyline': legA},
        },
        {
          'polyline': {'encodedPolyline': legB},
        },
        {
          'polyline': {'encodedPolyline': legC},
        },
      ]);

      expect(points, hasLength(5));
      expect(points.first, const LatLng(47.60, -122.33));
      expect(points[1], const LatLng(47.61, -122.34));
      expect(points[2], const LatLng(47.62, -122.35));
      expect(points[3], const LatLng(47.63, -122.36));
      expect(points.last, const LatLng(47.64, -122.37));
    });

    test('returns empty when legs have no polylines', () {
      expect(
        DirectionsService.pointsFromLegs([
          {
            'distanceMeters': 100,
          },
        ]),
        isEmpty,
      );
      expect(DirectionsService.pointsFromLegs(const []), isEmpty);
    });
  });

  group('DirectionsService.parseDurationSeconds', () {
    test('parses duration strings and numbers', () {
      expect(DirectionsService.parseDurationSeconds('165s'), 165);
      expect(DirectionsService.parseDurationSeconds('90.4s'), 90);
      expect(DirectionsService.parseDurationSeconds(120), 120);
      expect(DirectionsService.parseDurationSeconds(null), 0);
    });
  });

  group('DirectionsService.getDrivingRoute', () {
    test('uses concatenated leg geometry instead of sparse overview', () async {
      final dense = encodePolyline(const [
        LatLng(47.60, -122.33),
        LatLng(47.605, -122.335),
        LatLng(47.61, -122.34),
        LatLng(47.615, -122.345),
        LatLng(47.62, -122.35),
      ]);
      // Overview deliberately omits intermediate road points.
      final sparseOverview = encodePolyline(const [
        LatLng(47.60, -122.33),
        LatLng(47.62, -122.35),
      ]);
      final secondLeg = encodePolyline(const [
        LatLng(47.62, -122.35),
        LatLng(47.625, -122.355),
        LatLng(47.63, -122.36),
      ]);

      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.host, 'routes.googleapis.com');
        expect(request.url.path, '/directions/v2:computeRoutes');
        expect(request.headers['X-Goog-Api-Key'], 'test-key');
        expect(
          request.headers['X-Goog-FieldMask'],
          contains('routes.polyline.encodedPolyline'),
        );

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['travelMode'], 'DRIVE');
        expect(body['origin'], {
          'location': {
            'latLng': {'latitude': 47.60, 'longitude': -122.33},
          },
        });
        expect(body['destination'], {
          'location': {
            'latLng': {'latitude': 47.62, 'longitude': -122.35},
          },
        });
        expect(body['intermediates'], [
          {
            'location': {
              'latLng': {'latitude': 47.61, 'longitude': -122.34},
            },
          },
        ]);

        return http.Response(
          jsonEncode({
            'routes': [
              {
                'distanceMeters': 900,
                'duration': '210s',
                'polyline': {'encodedPolyline': sparseOverview},
                'legs': [
                  {
                    'distanceMeters': 500,
                    'duration': '120s',
                    'polyline': {'encodedPolyline': dense},
                  },
                  {
                    'distanceMeters': 400,
                    'duration': '90s',
                    'polyline': {'encodedPolyline': secondLeg},
                  },
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = DirectionsService(client: client, apiKey: 'test-key');
      final route = await service.getDrivingRoute(
        origin: const LatLng(47.60, -122.33),
        destination: const LatLng(47.62, -122.35),
        waypoints: const [LatLng(47.61, -122.34)],
      );

      expect(route.points.length, greaterThan(2));
      expect(route.points, isNot(equals(const [
        LatLng(47.60, -122.33),
        LatLng(47.62, -122.35),
      ])));
      expect(route.points.first, const LatLng(47.60, -122.33));
      expect(route.points.last, const LatLng(47.63, -122.36));
      expect(route.distanceMeters, 900);
      expect(route.durationSeconds, 210);
      expect(route.distanceText, isNotEmpty);
      expect(route.durationText, isNotEmpty);
    });

    test('falls back to overview when legs have no polylines', () async {
      final overview = encodePolyline(const [
        LatLng(47.60, -122.33),
        LatLng(47.61, -122.34),
        LatLng(47.62, -122.35),
      ]);

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'distanceMeters': 1000,
                'duration': '300s',
                'polyline': {'encodedPolyline': overview},
                'legs': [
                  {
                    'distanceMeters': 1000,
                    'duration': '300s',
                  },
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = DirectionsService(client: client, apiKey: 'test-key');
      final route = await service.getDrivingRoute(
        origin: const LatLng(47.60, -122.33),
        destination: const LatLng(47.62, -122.35),
      );

      expect(route.points, hasLength(3));
      expect(route.points[1], const LatLng(47.61, -122.34));
      expect(route.distanceMeters, 1000);
      expect(route.durationSeconds, 300);
      expect(route.durationText, '5 min');
    });

    test('passes multiple waypoints as ordered intermediates', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        final overview = encodePolyline(const [
          LatLng(1, 1),
          LatLng(2, 2),
        ]);
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'distanceMeters': 50,
                'duration': '30s',
                'polyline': {'encodedPolyline': overview},
                'legs': const [],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = DirectionsService(client: client, apiKey: 'test-key');
      await service.getDrivingRoute(
        origin: const LatLng(47.60, -122.33),
        destination: const LatLng(47.65, -122.40),
        waypoints: const [
          LatLng(47.61, -122.34),
          LatLng(47.62, -122.35),
        ],
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['intermediates'], [
        {
          'location': {
            'latLng': {'latitude': 47.61, 'longitude': -122.34},
          },
        },
        {
          'location': {
            'latLng': {'latitude': 47.62, 'longitude': -122.35},
          },
        },
      ]);
      expect(capturedBody!.containsKey('optimizeWaypointOrder'), isFalse);
    });

    test('maps HTTP errors to DirectionsException', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 403,
              'message':
                  'You’re calling a legacy API, which is not enabled for your project.',
              'status': 'PERMISSION_DENIED',
            },
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = DirectionsService(client: client, apiKey: 'test-key');
      expect(
        () => service.getDrivingRoute(
          origin: const LatLng(47.60, -122.33),
          destination: const LatLng(47.61, -122.34),
        ),
        throwsA(
          isA<DirectionsException>().having(
            (e) => e.message,
            'message',
            contains('legacy API'),
          ),
        ),
      );
    });

    test('reuses short-lived cache for identical geometry', () async {
      var hits = 0;
      final dense = encodePolyline(const [
        LatLng(47.60, -122.33),
        LatLng(47.61, -122.34),
      ]);
      final client = MockClient((request) async {
        hits++;
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'distanceMeters': 100,
                'duration': '60s',
                'polyline': {'encodedPolyline': dense},
                'legs': [
                  {
                    'distanceMeters': 100,
                    'duration': '60s',
                    'polyline': {'encodedPolyline': dense},
                  },
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = DirectionsService(client: client, apiKey: 'test-key');
      const origin = LatLng(47.60, -122.33);
      const destination = LatLng(47.61, -122.34);

      final first = await service.getDrivingRoute(
        origin: origin,
        destination: destination,
      );
      final second = await service.getDrivingRoute(
        origin: origin,
        destination: destination,
      );
      final bypassed = await service.getDrivingRoute(
        origin: origin,
        destination: destination,
        bypassCache: true,
      );

      expect(hits, 2);
      expect(identical(first.points, second.points), isTrue);
      expect(bypassed.points, hasLength(2));
    });
  });
}

/// Encodes [points] with the Google Encoded Polyline Algorithm Format.
String encodePolyline(List<LatLng> points) {
  final buffer = StringBuffer();
  var prevLat = 0;
  var prevLng = 0;

  for (final point in points) {
    final lat = (point.latitude * 1e5).round();
    final lng = (point.longitude * 1e5).round();
    buffer
      ..write(_encodeSigned(lat - prevLat))
      ..write(_encodeSigned(lng - prevLng));
    prevLat = lat;
    prevLng = lng;
  }

  return buffer.toString();
}

String _encodeSigned(int value) {
  var v = value < 0 ? ~(value << 1) : (value << 1);
  final out = StringBuffer();
  while (v >= 0x20) {
    out.writeCharCode(((v & 0x1f) | 0x20) + 63);
    v >>= 5;
  }
  out.writeCharCode(v + 63);
  return out.toString();
}
