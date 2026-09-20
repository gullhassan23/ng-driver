import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ngtowncardriver/services/directions_service.dart';

void main() {
  group('DirectionsService.pointsFromLegs', () {
    test('concatenates step polylines and drops boundary duplicates', () {
      final stepA = encodePolyline(const [
        LatLng(47.60, -122.33),
        LatLng(47.61, -122.34),
      ]);
      final stepB = encodePolyline(const [
        LatLng(47.61, -122.34), // duplicate of previous step end
        LatLng(47.62, -122.35),
        LatLng(47.63, -122.36),
      ]);
      final stepC = encodePolyline(const [
        LatLng(47.63, -122.36),
        LatLng(47.64, -122.37),
      ]);

      final points = DirectionsService.pointsFromLegs([
        {
          'steps': [
            {
              'polyline': {'points': stepA},
            },
            {
              'polyline': {'points': stepB},
            },
          ],
        },
        {
          'steps': [
            {
              'polyline': {'points': stepC},
            },
          ],
        },
      ]);

      expect(points, hasLength(5));
      expect(points.first, const LatLng(47.60, -122.33));
      expect(points[1], const LatLng(47.61, -122.34));
      expect(points[2], const LatLng(47.62, -122.35));
      expect(points[3], const LatLng(47.63, -122.36));
      expect(points.last, const LatLng(47.64, -122.37));
    });

    test('returns empty when steps have no polylines', () {
      expect(
        DirectionsService.pointsFromLegs([
          {
            'steps': [
              {'distance': {'value': 100}},
            ],
          },
        ]),
        isEmpty,
      );
      expect(DirectionsService.pointsFromLegs(const []), isEmpty);
    });
  });

  group('DirectionsService.getDrivingRoute', () {
    test('uses concatenated step geometry instead of sparse overview', () async {
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

      final client = MockClient((request) async {
        expect(request.url.path, '/maps/api/directions/json');
        expect(request.url.queryParameters['waypoints'], '47.61,-122.34');
        expect(request.url.queryParameters['origin'], '47.6,-122.33');
        expect(request.url.queryParameters['destination'], '47.62,-122.35');

        return http.Response(
          jsonEncode({
            'status': 'OK',
            'routes': [
              {
                'overview_polyline': {'points': sparseOverview},
                'legs': [
                  {
                    'distance': {'value': 500, 'text': '0.3 mi'},
                    'duration': {'value': 120, 'text': '2 mins'},
                    'steps': [
                      {
                        'polyline': {'points': dense},
                      },
                    ],
                  },
                  {
                    'distance': {'value': 400, 'text': '0.2 mi'},
                    'duration': {'value': 90, 'text': '1 min'},
                    'steps': [
                      {
                        'polyline': {
                          'points': encodePolyline(const [
                            LatLng(47.62, -122.35),
                            LatLng(47.625, -122.355),
                            LatLng(47.63, -122.36),
                          ]),
                        },
                      },
                    ],
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

    test('falls back to overview when legs have no step polylines', () async {
      final overview = encodePolyline(const [
        LatLng(47.60, -122.33),
        LatLng(47.61, -122.34),
        LatLng(47.62, -122.35),
      ]);

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'routes': [
              {
                'overview_polyline': {'points': overview},
                'legs': [
                  {
                    'distance': {'value': 1000, 'text': '0.6 mi'},
                    'duration': {'value': 300, 'text': '5 mins'},
                    'steps': [
                      {'html_instructions': 'Head north'},
                    ],
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
      expect(route.durationText, '5 mins');
    });

    test('passes multiple waypoints in rider order without optimize', () async {
      Uri? captured;
      final client = MockClient((request) async {
        captured = request.url;
        final overview = encodePolyline(const [
          LatLng(1, 1),
          LatLng(2, 2),
        ]);
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'routes': [
              {
                'overview_polyline': {'points': overview},
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

      expect(captured, isNotNull);
      expect(
        captured!.queryParameters['waypoints'],
        '47.61,-122.34|47.62,-122.35',
      );
      expect(captured!.queryParameters['waypoints'], isNot(contains('optimize')));
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
            'status': 'OK',
            'routes': [
              {
                'overview_polyline': {'points': dense},
                'legs': [
                  {
                    'distance': {'value': 100, 'text': '0.1 mi'},
                    'duration': {'value': 60, 'text': '1 min'},
                    'steps': [
                      {
                        'polyline': {'points': dense},
                      },
                    ],
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
