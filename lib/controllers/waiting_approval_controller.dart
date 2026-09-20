import 'dart:async';

import 'package:get/get.dart';

import '../models/driver_model.dart';
import '../routes/app_routes.dart';
import '../services/firestore_service.dart';
import '../widgets/app_snackbar_widget.dart';
import 'auth_controller.dart';

class WaitingApprovalController extends GetxController {
  WaitingApprovalController({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  final isLoading = true.obs;
  final errorMessage = RxnString(null);

  StreamSubscription<DriverModel?>? _driverSubscription;
  bool _isNavigating = false;

  @override
  void onInit() {
    super.onInit();
    listenForApproval();
  }

  @override
  void onClose() {
    _driverSubscription?.cancel();
    super.onClose();
  }

  void listenForApproval() {
    final auth = Get.find<AuthController>();
    final uid = auth.uid;

    if (uid == null) {
      Get.offAllNamed(AppRoutes.signIn);
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;
    _driverSubscription?.cancel();

    _driverSubscription = _firestore.watchDriver(uid).listen(
      (driver) async {
        if (driver == null) {
          auth.rememberApproval(false);
          isLoading.value = false;
          errorMessage.value =
              'Your driver profile was not found. Please sign in again.';
          return;
        }

        if (!driver.isApproved) {
          auth.rememberApproval(false);
          isLoading.value = false;
          errorMessage.value = null;
          return;
        }

        await _leaveWhenApproved(auth);
      },
      onError: (Object _) {
        auth.rememberApproval(false);
        isLoading.value = false;
        errorMessage.value =
            'Could not check your approval status. Please try again.';
      },
    );
  }

  Future<void> _leaveWhenApproved(AuthController auth) async {
    if (_isNavigating) return;

    _isNavigating = true;
    isLoading.value = true;

    try {
      final route = await auth.resolvePostAuthRoute();

      if (route == AppRoutes.waitingApproval) {
        _isNavigating = false;
        isLoading.value = false;
        return;
      }

      await auth.navigatePostAuth(route);
    } catch (_) {
      _isNavigating = false;
      isLoading.value = false;
      errorMessage.value =
          'Could not continue after approval. Please try again.';
      AppSnackbar.error(
        title: 'Approval',
        message: 'Could not continue after approval. Please try again.',
      );
    }
  }

  Future<void> signOut() {
    return Get.find<AuthController>().signOut();
  }
}
