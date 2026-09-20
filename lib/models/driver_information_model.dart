import 'package:cloud_firestore/cloud_firestore.dart';

import '../utilis/firestore_paths.dart';

/// CNIC, licence and vehicle details stored in `driver_information/{uid}`.
class DriverInformationModel {
  final String uid;
  final String cnic;
  final String licenseNumber;
  final String vehicleType;
  final String vehicleMake;
  final String vehicleModel;
  final String vehicleColor;
  final String vehicleRegistration;

  const DriverInformationModel({
    required this.uid,
    this.cnic = '',
    this.licenseNumber = '',
    this.vehicleType = '',
    this.vehicleMake = '',
    this.vehicleModel = '',
    this.vehicleColor = '',
    this.vehicleRegistration = '',
  });

  factory DriverInformationModel.fromMap(
    String uid,
    Map<String, dynamic> map,
  ) {
    String text(String key) => (map[key] as String?) ?? '';

    return DriverInformationModel(
      uid: uid,
      cnic: text(DriverInformationFields.cnic),
      licenseNumber: text(DriverInformationFields.licenseNumber),
      vehicleType: text(DriverInformationFields.vehicleType),
      vehicleMake: text(DriverInformationFields.vehicleMake),
      vehicleModel: text(DriverInformationFields.vehicleModel),
      vehicleColor: text(DriverInformationFields.vehicleColor),
      vehicleRegistration: text(DriverInformationFields.vehicleRegistration),
    );
  }

  factory DriverInformationModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return DriverInformationModel.fromMap(doc.id, doc.data() ?? const {});
  }

  Map<String, dynamic> toMap() {
    return {
      DriverInformationFields.uid: uid,
      DriverInformationFields.cnic: cnic,
      DriverInformationFields.licenseNumber: licenseNumber,
      DriverInformationFields.vehicleType: vehicleType,
      DriverInformationFields.vehicleMake: vehicleMake,
      DriverInformationFields.vehicleModel: vehicleModel,
      DriverInformationFields.vehicleColor: vehicleColor,
      DriverInformationFields.vehicleRegistration: vehicleRegistration,
    };
  }
}
