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
    Get.offNamed(AppRoutes.reservationhistory);
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

  //   static void tochat() {
  //   Get.offNamed(AppRoutes.chat);
  // }
  static void toChat(String rideId) {
    Get.toNamed(AppRoutes.chat, arguments: rideId);
  }

  static void torideHistory() {
    Get.offNamed(AppRoutes.rideHistory);
  }

  static void toCompletedRideDetail({
    required dynamic ride,
    bool returnToDashboard = false,
  }) {
    Get.offAllNamed(
      AppRoutes.completedRideDetail,
      arguments: {'ride': ride, 'returnToDashboard': returnToDashboard},
    );
  }

  static void toreviewsRatings() {
    Get.offNamed(AppRoutes.reviewsRatings);
  }

  static void toprofile() {
    Get.offNamed(AppRoutes.profile);
  }

  static void todriverDetails() {
    Get.offNamed(AppRoutes.driverDetails);
  }
}
