import 'package:get/get.dart';

import '../models/reservation_model.dart';
import '../utilis/firestore_paths.dart';
import 'reservation_feed_controller.dart';

class PendingReservationController extends GetxController {
  final reservations = <ReservationModel>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString(null);

  Worker? _feedWorker;

  List<ReservationModel> get pendingReservations {
    return reservations
        .where(
          (item) => item.status.toLowerCase() == ReservationStatus.pending,
        )
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
    reservations.assignAll(feed.reservations);
    isLoading.value = feed.isLoading.value;
    errorMessage.value = feed.errorMessage.value;
  }

  void retry() {
    _feed.retry();
  }
}
