import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utilis/firestore_paths.dart';

/// Configurable proximity / movement thresholds for the ride lifecycle.
class RideLifecycleConfig {
  const RideLifecycleConfig({
    this.movementThresholdMeters = 25.0,
    // Urban GPS noise often needs >50m; 80m is more reliable for arrival.
    this.pickupArrivalRadiusMeters = 80.0,
    this.dropoffArrivalRadiusMeters = 50.0,
  });

  /// Distance the driver must move from the accepted-session GPS anchor
  /// before `accepted` → `driver_arriving`.
  final double movementThresholdMeters;

  /// Radius around pickup that triggers `driver_arriving` → `driver_arrived`.
  final double pickupArrivalRadiusMeters;

  /// Radius around dropoff that triggers `ride_started` → `completed`.
  /// Also used for intermediate-stop arrival.
  final double dropoffArrivalRadiusMeters;

  static const RideLifecycleConfig defaults = RideLifecycleConfig();
}

/// Pure evaluation helpers for GPS-driven ride status transitions.
///
/// No Firestore, streams, or GetX — callers perform guarded writes.
class RideStatusEvaluator {
  RideStatusEvaluator({
    this.config = RideLifecycleConfig.defaults,
  });

  final RideLifecycleConfig config;

  double distanceMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  double? distanceToPickup(LatLng current, LatLng? pickup) {
    if (pickup == null) return null;
    return distanceMeters(current, pickup);
  }

  double? distanceToDropoff(LatLng current, LatLng? dropoff) {
    if (dropoff == null) return null;
    return distanceMeters(current, dropoff);
  }

  /// `driver_selected` / legacy `accepted` → `driver_arriving` when the driver
  /// has moved enough from the session anchor, or is already inside the pickup
  /// arrival radius (accept-while-already-at-pickup edge case).
  bool shouldBecomeArriving({
    required String status,
    required LatLng current,
    LatLng? acceptedAnchor,
    LatLng? pickup,
  }) {
    if (!RideStatus.isPreArrivingAssignedStatus(status)) return false;

    final toPickup = distanceToPickup(current, pickup);
    if (toPickup != null && toPickup <= config.pickupArrivalRadiusMeters) {
      return true;
    }

    if (acceptedAnchor == null) return false;
    final moved = distanceMeters(acceptedAnchor, current);
    return moved >= config.movementThresholdMeters;
  }

  /// `driver_arriving` → `driver_arrived` when within pickup radius.
  bool shouldBecomeArrived({
    required String status,
    required LatLng current,
    LatLng? pickup,
  }) {
    if (status != RideStatus.driverArriving) return false;
    final toPickup = distanceToPickup(current, pickup);
    if (toPickup == null) return false;
    return toPickup <= config.pickupArrivalRadiusMeters;
  }

  /// In-trip GPS arrival at the current intermediate stop.
  ///
  /// Reuses the dropoff radius. Never true when there are no remaining stops.
  bool shouldArriveAtStop({
    required String status,
    required LatLng current,
    LatLng? stop,
    required bool hasRemainingStops,
  }) {
    if (!hasRemainingStops) return false;
    if (!RideStatus.isTripInProgressStatus(status)) return false;
    if (stop == null) return false;
    return distanceMeters(current, stop) <= config.dropoffArrivalRadiusMeters;
  }

  /// `ride_started` / legacy `inProgress` → `completed` when within dropoff
  /// radius and no intermediate stops remain.
  bool shouldComplete({
    required String status,
    required LatLng current,
    LatLng? dropoff,
    bool hasRemainingStops = false,
  }) {
    if (hasRemainingStops) return false;
    if (!RideStatus.isTripInProgressStatus(status)) return false;
    final toDropoff = distanceToDropoff(current, dropoff);
    if (toDropoff == null) return false;
    return toDropoff <= config.dropoffArrivalRadiusMeters;
  }

  bool isNearDropoff({
    required String status,
    required LatLng current,
    LatLng? dropoff,
    bool hasRemainingStops = false,
  }) {
    if (hasRemainingStops) return false;
    if (!RideStatus.isTripInProgressStatus(status)) return false;
    final toDropoff = distanceToDropoff(current, dropoff);
    if (toDropoff == null) return false;
    return toDropoff <= config.dropoffArrivalRadiusMeters;
  }
}
