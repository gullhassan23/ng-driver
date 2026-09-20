import 'package:get/get.dart';

import '../models/ride_model.dart';
import '../routes/app_routes.dart';
import '../utilis/firestore_paths.dart';
import 'ride_history_feed_controller.dart';

class ReviewsRatingsController extends GetxController {
  /// `0` = all ratings; `1`–`5` = that star count.
  final selectedFilter = 0.obs;
  final reviews = <RideModel>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString(null);

  Worker? _feedWorker;

  List<RideModel> get filteredReviews {
    final filter = selectedFilter.value;
    if (filter < 1 || filter > 5) return List<RideModel>.from(reviews);
    return reviews.where((ride) => ride.riderRating == filter).toList();
  }

  int get reviewCount => reviews.length;

  double get averageRating {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<int>(
      0,
      (sum, ride) => sum + (ride.riderRating ?? 0),
    );
    return total / reviews.length;
  }

  String get formattedAverage {
    if (reviews.isEmpty) return '—';
    return averageRating.toStringAsFixed(1);
  }

  Map<int, int> get starCounts {
    final counts = <int, int>{for (var star = 1; star <= 5; star++) star: 0};
    for (final ride in reviews) {
      final rating = ride.riderRating;
      if (rating == null) continue;
      counts[rating] = (counts[rating] ?? 0) + 1;
    }
    return counts;
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
    reviews.assignAll(
      feed.history.where((ride) {
        return ride.status == RideStatus.completed && ride.hasRiderRating;
      }),
    );
    isLoading.value = feed.isLoading.value;
    errorMessage.value = feed.errorMessage.value;
  }

  void selectFilter(int stars) {
    selectedFilter.value = stars;
  }

  void openDetail(RideModel ride) {
    Get.toNamed(AppRoutes.completedRideDetail, arguments: ride);
  }

  void retry() {
    _feed.retry();
  }
}
