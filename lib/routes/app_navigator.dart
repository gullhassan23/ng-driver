import 'package:get/get.dart';
import 'package:ngtowncardriver/routes/app_routes.dart';

class AppNavigator {
  AppNavigator._();

  static void toSession() {
    Get.offNamed(AppRoutes.sessionRestore);
  }

  static void toForgot() {
    Get.offNamed(AppRoutes.forgotPassword);
  }

  static void topendingReservation() {
    Get.offNamed(AppRoutes.pendingReservation);
  }

  static void toSignIn() {
    Get.offNamed(AppRoutes.signIn);
  }

  static void toDeleteAccount() {
    Get.offNamed(AppRoutes.deleteacc);
  }

  static void toReservationHistory() {
    Get.toNamed(AppRoutes.reservationhistory);
  }

  static void toSigUp() {
    Get.offNamed(AppRoutes.signUp);
  }

  static void toDriverRegistration() {
    Get.offNamed(AppRoutes.driverRegistration);
  }

  static void towaitingApproval() {
    Get.offNamed(AppRoutes.waitingApproval);
  }

  static void tolocationPermission() {
    Get.offNamed(AppRoutes.locationPermission);
  }

  static void todashboard() {
    Get.offNamed(AppRoutes.dashboard);
  }

  static void toridePending() {
    Get.offNamed(AppRoutes.ridePending);
  }

  static void toactiveRide() {
    Get.offNamed(AppRoutes.activeRide);
  }

  /// True when Active Ride or in-ride Chat is the current route.
  static bool isOnActiveRideStack() {
    final route = Get.currentRoute;
    return route == AppRoutes.activeRide || route == AppRoutes.chat;
  }

  /// Leaves Active Ride (and any chat/dialog above it) and lands on dashboard.
  ///
  /// A single [Get.back] is unsafe: with Chat open it only pops Chat and
  /// leaves the driver stuck on Active Ride after cancel.
  static void leaveActiveRideToDashboard({int navIndex = 0}) {
    while (Get.isDialogOpen == true) {
      Get.back();
    }

    if (Get.currentRoute == AppRoutes.dashboard) return;

    final navigator = Get.key.currentState;
    if (navigator == null) {
      Get.offAllNamed(
        AppRoutes.dashboard,
        arguments: {'navIndex': navIndex},
      );
      return;
    }

    var foundDashboard = false;
    navigator.popUntil((route) {
      final isDashboard = route.settings.name == AppRoutes.dashboard;
      if (isDashboard) foundDashboard = true;
      return isDashboard || route.isFirst;
    });

    if (!foundDashboard && Get.currentRoute != AppRoutes.dashboard) {
      Get.offAllNamed(
        AppRoutes.dashboard,
        arguments: {'navIndex': navIndex},
      );
    }
  }

  //   static void tochat() {
  //   Get.offNamed(AppRoutes.chat);
  static bool _isNavigatingToChat = false;

  /// Opens in-ride chat for the current [rideId].
  static void toChat(String rideId) {
    final trimmed = rideId.trim();
    if (trimmed.isEmpty) return;
    if (_isNavigatingToChat || Get.currentRoute == AppRoutes.chat) return;
    _isNavigatingToChat = true;
    Get.toNamed(
      AppRoutes.chat,
      arguments: {'rideId': trimmed, 'isReservation': false},
    )?.whenComplete(() {
      _isNavigatingToChat = false;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _isNavigatingToChat = false;
    });
  }

  /// Opens chat for a confirmed reservation with assigned driver.
  static void toReservationChat({
    required String reservationId,
    dynamic reservation,
    String? rideId,
  }) {
    final trimmedId = reservationId.trim();
    if (trimmedId.isEmpty) return;
    if (_isNavigatingToChat || Get.currentRoute == AppRoutes.chat) return;
    _isNavigatingToChat = true;
    Get.toNamed(
      AppRoutes.chat,
      arguments: {
        'reservationId': trimmedId,
        'reservation': reservation,
        'rideId': rideId?.trim(),
        'isReservation': true,
      },
    )?.whenComplete(() {
      _isNavigatingToChat = false;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _isNavigatingToChat = false;
    });
  }

  static void torideHistory() {
    Get.toNamed(AppRoutes.rideHistory);
  }

  static void toCompletedRideDetail({
    required dynamic ride,
    bool returnToDashboard = false,
  }) {
    Get.offAllNamed(
      AppRoutes.rideDetail,
      arguments: {'ride': ride, 'returnToDashboard': returnToDashboard},
    );
  }

  static void toreviewsRatings() {
    Get.toNamed(AppRoutes.reviewsRatings);
  }

  static void toprofile() {
    Get.toNamed(AppRoutes.profile);
  }

  static void todriverDetails() {
    Get.offNamed(AppRoutes.driverDetails);
  }
}
