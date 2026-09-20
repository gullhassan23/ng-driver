import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ngtowncardriver/models/ride_stop_model.dart';
import 'package:ngtowncardriver/services/ride_status_evaluator.dart';
import 'package:ngtowncardriver/utilis/firestore_paths.dart';

void main() {
  group('RideStop.listFrom', () {
    test('missing, null, and non-list values become an empty list', () {
      expect(RideStop.listFrom(null), isEmpty);
      expect(RideStop.listFrom('oops'), isEmpty);
      expect(RideStop.listFrom(42), isEmpty);
      expect(RideStop.listFrom(<dynamic>[]), isEmpty);
    });

    test('skips malformed entries and sorts by order', () {
      final stops = RideStop.listFrom([
        {
          'location': 'Second',
          'latitude': 47.61,
          'longitude': -122.34,
          'order': 2,
        },
        'not a map',
        {
          'address': 'First',
          'latitude': 47.60,
          'longitude': -122.33,
          'order': 1,
        },
        {'location': '', 'latitude': 0, 'longitude': 0, 'order': 9},
      ]);

      expect(stops, hasLength(2));
      expect(stops.first.location, 'First');
      expect(stops.first.order, 1);
      expect(stops.last.location, 'Second');
      expect(stops.last.order, 2);
    });

    test('equal order values keep Firestore array order', () {
      final stops = RideStop.listFrom([
        {
          'location': 'Alpha',
          'latitude': 47.60,
          'longitude': -122.33,
          'order': 0,
        },
        {
          'location': 'Beta',
          'latitude': 47.61,
          'longitude': -122.34,
          'order': 0,
        },
        {
          'location': 'Gamma',
          'latitude': 47.62,
          'longitude': -122.35,
          // missing order → 0
        },
      ]);

      expect(stops.map((s) => s.location).toList(), [
        'Alpha',
        'Beta',
        'Gamma',
      ]);
    });
  });

  group('RideStatusEvaluator stop progress', () {
    final evaluator = RideStatusEvaluator();
    const here = LatLng(47.6062, -122.3321);
    const nearby = LatLng(47.6064, -122.3323);
    const far = LatLng(47.62, -122.35);

    test('does not complete while remaining stops exist', () {
      expect(
        evaluator.shouldComplete(
          status: RideStatus.rideStarted,
          current: nearby,
          dropoff: here,
          hasRemainingStops: true,
        ),
        isFalse,
      );
      expect(
        evaluator.isNearDropoff(
          status: RideStatus.rideStarted,
          current: nearby,
          dropoff: here,
          hasRemainingStops: true,
        ),
        isFalse,
      );
    });

    test('completes at dropoff only after remaining stops are done', () {
      expect(
        evaluator.shouldComplete(
          status: RideStatus.rideStarted,
          current: nearby,
          dropoff: here,
          hasRemainingStops: false,
        ),
        isTrue,
      );
    });

    test('arrives at the current stop using the dropoff radius', () {
      expect(
        evaluator.shouldArriveAtStop(
          status: RideStatus.rideStarted,
          current: nearby,
          stop: here,
          hasRemainingStops: true,
        ),
        isTrue,
      );
      expect(
        evaluator.shouldArriveAtStop(
          status: RideStatus.rideStarted,
          current: far,
          stop: here,
          hasRemainingStops: true,
        ),
        isFalse,
      );
      expect(
        evaluator.shouldArriveAtStop(
          status: RideStatus.rideStarted,
          current: nearby,
          stop: here,
          hasRemainingStops: false,
        ),
        isFalse,
      );
      expect(
        evaluator.shouldArriveAtStop(
          status: RideStatus.driverArriving,
          current: nearby,
          stop: here,
          hasRemainingStops: true,
        ),
        isFalse,
      );
    });
  });
}
