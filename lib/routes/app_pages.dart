import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/controllers/active_ride_controller.dart';
import 'package:ngtowncardriver/controllers/chat_controller.dart';
import 'package:ngtowncardriver/controllers/confirm_reservation_controller.dart';
import 'package:ngtowncardriver/controllers/dashboard_controller.dart';
import 'package:ngtowncardriver/controllers/pending_reservation_controller.dart';
import 'package:ngtowncardriver/controllers/reservation_feed_controller.dart';
import 'package:ngtowncardriver/controllers/reservation_history_controller.dart';
import 'package:ngtowncardriver/controllers/reviews_ratings_controller.dart';
import 'package:ngtowncardriver/controllers/ride_completed_controller.dart';
import 'package:ngtowncardriver/controllers/ride_history_feed_controller.dart';
import 'package:ngtowncardriver/controllers/rides_history_controller.dart';
import 'package:ngtowncardriver/controllers/signup_controller.dart';
import 'package:ngtowncardriver/controllers/waiting_approval_controller.dart';
import 'package:ngtowncardriver/middleware/approval_middleware.dart';
import 'package:ngtowncardriver/routes/app_routes.dart';
import 'package:ngtowncardriver/views/auth/driver_registration.dart';
import 'package:ngtowncardriver/views/auth/forgot_password.dart';
import 'package:ngtowncardriver/views/auth/session_restore_view.dart';
import 'package:ngtowncardriver/views/auth/signUp_view.dart';
import 'package:ngtowncardriver/views/auth/signin_view.dart';
import 'package:ngtowncardriver/views/auth/waiting_approval_view.dart';
import 'package:ngtowncardriver/views/chat/chat_view.dart';
import 'package:ngtowncardriver/views/location/location_permission_screen.dart';
import 'package:ngtowncardriver/views/main/main_shell_view.dart';
import 'package:ngtowncardriver/views/profile/profile_view.dart';
import 'package:ngtowncardriver/views/reservations/pending_reservation.dart';
import 'package:ngtowncardriver/views/reservations/reservation_history.dart';
import 'package:ngtowncardriver/views/reviews/reviews_ratings_view.dart';
import 'package:ngtowncardriver/views/rides/active_ride_view.dart';
import 'package:ngtowncardriver/views/rides/ride_completed_view.dart';
import 'package:ngtowncardriver/views/rides/ride_pending.dart';
import 'package:ngtowncardriver/views/rides/rides_history.dart';
import 'package:ngtowncardriver/views/settings/driver_details_view.dart';
import 'package:ngtowncardriver/widgets/constants/delete_acc_section.dart';

class AppPages {
  static const Transition _transition = Transition.rightToLeft;

  static const Duration _transitionDuration = Duration(milliseconds: 300);
  static final pages = [
    GetPage(
      name: AppRoutes.sessionRestore,
      page: () => const SessionRestoreView(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
    ),

    GetPage(
      name: AppRoutes.pendingReservation,
      page: () => const PendingReservation(),
      customTransition: ClippedRtlTransition(),
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<PendingReservationController>()) {
          Get.lazyPut<PendingReservationController>(
            () => PendingReservationController(),
          );
        }
        if (!Get.isRegistered<ReservationFeedController>()) {
          Get.lazyPut<ReservationFeedController>(
            () => ReservationFeedController(),
          );
        }
      }),
    ),
    GetPage(
      name: AppRoutes.signIn,
      page: () => const SignInView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
    ),

    GetPage(
      name: AppRoutes.deleteacc,
      page: () => const DeleteAccSection(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
    ),
    GetPage(
      name: AppRoutes.reservationhistory,
      page: () => const ReservationHistory(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<ReservationHistoryController>()) {
          Get.lazyPut<ReservationHistoryController>(
            () => ReservationHistoryController(),
          );
        }
        if (!Get.isRegistered<ReservationFeedController>()) {
          Get.lazyPut<ReservationFeedController>(
            () => ReservationFeedController(),
          );
        }
      }),
    ),
    GetPage(
      name: AppRoutes.signUp,
      page: () => const SignupView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: AppRoutes.driverRegistration,
      page: () => const DriverRegistration(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      binding: BindingsBuilder(() {
        Get.lazyPut<SignupController>(() => SignupController());
      }),
    ),

    GetPage(
      name: AppRoutes.waitingApproval,
      page: () => const WaitingApprovalView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      binding: BindingsBuilder(() {
        Get.lazyPut<WaitingApprovalController>(
          () => WaitingApprovalController(),
        );
      }),
    ),

    GetPage(
      name: AppRoutes.locationPermission,
      page: () => const LocationPermissionScreen(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const MainShellView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<DashboardController>()) {
          Get.lazyPut<DashboardController>(() => DashboardController());
        }
        if (!Get.isRegistered<ReservationFeedController>()) {
          Get.lazyPut<ReservationFeedController>(
            () => ReservationFeedController(),
          );
        }
        if (!Get.isRegistered<RideHistoryFeedController>()) {
          Get.lazyPut<RideHistoryFeedController>(
            () => RideHistoryFeedController(),
          );
        }
        if (!Get.isRegistered<ReservationHistoryController>()) {
          Get.lazyPut<ReservationHistoryController>(
            () => ReservationHistoryController(),
          );
        }
        if (!Get.isRegistered<PendingReservationController>()) {
          Get.lazyPut<PendingReservationController>(
            () => PendingReservationController(),
          );
        }
        if (!Get.isRegistered<ConfirmReservationController>()) {
          Get.lazyPut<ConfirmReservationController>(
            () => ConfirmReservationController(),
          );
        }
      }),
    ),

    GetPage(
      name: AppRoutes.ridePending,
      page: () => const RidePending(),
      customTransition: ClippedRtlTransition(),
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
    ),
    GetPage(
      name: AppRoutes.activeRide,
      page: () => const ActiveRideView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
      binding: BindingsBuilder(() {
        Get.lazyPut<ActiveRideController>(() => ActiveRideController());
      }),
    ),
    GetPage(
      name: AppRoutes.chat,
      page: () => const ChatView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
      binding: BindingsBuilder(() {
        Get.lazyPut<ChatController>(() => ChatController());
      }),
    ),
    GetPage(
      name: AppRoutes.rideHistory,
      page: () => const RidesHistory(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
      binding: BindingsBuilder(() {
        Get.lazyPut<RidesHistoryController>(() => RidesHistoryController());
        if (!Get.isRegistered<RideHistoryFeedController>()) {
          Get.lazyPut<RideHistoryFeedController>(
            () => RideHistoryFeedController(),
          );
        }
      }),
    ),
    GetPage(
      name: AppRoutes.completedRideDetail,
      page: () => const RideCompletedView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
      binding: BindingsBuilder(() {
        Get.lazyPut<RideCompletedController>(() => RideCompletedController());
      }),
    ),
    GetPage(
      name: AppRoutes.reviewsRatings,
      page: () => const ReviewsRatingsView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
      binding: BindingsBuilder(() {
        Get.lazyPut<ReviewsRatingsController>(() => ReviewsRatingsController());
        if (!Get.isRegistered<RideHistoryFeedController>()) {
          Get.lazyPut<RideHistoryFeedController>(
            () => RideHistoryFeedController(),
          );
        }
      }),
    ),

    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfileView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
    ),
    GetPage(
      name: AppRoutes.driverDetails,
      page: () => const DriverDetailsView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
    ),
  ];
}
