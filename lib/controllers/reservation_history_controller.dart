import 'package:get/get.dart';

import '../models/reservation_model.dart';
import '../utilis/firestore_paths.dart';
import 'reservation_feed_controller.dart';

class ReservationHistoryController extends GetxController {
  static const int filterAll = 0;
  static const int filterCompleted = 1;
  static const int filterCancelled = 2;

  final selectedFilter = 0.obs;
  final reservations = <ReservationModel>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString(null);

  Worker? _feedWorker;

  List<ReservationModel> get filteredReservations {
    final filter = selectedFilter.value;
    // Pending lives on the Pending Reservation tab; confirmed/active on
    // Confirm Reservation (opened after accept). History keeps completed +
    // cancelled only.
    final source = reservations
        .where(
          (item) =>
              !ReservationStatus.isConfirmedOrActive(item.status) &&
              item.status.toLowerCase() != ReservationStatus.pending,
        )
        .toList();

    if (filter == filterCompleted) {
      return source
          .where((item) => ReservationStatus.isCompleted(item.status))
          .toList();
    }
    if (filter == filterCancelled) {
      return source
          .where((item) => ReservationStatus.isCancelled(item.status))
          .toList();
    }
    return source;
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
    _applyLaunchArguments();
    _bindToFeed();
  }

  @override
  void onReady() {
    super.onReady();
    // Re-apply args when a shared instance is opened again via Get.toNamed.
    _applyLaunchArguments();
  }

  void _applyLaunchArguments() {
    final args = Get.arguments;
    if (args is Map) {
      final filter = args['reservationFilter'];
      if (filter is int) selectedFilter.value = filter;
    }
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
    reservations.assignAll(feed.reservations);
    isLoading.value = feed.isLoading.value;
    errorMessage.value = feed.errorMessage.value;
  }

  void selectFilter(int index) {
    selectedFilter.value = index;
  }

  void retry() {
    _feed.retry();
  }
}
