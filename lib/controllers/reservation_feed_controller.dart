import 'dart:async';

import 'package:get/get.dart';

import '../models/reservation_model.dart';
import '../services/firestore_service.dart';

/// Single shell-scoped Firestore listener for the entire `reservations`
/// collection. Pending / Confirm / History controllers consume this feed
/// instead of opening duplicate `.snapshots()` subscriptions.
class ReservationFeedController extends GetxController {
  ReservationFeedController({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  final reservations = <ReservationModel>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString(null);

  /// Local-only hides so Decline does not cancel for all drivers.
  final Set<String> dismissedReservationIds = <String>{};

  StreamSubscription<List<ReservationModel>>? _subscription;
  bool _started = false;

  @override
  void onInit() {
    super.onInit();
    ensureListening();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _subscription = null;
    _started = false;
    super.onClose();
  }

  void ensureListening() {
    if (_started && _subscription != null) return;
    _started = true;
    isLoading.value = true;
    errorMessage.value = null;
    _subscription?.cancel();

    _subscription = _firestore.watchReservations().listen(
      (items) {
        reservations.assignAll(
          items
              .where((item) => !dismissedReservationIds.contains(item.id))
              .toList(),
        );
        isLoading.value = false;
        errorMessage.value = null;
      },
      onError: (Object _) {
        isLoading.value = false;
        errorMessage.value = 'Could not load reservations';
      },
    );
  }

  /// Hides a pending reservation for this driver only (no Firestore cancel).
  void dismissLocally(String reservationId) {
    dismissedReservationIds.add(reservationId);
    reservations.removeWhere((item) => item.id == reservationId);
  }

  void retry() {
    _started = false;
    ensureListening();
  }
}
