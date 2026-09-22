import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppRoutes {
  static const String sessionRestore = '/';
  static const String signIn = '/signIn';
  static const String signUp = '/signUp';
  static const String driverRegistration = '/driverRegistration';
  static const String waitingApproval = '/waitingApproval';
  static const String dashboard = '/dashboard';
  static const String locationPermission = '/locationPermission';
  static const String reservationhistory = '/reservationHistory';
  static const String ridePending = '/ridePending';
  static const String pendingReservation = '/pendingReservation';
  static const String activeRide = '/activeRide';
  static const String chat = '/chat';
  static const String deleteacc = '/deleteAccount';
  static const String rideHistory = '/rideHistory';
  static const String completedRideDetail = '/completedRideDetail';
  static const String reviewsRatings = '/reviewsRatings';
  static const String profile = '/profile';
  static const String driverDetails = '/driverDetails';
  static const String forgotPassword = '/forgotPassword';
}

class ClippedRtlTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ClipRect(
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: curve ?? Curves.easeInOut,
              ),
            ),
        child: child,
      ),
    );
  }
}
