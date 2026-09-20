import 'package:get/get.dart';

import '../models/ride_model.dart';
import '../routes/app_routes.dart';
import '../utilis/firestore_paths.dart';
import '../views/rides/ride_history_detail.dart';
import 'ride_history_feed_controller.dart';

class RidesHistoryController extends GetxController {
  final selectedFilter = 0.obs;
  final rides = <RideModel>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString(null);

  Worker? _feedWorker;

  List<RideModel> get filteredRides {
    final filter = selectedFilter.value;
    final source = List<RideModel>.from(rides);

    if (filter == 1) {
      return source
          .where(
            (ride) =>
                RideStatus.normalize(ride.status) == RideStatus.completed,
          )
          .toList();
    }
    if (filter == 2) {
      return source
          .where(
            (ride) =>
                RideStatus.normalize(ride.status) == RideStatus.cancelled,
          )
          .toList();
    }
    return source;
  }

  RideHistoryFeedController get _feed {
    if (!Get.isRegistered<RideHistoryFeedController>()) {
      Get.put(RideHistoryFeedController(), permanent: false);
    }
    return Get.find<RideHistoryFeedController>();
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
      [feed.history, feed.isLoading, feed.errorMessage],
      (_) => _syncFromFeed(feed),
    );
  }

  void _syncFromFeed(RideHistoryFeedController feed) {
    rides.assignAll(feed.history);
    isLoading.value = feed.isLoading.value;
    errorMessage.value = feed.errorMessage.value;
  }

  void selectFilter(int index) {
    selectedFilter.value = index;
  }

  void openDetail(RideModel ride) {
    if (RideStatus.normalize(ride.status) == RideStatus.completed) {
      Get.toNamed(AppRoutes.completedRideDetail, arguments: ride);
      return;
    }
    Get.to(() => RideHistoryDetailView(ride: ride));
  }

  void retry() {
    _feed.retry();
  }
}
