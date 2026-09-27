// import 'dart:async';

// import 'package:flutter/widgets.dart';
// import 'package:get/get.dart';

// import '../models/ride_model.dart';
// import '../routes/app_routes.dart';
// import '../services/firestore_service.dart';

// /// Live ride receipt / rating for the completed-ride detail screen.
// class RideDetailController extends GetxController {
//   RideDetailController({FirestoreService? firestore})
//       : _firestore = firestore ?? FirestoreService();

//   final FirestoreService _firestore;

//   final ride = Rxn<RideModel>();
//   final returnToDashboard = false.obs;
//   final missingRide = false.obs;

//   StreamSubscription<RideModel?>? _rideSubscription;
//   bool _closeScheduled = false;
//   bool _missingCloseQueued = false;

//   @override
//   void onInit() {
//     super.onInit();
//     _hydrateFromArgs();
//   }

//   @override
//   void onClose() {
//     _rideSubscription?.cancel();
//     super.onClose();
//   }

//   void _hydrateFromArgs() {
//     final args = Get.arguments;
//     RideModel? initial;
//     var goDashboard = false;

//     if (args is RideModel) {
//       initial = args;
//     } else if (args is Map) {
//       if (args['ride'] is RideModel) {
//         initial = args['ride'] as RideModel;
//       }
//       goDashboard = args['returnToDashboard'] == true;
//     }

//     returnToDashboard.value = goDashboard;

//     if (initial == null) {
//       missingRide.value = true;
//       return;
//     }

//     ride.value = initial;
//     _watchRideRating(initial.id);
//   }

//   void _watchRideRating(String rideId) {
//     if (rideId.isEmpty) return;
//     _rideSubscription?.cancel();
//     _rideSubscription = _firestore.watchRide(rideId).listen((updated) {
//       if (updated == null) return;
//       ride.value = updated;
//     });
//   }

//   /// Queues a single post-frame close when args were missing.
//   void queueCloseIfMissing() {
//     if (!missingRide.value || _missingCloseQueued) return;
//     _missingCloseQueued = true;
//     WidgetsBinding.instance.addPostFrameCallback((_) => close());
//   }

//   void close() {
//     if (_closeScheduled) return;
//     _closeScheduled = true;
//     if (returnToDashboard.value) {
//       Get.offAllNamed(AppRoutes.dashboard);
//       return;
//     }
//     if (Get.key.currentState?.canPop() ?? false) {
//       Get.back();
//     } else {
//       Get.offAllNamed(AppRoutes.dashboard);
//     }
//   }
// }

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../models/ride_model.dart';
import '../routes/app_routes.dart';
import '../services/firestore_service.dart';

/// Live ride receipt / rating / cancellation view model.
class RideDetailController extends GetxController {
  RideDetailController({FirestoreService? firestore})
    : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  final ride = Rxn<RideModel>();
  final returnToDashboard = false.obs;
  final missingRide = false.obs;

  // Canceled state check karne ke liye reactive status
  final isCanceled = false.obs;

  StreamSubscription<RideModel?>? _rideSubscription;
  bool _closeScheduled = false;
  bool _missingCloseQueued = false;

  @override
  void onInit() {
    super.onInit();
    _hydrateFromArgs();
  }

  @override
  void onClose() {
    _rideSubscription?.cancel();
    super.onClose();
  }

  void _hydrateFromArgs() {
    final args = Get.arguments;
    RideModel? initial;
    var goDashboard = false;

    if (args is RideModel) {
      initial = args;
    } else if (args is Map) {
      if (args['ride'] is RideModel) {
        initial = args['ride'] as RideModel;
      }
      goDashboard = args['returnToDashboard'] == true;
      if (args['isCanceled'] == true) {
        isCanceled.value = true;
      }
    }

    returnToDashboard.value = goDashboard;

    if (initial == null) {
      missingRide.value = true;
      return;
    }

    ride.value = initial;
    _checkAndSetCanceledState(initial);
    _watchRideRating(initial.id);
  }

  void _checkAndSetCanceledState(RideModel model) {
    if (model.status.toString().toLowerCase().contains('cancel') ||
        model.cancelledAt != null) {
      isCanceled.value = true;
    }
  }

  void _watchRideRating(String rideId) {
    if (rideId.isEmpty) return;
    _rideSubscription?.cancel();
    _rideSubscription = _firestore.watchRide(rideId).listen((updated) {
      if (updated == null) return;
      ride.value = updated;
      _checkAndSetCanceledState(updated);
    });
  }

  /// Queues a single post-frame close when args were missing.
  void queueCloseIfMissing() {
    if (!missingRide.value || _missingCloseQueued) return;
    _missingCloseQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => close());
  }

  void close() {
    if (_closeScheduled) return;
    _closeScheduled = true;
    if (returnToDashboard.value) {
      Get.offAllNamed(AppRoutes.dashboard);
      return;
    }
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    } else {
      Get.offAllNamed(AppRoutes.dashboard);
    }
  }
}
