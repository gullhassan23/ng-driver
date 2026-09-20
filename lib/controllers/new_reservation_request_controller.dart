import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/reservation_model.dart';
import '../routes/app_routes.dart';
import '../services/firestore_service.dart';
import '../views/reservations/confirm_reservation.dart';
import '../widgets/app_snackbar_widget.dart';
import 'auth_controller.dart';
import 'confirm_reservation_controller.dart';
import 'dashboard_controller.dart';
import 'reservation_feed_controller.dart';

enum ReservationSubmitAction { accept, decline }

class NewReservationRequestController extends GetxController {
  NewReservationRequestController({
    required this.reservation,
    FirestoreService? firestore,
  }) : _firestore = firestore ?? FirestoreService();

  final ReservationModel reservation;
  final FirestoreService _firestore;

  final submittingAction = Rxn<ReservationSubmitAction>();

  bool get isBusy => submittingAction.value != null;

  Future<void> accept() async {
    if (isBusy) return;

    final uid = Get.find<AuthController>().uid;
    if (uid == null) return;

    if (Get.isRegistered<DashboardController>()) {
      final activeId = Get.find<DashboardController>().currentRideId.value;
      if (activeId != null && activeId.isNotEmpty) {
        AppSnackbar.error(
          title: 'Already on a ride',
          message:
              'Finish or cancel your current ride before accepting a reservation.',
        );
        return;
      }
    }

    submittingAction.value = ReservationSubmitAction.accept;
    try {
      await _firestore.confirmReservation(
        reservationId: reservation.id,
        driverId: uid,
      );

      if (isClosed) return;

      AppSnackbar.success(
        title: 'Success',
        message: 'reservation book successfully',
      );

      _openConfirmedReservations();
    } on StateError catch (error) {
      AppSnackbar.error(
        title: 'Could not accept',
        message: error.message,
      );
    } on FirebaseException catch (error) {
      AppSnackbar.error(
        title: 'Could not accept',
        message: error.message ?? 'Reservation is no longer available.',
      );
    } catch (_) {
      AppSnackbar.error(
        title: 'Could not accept',
        message: 'Reservation is no longer available.',
      );
    } finally {
      submittingAction.value = null;
    }
  }

  void _openConfirmedReservations() {
    // Prefer returning to the main shell Confirm tab (index 1).
    if (Get.isRegistered<DashboardController>()) {
      final navigator = Get.key.currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) {
          return route.isFirst || route.settings.name == AppRoutes.dashboard;
        });
      }
      Get.find<DashboardController>().selectNav(1);
      return;
    }

    Get.to(
      () => const ConfirmReservation(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<ReservationFeedController>()) {
          Get.put(ReservationFeedController());
        }
        if (!Get.isRegistered<ConfirmReservationController>()) {
          Get.put(ConfirmReservationController());
        }
      }),
    );
  }

  Future<void> decline() async {
    if (isBusy) return;

    submittingAction.value = ReservationSubmitAction.decline;
    try {
      // Local dismiss only — do not cancel the booking for other drivers.
      if (!Get.isRegistered<ReservationFeedController>()) {
        Get.put(ReservationFeedController());
      }
      Get.find<ReservationFeedController>().dismissLocally(reservation.id);

      AppSnackbar.info(
        title: 'Reservation declined',
        message: 'This reservation was hidden from your list.',
      );

      Get.back();
    } finally {
      submittingAction.value = null;
    }
  }
}
