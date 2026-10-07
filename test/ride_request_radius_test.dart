import 'package:flutter_test/flutter_test.dart';
import 'package:ngtowncardriver/utilis/geo.dart';

void main() {
  group('1-mile Ride Request Radius Tests', () {
    test('rideRequestRadiusMiles is 1.0', () {
      expect(rideRequestRadiusMiles, equals(1.0));
    });

    test('Same coordinates yield 0 miles and are within radius', () {
      final distance = milesBetween(47.6062, -122.3321, 47.6062, -122.3321);
      expect(distance, equals(0.0));
      expect(distance <= rideRequestRadiusMiles, isTrue);
    });

    test('Short distance within 1.0 mile is allowed', () {
      // ~0.5 miles north in Seattle (1 deg lat ~ 69 miles, 0.0072 deg ~ 0.5 miles)
      final distance = milesBetween(47.6062, -122.3321, 47.6134, -122.3321);
      expect(distance, lessThan(1.0));
      expect(distance <= rideRequestRadiusMiles, isTrue);
    });

    test('Distance beyond 1.0 mile is rejected', () {
      // ~2.0 miles north in Seattle (0.029 deg lat ~ 2.0 miles)
      final distance = milesBetween(47.6062, -122.3321, 47.6352, -122.3321);
      expect(distance, greaterThan(1.0));
      expect(distance <= rideRequestRadiusMiles, isFalse);
    });

    test('Exactly 1.0 mile boundary condition check (<= 1.0 is eligible)', () {
      // 1.0 miles is <= 1.0
      expect(1.0 <= rideRequestRadiusMiles, isTrue);
      expect(1.0001 <= rideRequestRadiusMiles, isFalse);
      expect(0.9999 <= rideRequestRadiusMiles, isTrue);
    });
  });
}
