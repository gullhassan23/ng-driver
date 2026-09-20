import 'package:cloud_firestore/cloud_firestore.dart';

import '../utilis/firestore_paths.dart';

/// Document from `rides/{rideId}/driverOffers/{driverId}`.
class DriverOfferModel {
  final String id;
  final String driverId;
  final String driverName;
  final String status;
  final double? driverLatitude;
  final double? driverLongitude;
  final String driverAddress;
  final DateTime? acceptedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverOfferModel({
    required this.id,
    this.driverId = '',
    this.driverName = '',
    this.status = DriverOfferStatus.driverAccepted,
    this.driverLatitude,
    this.driverLongitude,
    this.driverAddress = '',
    this.acceptedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory DriverOfferModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = doc.data() ?? const <String, dynamic>{};

    DateTime? timestamp(String key) {
      final value = map[key];
      if (value is Timestamp) return value.toDate();
      return null;
    }

    double? optionalNumber(String key) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim());
      return null;
    }

    return DriverOfferModel(
      id: doc.id,
      driverId: (map[DriverOfferFields.driverId] as String?) ?? doc.id,
      driverName: (map[DriverOfferFields.driverName] as String?) ?? '',
      status: (map[DriverOfferFields.status] as String?) ??
          DriverOfferStatus.driverAccepted,
      driverLatitude: optionalNumber(DriverOfferFields.driverLatitude),
      driverLongitude: optionalNumber(DriverOfferFields.driverLongitude),
      driverAddress: (map[DriverOfferFields.driverAddress] as String?) ?? '',
      acceptedAt: timestamp(DriverOfferFields.acceptedAt),
      createdAt: timestamp(DriverOfferFields.createdAt),
      updatedAt: timestamp(DriverOfferFields.updatedAt),
    );
  }

  bool get isWaiting => DriverOfferStatus.isWaiting(status);

  bool get isSelected => status == DriverOfferStatus.riderSelected;

  bool get isDeclined => status == DriverOfferStatus.riderDeclined;

  bool get isTerminal => DriverOfferStatus.isTerminal(status);
}
