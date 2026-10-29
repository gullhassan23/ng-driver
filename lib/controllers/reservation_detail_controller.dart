import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/reservation_model.dart';
import '../models/ride_model.dart';
import '../routes/app_navigator.dart';
import '../routes/app_routes.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../utilis/app_colors.dart';
import '../utilis/chat_constants.dart';
import '../utilis/firestore_paths.dart';
import '../widgets/app_blur_dialog.dart';
import '../widgets/app_snackbar_widget.dart';
import '../widgets/ride/cancel_reason_dialog.dart';
import 'auth_controller.dart';
import 'dashboard_controller.dart';

class ReservationDetailController extends GetxController {
  ReservationDetailController({
    required ReservationModel reservation,
    FirestoreService? firestore,
    ChatService? chatService,
  })  : reservation = reservation.obs,
        _firestore = firestore ?? FirestoreService(),
        _chatService = chatService ?? ChatService();

  final Rx<ReservationModel> reservation;
  final FirestoreService _firestore;
  final ChatService _chatService;

  final isSubmitting = false.obs;
  final isScheduledTimeArrived = false.obs;
  final chatUnreadCount = 0.obs;

  StreamSubscription<ReservationModel?>? _reservationSubscription;
  StreamSubscription<int>? _chatUnreadSubscription;
  Timer? _scheduleTimer;
  bool _leftForCompleted = false;
  bool _leftForCancelled = false;
  bool _unreadErrorShown = false;
  String? _boundUnreadReservationId;

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

  /// Confirmed future booking (no live ride yet) that this driver may cancel.
  bool get canCancelReservation {
    final current = reservation.value;
    if (!ReservationStatus.isConfirm(current.status)) return false;
    final rideId = current.rideId?.trim() ?? '';
    if (rideId.isNotEmpty) return false;
    final uid = Get.isRegistered<AuthController>()
        ? (Get.find<AuthController>().uid?.trim() ?? '')
        : '';
    final assigned = current.driverId?.trim() ?? '';
    return uid.isNotEmpty && assigned.isNotEmpty && assigned == uid;
  }

  /// True when the signed-in driver may open reservation chat.
  bool get canOpenChat {
    final current = reservation.value;
    final resId = current.id.trim();
    if (resId.isEmpty) return false;
    final uid = Get.isRegistered<AuthController>()
        ? (Get.find<AuthController>().uid?.trim() ?? '')
        : '';
    final assignedDriverId = current.driverId?.trim() ?? '';
    return uid.isNotEmpty &&
        assignedDriverId.isNotEmpty &&
        assignedDriverId == uid &&
        ReservationStatus.isConfirmedOrActive(current.status);
  }

  @override
  void onInit() {
    super.onInit();
    _updateScheduledTimeState();
    ever(reservation, (_) {
      _updateScheduledTimeState();
      _syncChatUnreadWatch();
    });
    _watchReservation();
    _syncChatUnreadWatch();
  }

