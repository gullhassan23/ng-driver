import '../utilis/firestore_paths.dart';
import 'geo.dart';

/// Denormalized driver snapshot written onto `rides/{rideId}` at accept.
Map<String, dynamic> assignedDriverRideFields({
  required Map<String, dynamic> driverData,
  double? driverLatitude,
  double? driverLongitude,
  double? pickupLatitude,
  double? pickupLongitude,
}) {
  String text(String key) {
    final value = driverData[key];
    return value is String ? value.trim() : '';
  }

  final firstName = text(DriverFields.firstName);
  final lastName = text(DriverFields.lastName);
  final make = text(DriverFields.vehicleMake);
  final model = text(DriverFields.vehicleModel);
  final type = text(DriverFields.vehicleType);
  final registration = text(DriverFields.vehicleRegistration);
  final makeModel = '$make $model'.trim();

  final fields = <String, dynamic>{
    RideFields.driverFirstName: firstName,
    RideFields.driverLastName: lastName,
    RideFields.driverName: '$firstName $lastName'.trim(),
    RideFields.driverPhone: text(DriverFields.phone),
    RideFields.driverVehicleType: type,
    RideFields.driverVehicleMake: make,
    RideFields.driverVehicleModel: model,
    RideFields.driverVehicleColor: text(DriverFields.vehicleColor),
    RideFields.driverVehicleRegistration: registration,
    RideFields.driverVehicle: makeModel.isNotEmpty ? makeModel : type,
    RideFields.driverVehicleNumber: registration,
    RideFields.driverRating: _ratingFromDriver(driverData),
  };

  final pickupEta = pickupEtaFields(
    driverLatitude: driverLatitude,
    driverLongitude: driverLongitude,
    pickupLatitude: pickupLatitude,
    pickupLongitude: pickupLongitude,
  );
  fields.addAll(pickupEta);
  return fields;
}

/// Pickup ETA + distance from the driver's current GPS.
Map<String, dynamic> pickupEtaFields({
  double? driverLatitude,
  double? driverLongitude,
  double? pickupLatitude,
  double? pickupLongitude,
}) {
  if (driverLatitude == null ||
      driverLongitude == null ||
      pickupLatitude == null ||
      pickupLongitude == null) {
    return const {};
  }

  final miles = milesBetween(
    driverLatitude,
    driverLongitude,
    pickupLatitude,
    pickupLongitude,
  );
  return {
    RideFields.driverDistanceMiles: (miles * 1000).round() / 1000,
    RideFields.driverEta: formatDriverEta(miles),
  };
}

double _ratingFromDriver(Map<String, dynamic> driverData) {
  final raw = driverData[DriverFields.rating] ?? driverData['driverRating'];
  if (raw is num && raw.isFinite && raw >= 0) return raw.toDouble();
  return 5;
}
