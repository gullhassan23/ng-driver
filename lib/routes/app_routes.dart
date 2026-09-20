import 'package:flutter/animation.dart';
import 'package:get/get.dart';
import 'package:ngtowncardriver/views/profile/profile_view.dart';
import 'package:ngtowncardriver/views/reservations/pending_reservation.dart';
import 'package:ngtowncardriver/views/reservations/reservation_history.dart';
import 'package:ngtowncardriver/views/reviews/reviews_ratings_view.dart';
import 'package:ngtowncardriver/views/rides/rides_history.dart';
import 'package:ngtowncardriver/views/settings/driver_details_view.dart';
import 'package:ngtowncardriver/widgets/constants/delete_acc_section.dart';

import '../controllers/active_ride_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/confirm_reservation_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/pending_reservation_controller.dart';
import '../controllers/reservation_feed_controller.dart';
import '../controllers/reservation_history_controller.dart';
import '../controllers/reviews_ratings_controller.dart';
import '../controllers/ride_completed_controller.dart';
import '../controllers/ride_history_feed_controller.dart';
import '../controllers/rides_history_controller.dart';
import '../controllers/signup_controller.dart';
import '../controllers/waiting_approval_controller.dart';
import '../middleware/approval_middleware.dart';
import '../views/auth/forgot_password.dart';
import '../views/auth/driver_registration.dart';
import '../views/auth/session_restore_view.dart';
import '../views/auth/signUp_view.dart';
import '../views/auth/signin_view.dart';
import '../views/auth/waiting_approval_view.dart';
import '../views/chat/chat_view.dart';
import '../views/location/location_permission_screen.dart';
import '../views/rides/active_ride_view.dart';
import '../views/rides/ride_completed_view.dart';
import '../views/rides/ride_pending.dart';
import '../views/main/main_shell_view.dart';

class AppRoutes {
  static const String sessionRestore = '/';
  static const String signIn = '/signIn';
  static const String signUp = '/signUp';
  static const String signUpDetail = '/signUpDetail';
  static const String waitingApproval = '/waitingApproval';
  static const String dashboard = '/dashboard';
  static const String locationPermission = '/locationPermission';
  static const String reservation = '/newReservationRequest';
  static const String ridePending = '/ridePending';
  static const String pendingReservation = '/pendingReservation';
  static const String activeRide = '/activeRide';
  static const String chat = '/chat';
  static const String deleteacc = '/deleteAccount';
  static const String rideCompleted = '/rideCompleted';
  static const String completedRideDetail = '/completedRideDetail';
  static const String reviewsRatings = '/reviewsRatings';
  static const String profile = '/profile';
  static const String driverDetails = '/driverDetails';
  static const String forgotPassword = '/forgotPassword';

  static const Transition _transition = Transition.rightToLeft;

  static const Duration _transitionDuration = Duration(milliseconds: 300);

  static final List<GetPage<dynamic>> pages = [
    GetPage(
      name: sessionRestore,
      page: () => const SessionRestoreView(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: forgotPassword,
      page: () => const ForgotView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
    ),

    GetPage(
      name: pendingReservation,
      page: () => const PendingReservation(),
      transition: _transition,
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
      name: signIn,
      page: () => const SignInView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
    ),

    GetPage(
      name: deleteacc,
      page: () => const DeleteAccSection(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
    ),
    GetPage(
      name: reservation,
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
      name: signUp,
      page: () => const SignupView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: signUpDetail,
      page: () => const DriverRegistration(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      binding: BindingsBuilder(() {
        Get.lazyPut<SignupController>(() => SignupController());
      }),
    ),

    GetPage(
      name: waitingApproval,
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
      name: locationPermission,
      page: () => const LocationPermissionScreen(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
    ),
    GetPage(
      name: dashboard,
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
      name: ridePending,
      page: () => const RidePending(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
    ),
    GetPage(
      name: activeRide,
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
      name: chat,
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
      name: rideCompleted,
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
      name: completedRideDetail,
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
      name: reviewsRatings,
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
      name: profile,
      page: () => const ProfileView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
    ),
    GetPage(
      name: driverDetails,
      page: () => const DriverDetailsView(),
      transition: _transition,
      transitionDuration: _transitionDuration,
      curve: Curves.easeInOut,
      middlewares: [ApprovalMiddleware()],
    ),
  ];
}
