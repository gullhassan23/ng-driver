import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/driver_information_model.dart';
import '../routes/app_routes.dart';
import '../services/firestore_service.dart';
import '../utilis/auth_messages.dart';
import '../utilis/firestore_paths.dart';
import '../widgets/app_snackbar_widget.dart';
import '../widgets/cnic_number_formatter.dart';
import '../widgets/phone_text_field_widget.dart';
import 'auth_controller.dart';

/// Backs the driver details form: CNIC, licence and vehicle information.
class SignupController extends GetxController {
  SignupController({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  final cnic = TextEditingController();
  final licenseNumber = TextEditingController();
  final vehicleMake = TextEditingController();
  final vehicleModel = TextEditingController();
  final vehicleColor = TextEditingController();
  final vehicleRegistration = TextEditingController();

  final selectedVehicleType = RxnString(null);
  final isLoading = false.obs;

  static const List<String> vehicleTypes = [
    'Sedan',
    'SUV',
  ];

  @override
  void onClose() {
    cnic.dispose();
    licenseNumber.dispose();
    vehicleMake.dispose();
    vehicleModel.dispose();
    vehicleColor.dispose();
    vehicleRegistration.dispose();
    super.onClose();
  }

  void setVehicleType(String? value) {
    selectedVehicleType.value = value;
  }

  void clearForm() {
    cnic.clear();
    licenseNumber.clear();
    vehicleMake.clear();
    vehicleModel.clear();
    vehicleColor.clear();
    vehicleRegistration.clear();
    selectedVehicleType.value = null;
    isLoading.value = false;
  }

  Future<void> submit() async {
    final auth = Get.find<AuthController>();
    final uid = auth.uid;

    if (uid == null) {
      _showError('Your session expired. Please sign in again.');
      Get.offAllNamed(AppRoutes.signIn);
      return;
    }

    final cnicDigits = CnicNumberFormatter.digitsOf(cnic.text);
    if (cnicDigits.isEmpty || licenseNumber.text.trim().isEmpty) {
      _showError('Enter a valid CNIC (123-45-6789) and driving licence number.');
      return;
    }

    if (selectedVehicleType.value == null) {
      _showError('Select your vehicle type.');
      return;
    }

    if (vehicleRegistration.text.trim().isEmpty) {
      _showError('Enter your vehicle registration number.');
      return;
    }

    isLoading.value = true;

    try {
      // Force a fresh ID token so Firestore sees request.auth after signup.
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      final info = DriverInformationModel(
        uid: uid,
        cnic: cnicDigits,
        licenseNumber: licenseNumber.text.trim(),
        vehicleType: selectedVehicleType.value ?? '',
        vehicleMake: vehicleMake.text.trim(),
        vehicleModel: vehicleModel.text.trim(),
        vehicleColor: vehicleColor.text.trim(),
        vehicleRegistration: vehicleRegistration.text.trim(),
      );

      final driverFields = <String, dynamic>{
        DriverFields.uid: uid,
        DriverFields.cnic: info.cnic,
        DriverFields.licenseNumber: info.licenseNumber,
        DriverFields.vehicleType: info.vehicleType,
        DriverFields.vehicleMake: info.vehicleMake,
        DriverFields.vehicleModel: info.vehicleModel,
        DriverFields.vehicleColor: info.vehicleColor,
        DriverFields.vehicleRegistration: info.vehicleRegistration,
        DriverFields.profileComplete: true,
      };

      final firstName = auth.firstName.text.trim();
      final lastName = auth.lastName.text.trim();
      final email = auth.signUpEmail.text.trim();
      final phone = UsPhoneNumberFormatter.digitsOf(auth.phone.text);

      if (firstName.isNotEmpty) driverFields[DriverFields.firstName] = firstName;
      if (lastName.isNotEmpty) driverFields[DriverFields.lastName] = lastName;
      if (email.isNotEmpty) driverFields[DriverFields.email] = email;
      if (phone.isNotEmpty) driverFields[DriverFields.phone] = phone;

      await _firestore.upsertDriverFields(uid, driverFields);
      await _firestore.saveDriverInformation(info);

      auth.rememberApproval(false);
      Get.offAllNamed(AppRoutes.waitingApproval);
    } on FirebaseException catch (error) {
      _showError(_firestoreMessageFor(error));
    } catch (_) {
      _showError('Could not save your details. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  String _firestoreMessageFor(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AuthMessages.noInternet;
      default:
        return 'Could not save your details. Please try again.';
    }
  }

  void _showError(String message) {
    AppSnackbar.error(
      title: 'Driver details',
      message: message,
      duration: const Duration(seconds: 4),
    );
  }
}
