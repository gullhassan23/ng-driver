import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../models/reservation_model.dart';
import '../models/ride_model.dart';
import '../routes/app_routes.dart';
import '../services/firestore_service.dart';
import '../utilis/firestore_paths.dart';
import '../widgets/app_snackbar_widget.dart';
import 'auth_controller.dart';
import 'dashboard_controller.dart';

class ReservationDetailController extends GetxController {
  ReservationDetailController({
    required ReservationModel reservation,
    FirestoreService? firestore,
  })  : reservation = reservation.obs,
        _firestore = firestore ?? FirestoreService();

  final Rx<ReservationModel> reservation;
  final FirestoreService _firestore;

  final isSubmitting = false.obs;
  final isScheduledTimeArrived = false.obs;

  StreamSubscription<ReservationModel?>? _reservationSubscription;
  Timer? _scheduleTimer;
  bool _leftForCompleted = false;

  bool get canStartRide {
    final current = reservation.value;
    return ReservationStatus.isConfirm(current.status) &&
        (current.rideId == null || current.rideId!.isEmpty);
  }

  bool get isStartRideEnabled =>
      canStartRide && isScheduledTimeArrived.value;

  bool get canContinueRide {
    final current = reservation.value;
    final hasRideId =
        current.rideId != null && current.rideId!.isNotEmpty;
    if (!hasRideId) return false;
    return ReservationStatus.isConfirm(current.status) ||
        ReservationStatus.isLiveActive(current.status);
  }

  @override
  void onInit() {
    super.onInit();
    _updateScheduledTimeState();
    ever(reservation, (_) => _updateScheduledTimeState());
    _watchReservation();
  }

  @override
  void onClose() {
    _scheduleTimer?.cancel();
    _reservationSubscription?.cancel();
    super.onClose();
  }

  void _updateScheduledTimeState() {
    _scheduleTimer?.cancel();
    _scheduleTimer = null;

    final current = reservation.value;
    final scheduled = current.scheduledDateTime;

    if (scheduled == null) {
      isScheduledTimeArrived.value = false;
      return;
    }

    final now = DateTime.now();
    if (!now.isBefore(scheduled)) {
      isScheduledTimeArrived.value = true;
    } else {
      isScheduledTimeArrived.value = false;
      final duration = scheduled.difference(now);
      _scheduleTimer = Timer(duration, () {
        _updateScheduledTimeState();
      });
    }
  }

  void _watchReservation() {
    _reservationSubscription?.cancel();
    _reservationSubscription =
        _firestore.watchReservation(reservation.value.id).listen(
      (live) {
        if (live == null || _leftForCompleted) return;
        final wasCompleted =
            ReservationStatus.isCompleted(reservation.value.status);
        reservation.value = live;
        if (!wasCompleted && ReservationStatus.isCompleted(live.status)) {
          _leaveAfterCompleted();
        }
      },
      onError: (Object _) {
        // Keep the last known snapshot; list/history still reflects Firestore.
      },
    );
  }

