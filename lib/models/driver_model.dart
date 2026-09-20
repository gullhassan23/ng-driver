import 'package:cloud_firestore/cloud_firestore.dart';

import '../utilis/firestore_paths.dart';

class DriverModel {
  final String uid;

  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  final String cnic;
  final String licenseNumber;

  final String vehicleType;
  final String vehicleMake;
  final String vehicleModel;
  final String vehicleColor;
  final String vehicleRegistration;

  final bool isOnline;
  final bool isApproved;
  final String? fcmToken;
  final String? currentRideId;

  const DriverModel({
    required this.uid,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.cnic = '',
    this.licenseNumber = '',
    this.vehicleType = '',
    this.vehicleMake = '',
    this.vehicleModel = '',
    this.vehicleColor = '',
    this.vehicleRegistration = '',
    this.isOnline = false,
    this.isApproved = false,
    this.fcmToken,
    this.currentRideId,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory DriverModel.fromMap(
    String uid,
    Map<String, dynamic> map,
  ) {
    String text(String key) => (map[key] as String?) ?? '';

    final rideId = map[DriverFields.currentRideId] as String?;

    return DriverModel(
      uid: uid,
      firstName: text(DriverFields.firstName),
      lastName: text(DriverFields.lastName),
      email: text(DriverFields.email),
      phone: text(DriverFields.phone),
      cnic: text(DriverFields.cnic),
      licenseNumber: text(DriverFields.licenseNumber),
      vehicleType: text(DriverFields.vehicleType),
      vehicleMake: text(DriverFields.vehicleMake),
      vehicleModel: text(DriverFields.vehicleModel),
      vehicleColor: text(DriverFields.vehicleColor),
      vehicleRegistration: text(DriverFields.vehicleRegistration),
      isOnline: (map[DriverFields.isOnline] as bool?) ?? false,
      isApproved: map[DriverFields.isApproved] == true,
      fcmToken: map[DriverFields.fcmToken] as String?,
      currentRideId: (rideId == null || rideId.isEmpty) ? null : rideId,
    );
  }

  factory DriverModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return DriverModel.fromMap(doc.id, doc.data() ?? const {});
  }

  Map<String, dynamic> toMap() {
    return {
      DriverFields.uid: uid,
      DriverFields.firstName: firstName,
      DriverFields.lastName: lastName,
      DriverFields.email: email,
      DriverFields.phone: phone,
      DriverFields.cnic: cnic,
      DriverFields.licenseNumber: licenseNumber,
      DriverFields.vehicleType: vehicleType,
      DriverFields.vehicleMake: vehicleMake,
      DriverFields.vehicleModel: vehicleModel,
      DriverFields.vehicleColor: vehicleColor,
      DriverFields.vehicleRegistration: vehicleRegistration,
      DriverFields.isOnline: isOnline,
      if (fcmToken != null) DriverFields.fcmToken: fcmToken,
      // isApproved is owned by admin / Firestore rules — never write it here.
    };
  }
}
