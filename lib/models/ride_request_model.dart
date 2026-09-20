import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utilis/firestore_paths.dart';

class RideRequestModel {
  final String id;

  final String riderId;
  final String riderName;
  final double riderRating;
  final int riderReviews;

  final double fare;
  final String currency;
  final List<double> fareOffers;

  final double distanceKm;
  final int durationMinutes;

  final String pickupAddress;
  final GeoPoint? pickupLocation;
  final String dropoffAddress;
  final GeoPoint? dropoffLocation;

  final String status;
  final String? driverId;

  const RideRequestModel({
    required this.id,
    this.riderId = '',
    this.riderName = '',
    this.riderRating = 0,
    this.riderReviews = 0,
    this.fare = 0,
    this.currency = 'USD',
    this.fareOffers = const [],
    this.distanceKm = 0,
    this.durationMinutes = 0,
    this.pickupAddress = '',
    this.pickupLocation,
    this.dropoffAddress = '',
    this.dropoffLocation,
    this.status = RideStatus.pending,
    this.driverId,
  });

  factory RideRequestModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = doc.data() ?? const <String, dynamic>{};

    double number(String key) =>
        (map[key] as num?)?.toDouble() ?? 0;

    String text(String key) => (map[key] as String?) ?? '';

    final offers = (map[RideFields.fareOffers] as List<dynamic>?)
            ?.map((offer) => (offer as num).toDouble())
            .toList() ??
        const <double>[];

    return RideRequestModel(
      id: doc.id,
      riderId: text(RideFields.riderId),
      riderName: text(RideFields.riderName),
      riderRating: number(RideFields.riderRating),
      riderReviews: (map[RideFields.riderReviews] as num?)?.toInt() ?? 0,
      fare: number(RideFields.fare),
      currency: (map[RideFields.currency] as String?) ?? 'USD',
      fareOffers: offers,
      distanceKm: number(RideFields.distanceKm),
      durationMinutes:
          (map[RideFields.durationMinutes] as num?)?.toInt() ?? 0,
      pickupAddress: text(RideFields.pickupAddress),
      pickupLocation: map[RideFields.pickupLocation] as GeoPoint?,
      dropoffAddress: text(RideFields.dropoffAddress),
      dropoffLocation: map[RideFields.dropoffLocation] as GeoPoint?,
      status: (map[RideFields.status] as String?) ?? RideStatus.pending,
      driverId: map[RideFields.driverId] as String?,
    );
  }

  // ==========================================
  // DISPLAY FORMATTING
  // ==========================================

  /// e.g. `$221`
  String get formattedFare => '\$${fare.round()}';

  /// e.g. `~1.5 km` for longer trips, `~448 m` under a kilometre.
  String get formattedDistance {
    if (distanceKm <= 0) return '';

    if (distanceKm < 1) {
      return '~${(distanceKm * 1000).round()} m';
    }

    return '~${distanceKm.toStringAsFixed(1)} km';
  }

  /// e.g. `7 min`
  String get formattedDuration =>
      durationMinutes > 0 ? '$durationMinutes min' : '';

  String get formattedRating => riderRating.toStringAsFixed(2);

  String get formattedReviews => riderReviews.toString();

  /// Fare suggestions shown in the ride details sheet. Falls back to a
  /// spread above the base fare when the user app sends none.
  List<String> get formattedFareOffers {
    final offers = fareOffers.isNotEmpty
        ? fareOffers
        : List<double>.generate(
            6,
            (index) => fare + ((index + 1) * fare * 0.1),
          );

    return offers
        .map((offer) => '\$${offer.round()}')
        .toList();
  }

  LatLng? get pickupLatLng => _toLatLng(pickupLocation);

  LatLng? get dropoffLatLng => _toLatLng(dropoffLocation);

  static LatLng? _toLatLng(GeoPoint? point) {
    if (point == null) return null;

    return LatLng(point.latitude, point.longitude);
  }
}