  void _leaveAfterCompleted() {
    if (_leftForCompleted) return;
    _leftForCompleted = true;
    unawaited(_reservationSubscription?.cancel() ?? Future<void>.value());

    final uid =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>().uid : null;
    final rideId = reservation.value.rideId;
    if (uid != null && rideId != null && rideId.isNotEmpty) {
      if (Get.isRegistered<DashboardController>()) {
        final dashboard = Get.find<DashboardController>();
        if (dashboard.currentRideId.value == rideId) {
          dashboard.currentRideId.value = null;
        }
      }
      unawaited(_firestore.clearCurrentRideId(uid));
    }

    Get.offAllNamed(
      AppRoutes.dashboard,
      arguments: {'navIndex': DashboardController.homeNavIndex},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppSnackbar.success(title: 'Reservation completed');
    });
  }

  Future<void> startRide() async {
    if (isSubmitting.value || !canStartRide) return;

    if (!reservation.value.isScheduledTimeArrived) {
      AppSnackbar.error(
        title: 'Could not start ride',
        message:
            'This reservation cannot be started before the scheduled time.',
      );
      return;
    }

    final uid = Get.find<AuthController>().uid;
    if (uid == null) return;

    final current = reservation.value;

    if (!_isAssignedDriver(uid, current)) {
      AppSnackbar.error(
        title: 'Could not start ride',
        message: 'This reservation is assigned to another driver.',
      );
      return;
    }

    if (!current.hasPickupAndDropoffCoords) {
      AppSnackbar.error(
        title: 'Could not start ride',
        message: 'Reservation is missing pickup or drop-off coordinates.',
      );
      return;
    }

    if (_hasConflictingActiveRide()) {
      AppSnackbar.error(
        title: 'Already on a ride',
        message:
            'Finish or cancel your current ride before starting another.',
      );
      return;
    }

    isSubmitting.value = true;
    try {
      final ride = await _firestore.startReservationRide(
        reservationId: current.id,
        driverId: uid,
      );
      _openActiveRide(
        ride,
        title: 'Ride started',
        message:
            'Head to ${ride.pickupLocation.isEmpty ? 'the pickup' : ride.pickupLocation}.',
      );
    } on StateError catch (error) {
      AppSnackbar.error(
        title: 'Could not start ride',
        message: error.message,
      );
    } on FirebaseException catch (error) {
      AppSnackbar.error(
        title: 'Could not start ride',
        message: error.message ?? 'Reservation is no longer available.',
      );
    } catch (_) {
      AppSnackbar.error(
        title: 'Could not start ride',
        message: 'Reservation is no longer available.',
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Opens the linked live ride when [reservation.rideId] is already set.
  Future<void> continueRide() async {
    if (isSubmitting.value || !canContinueRide) return;

    final uid = Get.find<AuthController>().uid;
    if (uid == null) return;

    final current = reservation.value;

    if (!_isAssignedDriver(uid, current)) {
      AppSnackbar.error(
        title: 'Could not open ride',
        message: 'This reservation is assigned to another driver.',
      );
      return;
    }

    final linkedRideId = current.rideId!;
    if (_hasConflictingActiveRide(allowedRideId: linkedRideId)) {
      AppSnackbar.error(
        title: 'Already on a ride',
        message:
            'Finish or cancel your current ride before opening another.',
      );
      return;
    }

    isSubmitting.value = true;
    try {
      // Idempotent: returns the existing linked ride and restores currentRideId.
      final ride = await _firestore.startReservationRide(
        reservationId: current.id,
        driverId: uid,
      );
      _openActiveRide(
        ride,
        title: 'Active ride',
        message: 'Continuing your reservation ride.',
      );
    } on StateError catch (error) {
      AppSnackbar.error(
        title: 'Could not open ride',
        message: error.message,
      );
    } on FirebaseException catch (error) {
      AppSnackbar.error(
        title: 'Could not open ride',
        message: error.message ?? 'Linked ride is no longer available.',
      );
    } catch (_) {
      AppSnackbar.error(
        title: 'Could not open ride',
        message: 'Linked ride is no longer available.',
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  bool _isAssignedDriver(String uid, ReservationModel current) {
    final assigned = current.driverId;
    if (assigned == null || assigned.isEmpty) return true;
    return assigned == uid;
  }

  bool _hasConflictingActiveRide({String? allowedRideId}) {
    if (!Get.isRegistered<DashboardController>()) return false;
    final activeId = Get.find<DashboardController>().currentRideId.value;
    if (activeId == null || activeId.isEmpty) return false;
    if (allowedRideId != null && activeId == allowedRideId) return false;
    return true;
  }

  void _openActiveRide(
    RideModel ride, {
    required String title,
    required String message,
  }) {
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().currentRideId.value = ride.id;
    }

    AppSnackbar.success(title: title, message: message);
    // Keep shell under Active Ride when possible.
    if (Get.key.currentState?.canPop() == true ||
        Get.isRegistered<DashboardController>()) {
      Get.toNamed(AppRoutes.activeRide, arguments: ride);
    } else {
      Get.offAllNamed(AppRoutes.activeRide, arguments: ride);
    }
  }
}
