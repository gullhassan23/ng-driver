import 'dart:async';

import 'package:get/get.dart';

import '../models/driver_model.dart';
import '../routes/app_routes.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_snackbar_widget.dart';
import 'auth_controller.dart';

class WaitingApprovalController extends GetxController {
  WaitingApprovalController({
    FirestoreService? firestore,
    NotificationService? notifications,
  }) : _firestore = firestore ?? FirestoreService(),
       _notifications = notifications ?? NotificationService();

  final FirestoreService _firestore;
  final NotificationService _notifications;

  final isLoading = true.obs;
  final errorMessage = RxnString(null);

  StreamSubscription<DriverModel?>? _driverSubscription;
  StreamSubscription<String>? _tokenSubscription;
  bool _isNavigating = false;

  @override
  void onInit() {
    super.onInit();
    unawaited(_registerFcmToken());
    listenForApproval();
  }

  @override
  void onClose() {
    _driverSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.onClose();
  }

  /// Token must exist before approval so `driver_approved` push can arrive.
  Future<void> _registerFcmToken() async {
    final uid = Get.find<AuthController>().uid;
    if (uid == null) return;

    final granted = await _notifications.requestPermission();
    if (!granted) return;

    final token = await _notifications.deviceToken();
    if (token != null) {
      await _firestore.saveFcmToken(uid, token);
    }
    _tokenSubscription = _notifications.tokenRefreshes.listen((value) {
      _firestore.saveFcmToken(uid, value);
    });
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
