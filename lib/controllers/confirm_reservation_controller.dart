import 'package:get/get.dart';

import '../models/reservation_model.dart';
import '../utilis/firestore_paths.dart';
import '../widgets/app_snackbar_widget.dart';
import 'auth_controller.dart';
import 'dashboard_controller.dart';
import 'reservation_detail_controller.dart';
import 'reservation_feed_controller.dart';

class ConfirmReservationController extends GetxController {
  final reservations = <ReservationModel>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString(null);

  Worker? _feedWorker;
  final Map<String, String> _statusById = <String, String>{};

  List<ReservationModel> get confirmedReservations {
    return reservations
        .where((item) => ReservationStatus.isConfirmedOrActive(item.status))
        .toList();
  }

  ReservationFeedController get _feed {
    if (!Get.isRegistered<ReservationFeedController>()) {
      Get.put(ReservationFeedController(), permanent: false);
    }
    return Get.find<ReservationFeedController>();
  }

  @override
  void onInit() {
    super.onInit();
    _bindToFeed();
  }

  @override
  void onClose() {
    _feedWorker?.dispose();
    super.onClose();
  }

  void _bindToFeed() {
    final feed = _feed;
    feed.ensureListening();
    _syncFromFeed(feed);
    _feedWorker?.dispose();
    _feedWorker = everAll(
      [feed.reservations, feed.isLoading, feed.errorMessage],
      (_) => _syncFromFeed(feed),
    );
  }

  void _syncFromFeed(ReservationFeedController feed) {
    _notifyIfAssignedReservationCompleted(feed.reservations.toList());
    reservations.assignAll(feed.reservations);
    isLoading.value = feed.isLoading.value;
    errorMessage.value = feed.errorMessage.value;
  }

  void _notifyIfAssignedReservationCompleted(List<ReservationModel> items) {
    // Detail screen handles its own navigation + snackbar.
    if (Get.isRegistered<ReservationDetailController>()) {
      _rememberStatuses(items);
      return;
    }

    final uid =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>().uid : null;
    var shouldNotify = false;
    if (uid != null && _statusById.isNotEmpty) {
      for (final item in items) {
        final previous = _statusById[item.id];
        if (previous == null) continue;
        if (item.driverId != uid) continue;
        if (!ReservationStatus.isCompleted(previous) &&
            ReservationStatus.isCompleted(item.status)) {
          shouldNotify = true;
          break;
        }
      }
    }

    _rememberStatuses(items);
    if (!shouldNotify) return;

    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().selectNav(
        DashboardController.homeNavIndex,
      );
    }
    AppSnackbar.success(title: 'Reservation completed');
  }

  void _rememberStatuses(List<ReservationModel> items) {
    _statusById
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.id, item.status)));
  }

  void retry() {
    _feed.retry();
  }
}
