import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utilis/firestore_paths.dart';
import 'ride_stop_model.dart';

/// Document from the shared `rides` collection.
class RideModel {
  final String id;
  final String rideId;
  final String customerId;
  final String customerName;

  final double estimatedFare;
  final double totalMiles;
  final String vehicleType;

  final String pickupLocation;
  final double? pickupLatitude;
  final double? pickupLongitude;

  final String dropoffLocation;
  final double? dropoffLatitude;
  final double? dropoffLongitude;

  /// Optional intermediate stops between pickup and destination.
  final List<RideStop> stops;

  /// Index into [stops] for the driver's next stop; when >= [stops.length],
  /// the next target is the final destination. Missing on old rides → 0.
  final int currentStopIndex;

  final String status;
  final String? driverId;
  final String? cancelledBy;
  final String? reservationId;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivingAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;
  final int durationMinutes;
  final bool riderArrived;
  final DateTime? riderArrivedAt;

  /// Passenger rating of this trip (`1`–`5`). Null until the rider submits it.
  final int? riderRating;
  final DateTime? ratedAt;

  /// Optional written review left by the passenger.
  final String riderReview;

  /// Latest live driver GPS persisted on the ride document.
  final double? driverLatitude;
  final double? driverLongitude;
  final double? driverHeading;
  final DateTime? driverLocationUpdatedAt;
  final DateTime? driverArrivedAt;

  const RideModel({
    required this.id,
    this.rideId = '',
    this.customerId = '',
    this.customerName = '',
    this.estimatedFare = 0,
    this.totalMiles = 0,
    this.vehicleType = '',
    this.pickupLocation = '',
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLocation = '',
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.stops = const [],
    this.currentStopIndex = 0,
    this.status = RideStatus.pending,
    this.driverId,
    this.cancelledBy,
    this.reservationId,
    this.createdAt,
    this.acceptedAt,
    this.arrivingAt,
    this.startedAt,
    this.completedAt,
    this.updatedAt,
    this.durationMinutes = 0,
    this.riderArrived = false,
    this.riderArrivedAt,
    this.riderRating,
    this.ratedAt,
    this.riderReview = '',
    this.driverLatitude,
    this.driverLongitude,
    this.driverHeading,
    this.driverLocationUpdatedAt,
    this.driverArrivedAt,
  });

  factory RideModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = doc.data() ?? const <String, dynamic>{};

