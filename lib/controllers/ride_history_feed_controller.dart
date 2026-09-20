import 'dart:async';

import 'package:get/get.dart';

import '../models/ride_model.dart';
import '../services/firestore_service.dart';
import '../utilis/firestore_paths.dart';
import 'auth_controller.dart';

/// Single shell-scoped listener for `driverRideHistory`.
/// Dashboard stats, ride history, and reviews all consume this feed.
class RideHistoryFeedController extends GetxController {
  RideHistoryFeedController({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  final history = <RideModel>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString(null);

  StreamSubscription<List<RideModel>>? _subscription;
  String? _listeningUid;

  @override
  void onInit() {
    super.onInit();
    ensureListening();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _subscription = null;
    _listeningUid = null;
    super.onClose();
  }

  void ensureListening() {
    final uid = Get.find<AuthController>().uid;
    if (uid == null || uid.isEmpty) {
      history.clear();
      isLoading.value = false;
      errorMessage.value = 'Sign in to view ride history';
      return;
    }

    if (_listeningUid == uid && _subscription != null) return;

    _listeningUid = uid;
    isLoading.value = true;
    errorMessage.value = null;
    _subscription?.cancel();

    _subscription = _firestore.driverRideHistory(uid).listen(
      (items) {
        history.assignAll(items);
        isLoading.value = false;
        errorMessage.value = null;
      },
      onError: (Object _) {
        isLoading.value = false;
        errorMessage.value = 'Could not load ride history';
      },
    );
  }

  void retry() {
    _listeningUid = null;
    ensureListening();
  }

  List<RideModel> get completedRides => history
      .where((ride) => ride.status == RideStatus.completed)
      .toList();

  List<RideModel> get ratedCompletedRides => completedRides
      .where((ride) => ride.hasRiderRating)
      .toList();
}