  @override
  void onClose() {
    _scheduleTimer?.cancel();
    _reservationSubscription?.cancel();
    _stopChatUnreadWatch();
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
        if (live == null || _leftForCompleted || _leftForCancelled) return;
        final previous = reservation.value;
        final wasCompleted = ReservationStatus.isCompleted(previous.status);
        final wasCancelled = ReservationStatus.isCancelled(previous.status);
        reservation.value = live;
        if (!wasCompleted && ReservationStatus.isCompleted(live.status)) {
          _leaveAfterCompleted();
          return;
        }
        if (!wasCancelled && ReservationStatus.isCancelled(live.status)) {
          _leaveAfterCancelled(live);
        }
      },
      onError: (Object _) {
        // Keep the last known snapshot; list/history still reflects Firestore.
      },
    );
  }

  void _leaveAfterCancelled(ReservationModel live) {
    if (_leftForCancelled || _leftForCompleted) return;
    _leftForCancelled = true;
    unawaited(_reservationSubscription?.cancel() ?? Future<void>.value());

    final message = live.wasCancelledByDriver
        ? 'Reservation cancelled.'
        : live.wasCancelledByRider
            ? 'The customer cancelled this reservation.'
            : 'This reservation was cancelled.';

    if (Get.key.currentState?.canPop() == true) {
      Get.back();
    } else if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>()
          .selectNav(DashboardController.reservationNavIndex);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppSnackbar.info(title: 'Reservation cancelled', message: message);
    });
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

  /// Cancels an accepted future reservation (not a pending offer decline).
  Future<void> cancelReservation() async {
    if (isSubmitting.value || !canCancelReservation) return;

    final reason = await CancelReasonDialog.show(
      title: 'Why do you want to cancel the reservation?',
    );
    if (reason == null || reason.trim().isEmpty || isClosed) return;

    final confirmed = await showAppBlurGetDialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.inputBackground,
        title: const Text(
          'Cancel reservation?',
          style: TextStyle(color: AppColors.white),
        ),
        content: const Text(
          'The customer will be notified and this booking will end. '
          'It will be removed from your schedule. '
          'This is not a customer cancellation.',
          style: TextStyle(color: AppColors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Keep reservation'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'Cancel reservation',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || isClosed) return;

    final uid = Get.find<AuthController>().uid;
    if (uid == null) return;

    isSubmitting.value = true;
    try {
      await _firestore.cancelConfirmedReservation(
        reservationId: reservation.value.id,
        driverId: uid,
        cancellationReason: reason.trim(),
      );
      if (isClosed) return;

      AppSnackbar.success(
        title: 'Reservation cancelled',
        message: 'The customer has been notified.',
      );

      if (Get.key.currentState?.canPop() == true) {
        Get.back();
      } else if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>()
            .selectNav(DashboardController.reservationNavIndex);
      }
    } on FirebaseFunctionsException catch (error) {
      if (isClosed) return;
      AppSnackbar.error(
        title: 'Could not cancel',
        message: error.message ?? 'Reservation could not be cancelled.',
      );
    } on StateError catch (error) {
      if (isClosed) return;
      AppSnackbar.error(
        title: 'Could not cancel',
        message: error.message,
      );
    } on FirebaseException catch (error) {
      if (isClosed) return;
      AppSnackbar.error(
        title: 'Could not cancel',
        message: error.message ?? 'Reservation could not be cancelled.',
      );
    } catch (_) {
      if (isClosed) return;
      AppSnackbar.error(
        title: 'Could not cancel',
        message: 'Reservation could not be cancelled.',
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Opens chat for this reservation with the rider.
  void openChat() {
    final current = reservation.value;
    final resId = current.id.trim();
    if (resId.isEmpty) {
      AppSnackbar.error(
        title: ChatConstants.title,
        message: ChatConstants.reservationNotFound,
      );
      return;
    }

    final uid = Get.find<AuthController>().uid?.trim() ?? '';
    final assignedDriverId = current.driverId?.trim() ?? '';

    if (assignedDriverId.isEmpty || assignedDriverId != uid) {
      AppSnackbar.info(
        title: ChatConstants.title,
        message: ChatConstants.reservationChatUnavailable,
      );
      return;
    }

    if (!ReservationStatus.isConfirmedOrActive(current.status)) {
      AppSnackbar.info(
        title: ChatConstants.sessionEndedTitle,
        message: ChatConstants.reservationSessionEnded,
      );
      return;
    }

    final rId = current.rideId?.trim();
    AppNavigator.toReservationChat(
      reservationId: resId,
      reservation: current,
      rideId: (rId != null && rId.isNotEmpty) ? rId : null,
    );
  }

  void _syncChatUnreadWatch() {
    if (!canOpenChat) {
      _stopChatUnreadWatch();
      return;
    }
    final resId = reservation.value.id.trim();
    if (_boundUnreadReservationId == resId &&
        _chatUnreadSubscription != null) {
      return;
    }
    _startChatUnreadWatch(resId);
  }

  void _startChatUnreadWatch(String reservationId) {
    final id = reservationId.trim();
    if (id.isEmpty) {
      _stopChatUnreadWatch();
      return;
    }

    _stopChatUnreadWatch();
    _boundUnreadReservationId = id;
    _unreadErrorShown = false;
    _chatUnreadSubscription = _chatService
        .watchUnreadFromRiderCount(id, isReservation: true)
        .listen(
          (unread) {
            chatUnreadCount.value = unread < 0 ? 0 : unread;
          },
          onError: (Object error) {
            chatUnreadCount.value = 0;
            if (_unreadErrorShown) return;
            _unreadErrorShown = true;
            final message = error is ChatServiceException
                ? error.message
                : ChatConstants.unreadWatchFailed;
            AppSnackbar.error(
              title: ChatConstants.loadFailedTitle,
              message: message,
            );
          },
        );
  }

  void _stopChatUnreadWatch() {
    _chatUnreadSubscription?.cancel();
    _chatUnreadSubscription = null;
    _boundUnreadReservationId = null;
    chatUnreadCount.value = 0;
  }
}