    double? optionalNumber(String key) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim());
      return null;
    }

    double number(String key) => optionalNumber(key) ?? 0;

    String text(String key) {
      final value = map[key];
      if (value is String) return value;
      return '';
    }

    GeoPoint? geoPoint(String key) {
      final value = map[key];
      if (value is GeoPoint) return value;
      return null;
    }

    DateTime? timestamp(String key) {
      final value = map[key];
      if (value is Timestamp) return value.toDate();
      return null;
    }

    int minutes(String key) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.round();
      return 0;
    }

    int? tripRating() {
      final value = map[RideFields.riderRating];
      if (value is int) {
        return (value >= 1 && value <= 5) ? value : null;
      }
      if (value is num) {
        final n = value.round();
        return (n >= 1 && n <= 5) ? n : null;
      }
      return null;
    }

    String reviewText() {
      const keys = [
        RideFields.riderReview,
        'review',
        'comment',
        'feedback',
        'riderComment',
      ];
      for (final key in keys) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return '';
    }

    var pickupLatitude = optionalNumber(RideFields.pickupLatitude);
    var pickupLongitude = optionalNumber(RideFields.pickupLongitude);
    final pickupGeo = geoPoint(RideFields.pickupLocation);
    if ((pickupLatitude == null || pickupLongitude == null) &&
        pickupGeo != null) {
      pickupLatitude = pickupGeo.latitude;
      pickupLongitude = pickupGeo.longitude;
    }
    // Some rides store coords as a map under pickupLocation.
    if (pickupLatitude == null || pickupLongitude == null) {
      final fromMap = _latLngFromDynamic(map[RideFields.pickupLocation]);
      if (fromMap != null) {
        pickupLatitude = fromMap.latitude;
        pickupLongitude = fromMap.longitude;
      }
    }

    var dropoffLatitude = optionalNumber(RideFields.dropoffLatitude);
    var dropoffLongitude = optionalNumber(RideFields.dropoffLongitude);
    final dropoffGeo = geoPoint(RideFields.dropoffLocation);
    if ((dropoffLatitude == null || dropoffLongitude == null) &&
        dropoffGeo != null) {
      dropoffLatitude = dropoffGeo.latitude;
      dropoffLongitude = dropoffGeo.longitude;
    }
    if (dropoffLatitude == null || dropoffLongitude == null) {
      final fromMap = _latLngFromDynamic(map[RideFields.dropoffLocation]);
      if (fromMap != null) {
        dropoffLatitude = fromMap.latitude;
        dropoffLongitude = fromMap.longitude;
      }
    }

    double? driverLatitude;
    double? driverLongitude;
    double? driverHeading;
    final driverLoc = map[RideFields.driverLocation];
    if (driverLoc is Map) {
      final lat = driverLoc['latitude'];
      final lng = driverLoc['longitude'];
      final heading = driverLoc['heading'];
      if (lat is num) driverLatitude = lat.toDouble();
      if (lng is num) driverLongitude = lng.toDouble();
      if (heading is num) driverHeading = heading.toDouble();
    }

      final rawStatus = map[RideFields.status];
      final statusText = rawStatus is String ? rawStatus.trim() : '';
      final normalizedStatus = RideStatus.normalize(
        statusText.isEmpty ? RideStatus.pending : statusText,
      );

    return RideModel(
      id: doc.id,
      rideId: text(RideFields.rideId).isEmpty
          ? doc.id
          : text(RideFields.rideId),
      customerId: text(RideFields.customerId),
      customerName: text(RideFields.customerName),
      estimatedFare: number(RideFields.estimatedFare),
      totalMiles: number(RideFields.totalMiles),
      vehicleType: text(RideFields.vehicleType),
      pickupLocation: text(RideFields.pickupLocation),
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      dropoffLocation: text(RideFields.dropoffLocation),
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
      stops: RideStop.listFrom(map[RideFields.stops]),
      currentStopIndex: _parseCurrentStopIndex(map[RideFields.currentStopIndex]),
      status: normalizedStatus,
      driverId: map[RideFields.driverId] as String?,
      cancelledBy: text(RideFields.cancelledBy).isEmpty
          ? null
          : text(RideFields.cancelledBy),
      reservationId: text(RideFields.reservationId).isEmpty
          ? null
          : text(RideFields.reservationId),
      createdAt: timestamp(RideFields.createdAt),
      acceptedAt: timestamp(RideFields.acceptedAt),
      arrivingAt: timestamp(RideFields.arrivingAt),
      startedAt: timestamp(RideFields.startedAt),
      completedAt: timestamp(RideFields.completedAt),
      updatedAt: timestamp(RideFields.updatedAt),
      durationMinutes: minutes(RideFields.durationMinutes),
      riderArrived: map[RideFields.riderArrived] == true,
      riderArrivedAt: timestamp(RideFields.riderArrivedAt),
      riderRating: tripRating(),
      ratedAt: timestamp(RideFields.ratedAt),
      riderReview: reviewText(),
      driverLatitude: driverLatitude,
      driverLongitude: driverLongitude,
      driverHeading: driverHeading,
      driverLocationUpdatedAt:
          timestamp(RideFields.driverLocationUpdatedAt),
      driverArrivedAt: timestamp(RideFields.driverArrivedAt),
    );
  }

  RideModel withCurrentStopIndex(int index) {
    return RideModel(
      id: id,
      rideId: rideId,
      customerId: customerId,
      customerName: customerName,
      estimatedFare: estimatedFare,
      totalMiles: totalMiles,
      vehicleType: vehicleType,
      pickupLocation: pickupLocation,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      dropoffLocation: dropoffLocation,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
      stops: stops,
      currentStopIndex: index < 0 ? 0 : index,
      status: status,
      driverId: driverId,
      cancelledBy: cancelledBy,
      reservationId: reservationId,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
      arrivingAt: arrivingAt,
      startedAt: startedAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
      durationMinutes: durationMinutes,
      riderArrived: riderArrived,
      riderArrivedAt: riderArrivedAt,
      riderRating: riderRating,
      ratedAt: ratedAt,
      riderReview: riderReview,
      driverLatitude: driverLatitude,
      driverLongitude: driverLongitude,
      driverHeading: driverHeading,
      driverLocationUpdatedAt: driverLocationUpdatedAt,
      driverArrivedAt: driverArrivedAt,
    );
  }

  /// Ride was created from a confirmed reservation.
  bool get isFromReservation =>
      reservationId != null && reservationId!.isNotEmpty;

  /// Passenger (rider app) cancelled this ride.
  bool get wasCancelledByRider {
    final by = cancelledBy?.toLowerCase();
    return by == 'rider' || by == 'user';
  }

  /// True when the rider signaled arrival (flag and/or status).
  bool get hasRiderArrived =>
      riderArrived || status == RideStatus.riderArrived;

  /// Active trip after Start Ride (`ride_started` or legacy aliases).
  bool get isTripInProgress => RideStatus.isTripInProgressStatus(status);

  /// Driver still has an assigned open ride.
  bool get isActiveAssigned => RideStatus.isActiveAssignedStatus(status);

  bool get isPreArrivingAssigned =>
      RideStatus.isPreArrivingAssignedStatus(status);

  bool get isDriverArriving =>
      status == RideStatus.driverArriving || isPreArrivingAssigned;

  bool get isDriverArrived => status == RideStatus.driverArrived;

  bool get isPassengerArriving => status == RideStatus.passengerArriving;

  /// Waiting at pickup before or after passenger acknowledges "I'm Coming".
  bool get isWaitingAtPickup =>
      isDriverArrived || isPassengerArriving;

  /// Start Ride requires rider `passenger_arriving` acknowledgment.
  bool get canStart => status == RideStatus.passengerArriving;

  bool get canComplete => isTripInProgress && !hasRemainingStops;

  bool get canCancel =>
      status == RideStatus.pending || isActiveAssigned;

  bool get hasStops => stops.isNotEmpty;

  /// True while any intermediate stop is still the current in-trip target.
  bool get hasRemainingStops =>
      hasStops && currentStopIndex < stops.length;

  /// Next in-trip target: current stop if remaining, otherwise dropoff.
  LatLng? get currentTripTargetLatLng {
    if (hasRemainingStops) {
      return stops[currentStopIndex].latLng ?? dropoffLatLng;
    }
    return dropoffLatLng;
  }

  int get currentStopDisplayNumber => currentStopIndex + 1;

  /// Remaining ordered stop coordinates from [currentStopIndex] onward.
  List<LatLng> remainingStopWaypoints() {
    if (!hasRemainingStops) return const [];
    final points = <LatLng>[];
    for (var i = currentStopIndex; i < stops.length; i++) {
      final point = stops[i].latLng;
      if (point != null) points.add(point);
    }
    return points;
  }

  /// All stop coordinates in order (preview / pre-trip).
  List<LatLng> allStopWaypoints() {
    if (!hasStops) return const [];
    final points = <LatLng>[];
    for (final stop in stops) {
      final point = stop.latLng;
      if (point != null) points.add(point);
    }
    return points;
  }

  /// e.g. `$40`
  String get formattedFare =>
      estimatedFare > 0 ? '\$${estimatedFare.round()}' : '';

  /// e.g. `$328 · Cash`
  String get formattedFarePkr {
    if (estimatedFare <= 0) return 'Cash';
    return '\$${estimatedFare.round()} · Cash';
  }

  /// e.g. `~0.7 mi` or `~448 m` for very short trips.
  String get formattedDistance {
    if (totalMiles <= 0) return '';

    if (totalMiles < 0.1) {
      return '~${(totalMiles * 1609.34).round()} m';
    }

    return '~${totalMiles.toStringAsFixed(1)} mi';
  }

  /// True when the passenger has submitted a 1–5 rating for this trip.
  bool get hasRiderRating {
    final rating = riderRating;
    return rating != null && rating >= 1 && rating <= 5;
  }

  /// e.g. `5` — empty until the rider rates.
  String get formattedRating => hasRiderRating ? '$riderRating' : '';

  bool get hasRiderReview => riderReview.trim().isNotEmpty;

  /// Prefer stored `durationMinutes`, else derive from start/complete times.
  String get formattedDuration {
    if (durationMinutes > 0) return '$durationMinutes min';

    final start = startedAt;
    final end = completedAt;
    if (start != null && end != null) {
      final mins = end.difference(start).inMinutes;
      if (mins > 0) return '$mins min';
    }

    return '';
  }

  /// Minutes used for the pickup ETA countdown (fallback 5 when missing).
  int get etaMinutes => durationMinutes > 0 ? durationMinutes : 5;

  LatLng? get pickupLatLng {
    final lat = pickupLatitude;
    final lng = pickupLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? get dropoffLatLng {
    final lat = dropoffLatitude;
    final lng = dropoffLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  /// Live driver position from the ride document (for resume / rider sync).
  LatLng? get driverLatLng {
    final lat = driverLatitude;
    final lng = driverLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static LatLng? _latLngFromDynamic(dynamic value) {
    if (value is GeoPoint) {
      return LatLng(value.latitude, value.longitude);
    }
    if (value is Map) {
      final lat = value['latitude'] ?? value['lat'];
      final lng = value['longitude'] ?? value['lng'];
      final latN = lat is num ? lat.toDouble() : double.tryParse('$lat');
      final lngN = lng is num ? lng.toDouble() : double.tryParse('$lng');
      if (latN != null && lngN != null) return LatLng(latN, lngN);
    }
    return null;
  }

  static int _parseCurrentStopIndex(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) {
      final n = value.toInt();
      return n < 0 ? 0 : n;
    }
    return 0;
  }
}
