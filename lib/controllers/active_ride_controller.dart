import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ngtowncardriver/routes/app_navigator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reservation_model.dart';
import '../models/ride_model.dart';
import '../models/ride_stop_model.dart';
import '../routes/app_routes.dart';
import '../services/chat_service.dart';
import '../services/directions_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/map_warmup_service.dart';
import '../services/marker_icon_cache.dart';
import '../services/ride_status_evaluator.dart';
import '../utilis/app_colors.dart';
import '../utilis/chat_constants.dart';
import '../utilis/firestore_paths.dart';
import '../utilis/map_route_polyline.dart';
import '../widgets/app_blur_dialog.dart';
import '../widgets/app_snackbar_widget.dart';
import 'auth_controller.dart';
import 'dashboard_controller.dart';

class ActiveRideController extends GetxController with WidgetsBindingObserver {
  ActiveRideController({
    FirestoreService? firestore,
    DirectionsService? directions,
    LocationService? location,
    RideStatusEvaluator? statusEvaluator,
    ChatService? chatService,
  }) : _firestore = firestore ?? FirestoreService(),
       _directions =
           directions ??
           (Get.isRegistered<DirectionsService>()
               ? Get.find<DirectionsService>()
               : DirectionsService()),
       _location =
           location ??
           (Get.isRegistered<LocationService>()
               ? Get.find<LocationService>()
               : LocationService()),
       _statusEvaluator = statusEvaluator ?? RideStatusEvaluator(),
       _chatService = chatService ?? ChatService();

  final FirestoreService _firestore;
  final DirectionsService _directions;
  final LocationService _location;
  final RideStatusEvaluator _statusEvaluator;
  final ChatService _chatService;

  final ride = Rxn<RideModel>();
  final isLoading = true.obs;
  final errorMessage = RxnString(null);
  final isUpdating = false.obs;

  /// Remaining pickup ETA; null when hidden or unknown.
  final remainingEta = Rxn<Duration>();

  final markers = <Marker>{}.obs;
  final polylines = <Polyline>{}.obs;
  final routeEtaText = ''.obs;
  final routeDistanceText = ''.obs;
  final driverPosition = Rxn<LatLng>();
  final routeError = RxnString(null);
  final nearDropoff = false.obs;

  /// Unread rider messages for the Active Ride chat badge.
  final chatUnreadCount = 0.obs;

  /// When true, the map camera follows the driver's GPS updates.
  final isFollowingDriver = true.obs;

  GoogleMapController? _mapController;
  StreamSubscription<RideModel?>? _rideSubscription;
  StreamSubscription<ReservationModel?>? _reservationSubscription;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<int>? _chatUnreadSubscription;
  Timer? _etaTimer;
  Timer? _routeDebounce;
  Timer? _locationWriteRetry;
  Timer? _proximityPollTimer;
  bool _exiting = false;
  bool _driverInitiatedCancel = false;
  bool _routeFetchInFlight = false;
  bool _pendingRouteRefresh = false;
  bool _pendingRouteForce = false;
  bool _pendingRouteFit = false;
  bool _locationWriteInFlight = false;
  bool _arrivingWriteInFlight = false;
  bool _pickupArrivalWritten = false;
  bool _completionWriteInFlight = false;
  bool _stopAdvanceWriteInFlight = false;
  String? _lastRouteKey;
  DateTime? _lastRouteFetchAt;
  bool _routeErrorSnackShown = false;
  bool _cameraFittedForPhase = false;
  bool _locationPermissionSnackShown = false;
  bool _programmaticCameraMove = false;
  LatLng? _lastPersistedLocation;
  DateTime? _lastPersistedAt;
  double? _lastHeading;
  bool _lifecycleErrorSnackShown = false;

  /// Latest GPS fix waiting while a Firestore location write is in flight.
  LatLng? _pendingLocationWrite;
  double? _pendingLocationHeading;

  /// Debounce GPS stream restarts after error/done.
  DateTime? _lastLocationRestartAt;
  bool _locationTrackingDown = false;
  int _rideSnapshotGeneration = 0;
  int _routeRequestGeneration = 0;

  /// GPS position when the ride was (or became) `accepted` this session.
  LatLng? _acceptedAnchor;
  double? _lastLoggedPickupDistance;

  static const _driverMarkerId = MarkerId('driver');
  static const _minRouteRefresh = Duration(seconds: 12);
  static const _locationPersistMinMeters = 15.0;
  static const _locationPersistMaxInterval = Duration(seconds: 8);

  /// Re-check pickup/dropoff even when the GPS stream is quiet (driver stopped).
  static const _proximityPollInterval = Duration(seconds: 3);

  /// Throttle camera follow so hybrid maps are not blanked by constant animateCamera.
  static const _cameraFollowMinMeters = 12.0;
  static const _cameraFollowMinInterval = Duration(milliseconds: 900);

  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  BitmapDescriptor? _stopIcon;
  LatLng? _lastCameraFollowPos;
  DateTime? _lastCameraFollowAt;
  LatLng? _lastDriverMarkerPos;

  /// Frozen once for GoogleMap init — never read reactive fields for this.
  LatLng? _frozenInitialCameraTarget;

  /// Stable camera seed for [AppMapWidget]. Prefer pickup → dropoff → cache.
  /// Never falls back to Seattle in production (avoids wrong-city flash).
  LatLng get initialCameraTarget =>
      _frozenInitialCameraTarget ?? const LatLng(0, 0);

  void _freezeInitialCameraTarget(LatLng? target) {
    if (_frozenInitialCameraTarget != null || target == null) return;
    // Ignore (0,0) sentinel used only when no real seed exists yet.
    if (target.latitude == 0 && target.longitude == 0) return;
    _frozenInitialCameraTarget = target;
  }

  bool get isDriverArriving {
    final current = ride.value;
    if (current == null) return false;
    return current.status == RideStatus.driverArriving ||
        current.isPreArrivingAssigned;
  }

  bool get isDriverArrived => ride.value?.isDriverArrived ?? false;

  /// Arrived at pickup, waiting for passenger and/or Start Ride — keep map still.
  bool get isWaitingAtPickup {
    if (ride.value?.isTripInProgress ?? false) return false;
    return _pickupArrivalWritten || (ride.value?.isWaitingAtPickup ?? false);
  }

  bool get isRideStarted => ride.value?.isTripInProgress ?? false;

  bool get showStartRide => ride.value?.canStart ?? false;

  /// At pickup but rider has not yet sent `passenger_arriving`.
  bool get showWaitingForPassenger {
    final current = ride.value;
    if (current == null || current.isTripInProgress) return false;
    if (showStartRide) return false;
    return current.isDriverArrived || _pickupArrivalWritten;
  }

  bool get showCompleteRide =>
      (ride.value?.canComplete ?? false) && nearDropoff.value;

  bool get showPrimaryCta => showStartRide || showCompleteRide;

  String get statusLabel {
    final current = ride.value;
    if (current == null) return '';
    if (current.isTripInProgress) {
      if (nearDropoff.value) return 'Arrived at dropoff';
      if (current.hasRemainingStops) {
        return 'Heading to Stop ${current.currentStopDisplayNumber}';
      }
      return 'Heading to dropoff';
    }
    if (current.isPassengerArriving) return 'Passenger is coming';
    if (current.isDriverArrived || _pickupArrivalWritten) {
      return 'Arrived at pickup';
    }
    if (current.status == RideStatus.driverArriving ||
        current.isPreArrivingAssigned) {
      return 'Heading to pickup';
    }
    return current.status;
  }

  bool get showEtaTimer {
    final current = ride.value;
    if (current == null) return false;
    if (current.isTripInProgress) return false;
    if (current.isWaitingAtPickup) return false;
    if (current.hasRiderArrived) return false;
    return current.isPreArrivingAssigned ||
        current.status == RideStatus.driverArriving ||
        current.status == RideStatus.riderArrived;
  }

  bool get showRiderArrivedBanner {
    final current = ride.value;
    if (current == null) return false;
    return current.hasRiderArrived && !current.isTripInProgress;
  }

  String get etaLabel {
    final remaining = remainingEta.value;
    if (remaining == null) return '0:00';
    final totalSeconds = remaining.inSeconds.clamp(0, 99 * 60);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get primaryCtaLabel {
    if (showCompleteRide) return 'Complete Ride';
    if (showStartRide) return 'Start Ride';
    if (isRideStarted) return 'Complete Ride';
    return 'Start Ride';
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    if (Get.isRegistered<MapWarmupService>()) {
      Get.find<MapWarmupService>().warmInBackground(requestPermission: false);
    }
    _bootstrap();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _etaTimer?.cancel();
    _routeDebounce?.cancel();
    _locationWriteRetry?.cancel();
    _proximityPollTimer?.cancel();
    _rideSubscription?.cancel();
    _reservationSubscription?.cancel();
    _positionSubscription?.cancel();
    _stopChatUnreadWatch();
    _mapController = null;
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _exiting || isClosed) return;
    if (_locationTrackingDown || _positionSubscription == null) {
      unawaited(_restartLocationTracking());
    }
  }

  Future<void> _bootstrap() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final args = Get.arguments;
      RideModel? initial;

      if (args is RideModel) {
        initial = await _firestore.fetchRide(args.id) ?? args;
      } else if (args is Map && args['rideId'] is String) {
        initial = await _firestore.fetchRide(args['rideId'] as String);
      } else {
        final uid = Get.find<AuthController>().uid;
        if (uid == null) {
          // Get.offAllNamed(AppRoutes.signIn);
          AppNavigator.toSignIn();
          return;
        }
        final driver = await _firestore.fetchDriver(uid);
        final rideId = driver?.currentRideId;
        if (rideId == null || rideId.isEmpty) {
          // Get.offAllNamed(AppRoutes.dashboard);
          AppNavigator.todashboard();
          return;
        }
        initial = await _firestore.fetchRide(rideId);
      }

      if (initial == null) {
        await _clearAndExit();
        return;
      }

      if (_isTerminalRideStatus(initial.status)) {
        final normalized = initial.status.toLowerCase().trim();
        if (normalized == RideStatus.completed) {
          await _exitAfterRideCompleted(completedRide: initial);
          return;
        }
        await _clearAndExit(
          message: normalized == RideStatus.expired
              ? 'Ride cancelled.'
              : 'Ride cancelled by user',
        );
        return;
      }

      final uid = Get.find<AuthController>().uid;
      if (uid != null &&
          initial.driverId != null &&
          initial.driverId!.isNotEmpty &&
          initial.driverId != uid) {
        await _clearAndExit(
          message: 'Another driver was selected for this ride.',
        );
        return;
      }

      ride.value = initial;
      _syncArrivalFlags(initial);
      if (isWaitingAtPickup) {
        isFollowingDriver.value = false;
      }

      // Seed marker/camera from stored ride location, then process cache / warmup.
      final storedDriver = initial.driverLatLng;
      final cached =
          _location.cachedPosition ??
          (Get.isRegistered<MapWarmupService>()
              ? Get.find<MapWarmupService>().warmPosition
              : null);
      if (storedDriver != null && driverPosition.value == null) {
        driverPosition.value = storedDriver;
      } else if (cached != null && driverPosition.value == null) {
        driverPosition.value = cached;
      }
      _freezeInitialCameraTarget(
        driverPosition.value ??
            initial.pickupLatLng ??
            initial.dropoffLatLng ??
            LocationService.seattleLatLng,
      );

      // Prefer warm icons so the first paint is not default-hue then swap.
      _applyCachedIconsIfReady();
      if (_driverIcon == null ||
          _pickupIcon == null ||
          _dropoffIcon == null ||
          _stopIcon == null) {
        try {
          await MarkerIconCache.instance.ensureLoaded().timeout(
            const Duration(milliseconds: 900),
          );
        } catch (_) {}
        _applyCachedIconsIfReady();
      }
      _rebuildMarkers(initial);
      _startEtaTicker(initial);
      _watchRide(initial.id);
      _watchLinkedReservation(initial);
      _startChatUnreadWatch(initial.id);

      // Mount the map now — do not wait for GPS or Directions.
      isLoading.value = false;

      unawaited(_continueBootstrapAfterMapVisible());
    } catch (error) {
      errorMessage.value = error.toString();
      isLoading.value = false;
    }
  }

  /// GPS + route after the map is already visible.
  Future<void> _continueBootstrapAfterMapVisible() async {
    if (_exiting) return;
    await _ensureMarkerIcons();
    if (_exiting) return;
    final current = ride.value;
    if (current != null) _rebuildMarkers(current);

    await _startLocationTracking();
    if (_exiting) return;
    await _refreshRoute(force: true, fitCamera: true);
  }

  void _syncArrivalFlags(RideModel current) {
    if (current.status == RideStatus.driverArrived ||
        current.status == RideStatus.passengerArriving ||
        current.isTripInProgress ||
        current.status == RideStatus.completed) {
      _pickupArrivalWritten = true;
    }
    if (!RideStatus.isPreArrivingAssignedStatus(current.status)) {
      _acceptedAnchor = null;
    }
    if (current.isTripInProgress || current.status == RideStatus.completed) {
      _etaTimer?.cancel();
      remainingEta.value = null;
    }
  }

  void _watchRide(String rideId) {
    _rideSubscription?.cancel();
    _rideSubscription = _firestore
        .watchRide(rideId)
        .listen(
          (updated) {
            if (_exiting) return;

            if (updated == null) {
              unawaited(
                _clearAndExit(message: 'This ride is no longer available.'),
              );
              return;
            }

            // Terminal status first — before any await — so cancel always exits.
            // Also schedule exit outside this callback to avoid deadlocking on
            // subscription.cancel() inside the same listen handler.
            if (_isTerminalRideStatus(updated.status)) {
              ride.value = updated;
              if (updated.status.toLowerCase().trim() == RideStatus.completed) {
                unawaited(_exitAfterRideCompleted(completedRide: updated));
              } else {
                unawaited(
                  _clearAndExit(message: _remoteCancelMessage(updated)),
                );
              }
              return;
            }

            unawaited(_onRideSnapshot(updated));
          },
          onError: (Object error, StackTrace stack) {
            if (kDebugMode) {
              debugPrint('watchRide error: $error\n$stack');
            }
            if (!_exiting && !isClosed) {
              errorMessage.value =
                  'Lost connection to this ride. Check internet and retry.';
            }
          },
        );
  }

  void _watchLinkedReservation(RideModel current) {
    _reservationSubscription?.cancel();
    _reservationSubscription = null;

    final reservationId = current.reservationId;
    if (reservationId == null || reservationId.isEmpty) return;

    _reservationSubscription = _firestore
        .watchReservation(reservationId)
        .listen(
          (reservation) {
            if (_exiting || reservation == null) return;
            if (ReservationStatus.isCompleted(reservation.status)) {
              unawaited(_exitAfterRideCompleted(fromReservation: true));
              return;
            }
            if (!ReservationStatus.isCancelled(reservation.status)) {
              return;
            }
            unawaited(_exitBecauseReservationCancelled());
          },
          onError: (Object error, StackTrace stack) {
            debugPrint('watchReservation error: $error\n$stack');
          },
        );
  }

  /// Cancels the linked ride (idempotent) then leaves Active Ride.
  Future<void> _exitBecauseReservationCancelled() async {
    if (_exiting) return;
    _exiting = true;

    final current = ride.value;
    final uid = Get.find<AuthController>().uid;
    if (current != null &&
        uid != null &&
        !_isTerminalRideStatus(current.status)) {
      try {
        await _firestore.updateRideLifecycle(
          rideId: current.id,
          action: 'cancel',
          driverId: uid,
        );
      } catch (error) {
        if (kDebugMode) {
          debugPrint('cancel linked ride after reservation cancel: $error');
        }
      }
    }
    // Reset so _clearAndExit can run its full cleanup path once.
    _exiting = false;
    if (isClosed) return;
    await _clearAndExit(message: 'Your reservation has been cancelled by user');
  }

  bool _isTerminalRideStatus(String status) =>
      RideStatus.isTerminalStatus(status);

  bool _sameStops(List<RideStop> a, List<RideStop> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].order != b[i].order ||
          a[i].latitude != b[i].latitude ||
          a[i].longitude != b[i].longitude ||
          a[i].location != b[i].location) {
        return false;
      }
    }
    return true;
  }

  Future<void> _onRideSnapshot(RideModel updated) async {
    if (_exiting || isClosed) return;
    final generation = ++_rideSnapshotGeneration;

    final previous = ride.value;
    ride.value = updated;
    _syncArrivalFlags(updated);

    // Linked reservation may appear after the first snapshot.
    if (updated.isFromReservation && _reservationSubscription == null) {
      _watchLinkedReservation(updated);
    }

    // Drop stale overlapping handlers.
    if (generation != _rideSnapshotGeneration || _exiting || isClosed) return;

    // Edge-detect only — skip cold restore when previous is null.
    if (previous != null &&
        previous.status != RideStatus.passengerArriving &&
        updated.status == RideStatus.passengerArriving) {
      AppSnackbar.info(title: 'Passenger is coming');
    }

    final arrivedAtPickup =
        updated.isWaitingAtPickup && !updated.isTripInProgress;
    final markersNeedRebuild =
        previous == null ||
        previous.pickupLatLng != updated.pickupLatLng ||
        previous.dropoffLatLng != updated.dropoffLatLng ||
        previous.pickupLocation != updated.pickupLocation ||
        previous.dropoffLocation != updated.dropoffLocation ||
        previous.isTripInProgress != updated.isTripInProgress ||
        previous.currentStopIndex != updated.currentStopIndex ||
        !_sameStops(previous.stops, updated.stops);
    // Status-only snapshots (driver_arrived) must not rebuild markers —
    // that remounts GoogleMap overlays and blanks the map.
    // Exception: entering/leaving ride_started must rebuild so the pickup pin
    // is removed once the trip is in progress.
    if (markersNeedRebuild) {
      _rebuildMarkers(updated);
    }

    // Re-check after sync work in case a concurrent cancel set _exiting.
    if (_exiting || _isTerminalRideStatus(updated.status)) {
      if (!_exiting && _isTerminalRideStatus(updated.status)) {
        if (updated.status.toLowerCase().trim() == RideStatus.completed) {
          await _exitAfterRideCompleted(completedRide: updated);
        } else {
          await _clearAndExit(message: _remoteCancelMessage(updated));
        }
      }
      return;
    }

    final uid = Get.find<AuthController>().uid;
    if (uid != null &&
        updated.driverId != null &&
        updated.driverId!.isNotEmpty &&
        updated.driverId != uid &&
        RideStatus.isActiveAssignedStatus(updated.status)) {
      await _clearAndExit(
        message: 'Another driver was selected for this ride.',
      );
      return;
    }

    if (updated.isTripInProgress) {
      _etaTimer?.cancel();
      remainingEta.value = null;
    } else if (updated.isWaitingAtPickup || updated.hasRiderArrived) {
      _etaTimer?.cancel();
      remainingEta.value = null;
    } else if (RideStatus.isPreArrivingAssignedStatus(updated.status) ||
        updated.status == RideStatus.driverArriving) {
      _startEtaTicker(updated);
    }

    final phaseChanged = previous == null || previous.status != updated.status;
    final stopProgressChanged =
        previous != null &&
        previous.currentStopIndex != updated.currentStopIndex;
    if (phaseChanged || (stopProgressChanged && updated.isTripInProgress)) {
      _lastRouteKey = null;
      if (arrivedAtPickup && phaseChanged) {
        // Freeze follow-camera and skip route/camera work while waiting
        // to start. AnimateCamera + marker Obx here caused the black map
        // and sent Start Ride to the top of the screen.
        isFollowingDriver.value = false;
        routeEtaText.value = '';
        routeDistanceText.value = '';
      } else {
        if (updated.isTripInProgress) {
          isFollowingDriver.value = true;
        }
        _cameraFittedForPhase = false;
        await _refreshRoute(force: true, fitCamera: true);
      }

      if (_exiting) return;

      // Status may change while GPS is quiet (driver stopped). Re-evaluate
      // with the latest known position so arrival/complete are not missed.
      final latestPos = driverPosition.value;
      if (latestPos != null &&
          (updated.status == RideStatus.driverArriving ||
              RideStatus.isPreArrivingAssignedStatus(updated.status) ||
              updated.isTripInProgress)) {
        unawaited(_handleLocationUpdate(latestPos));
      }
    }

    _syncProximityPolling(updated);
  }

  Future<void> _startLocationTracking() async {
    if (_exiting) return;

    await _ensureMarkerIcons();

    final readiness = await _location.ensureReadyForOnline(
      requestIfDenied: false,
    );
    if (readiness != LocationReadiness.ready) {
      // Soft-request once if we never had permission; otherwise show settings.
      final retried = await _location.ensureReadyForOnline(
        requestIfDenied: true,
      );
      if (retried != LocationReadiness.ready) {
        await _showLocationRequired(retried);
        return;
      }
    }

    // Prefer quick/cached fix so the map is not blocked on high-accuracy GPS.
    final current =
        await _location.getPositionQuick() ??
        await _location.getCurrentPosition();
    if (current != null) {
      driverPosition.value = current;
      _location.cachePosition(current);
      _freezeInitialCameraTarget(current);
      if (!isWaitingAtPickup) {
        _syncDriverMarker();
      }
      unawaited(_handleLocationUpdate(current));
      unawaited(_maybePersistDriverLocation(current));
      if (isFollowingDriver.value && !isWaitingAtPickup) {
        unawaited(_animateCameraToDriver(current));
      }
    }

    // Avoid duplicate GPS streams if resume/bootstrap runs again.
    await _positionSubscription?.cancel();
    // Smaller filter so creeping into the pickup radius still emits updates.
    _positionSubscription = _location
        .positionStream(distanceFilterMeters: 5, enableBackground: true)
        .listen(
          (position) {
            if (_exiting || isClosed) return;
            _locationTrackingDown = false;
            final latLng = LatLng(position.latitude, position.longitude);
            _lastHeading = position.heading;
            driverPosition.value = latLng;
            _location.cachePosition(latLng);
            _freezeInitialCameraTarget(latLng);
            unawaited(_handleLocationUpdate(latLng));
            unawaited(
              _maybePersistDriverLocation(latLng, heading: position.heading),
            );

            // Waiting at pickup: do not move the camera or rewrite markers. That
            // churn blanks GoogleMap and mis-composites the bottom sheet.
            if (isWaitingAtPickup) return;

            _syncDriverMarker();
            if (isFollowingDriver.value &&
                !_routeFetchInFlight &&
                !_programmaticCameraMove) {
              unawaited(_animateCameraToDriver(latLng));
            }
            _scheduleRouteRefresh();
          },
          onError: (Object error, StackTrace stack) {
            if (kDebugMode) {
              debugPrint('positionStream error: $error\n$stack');
            }
            _locationTrackingDown = true;
            _positionSubscription = null;
            unawaited(_restartLocationTracking());
          },
          onDone: () {
            _locationTrackingDown = true;
            _positionSubscription = null;
            if (!_exiting && !isClosed) {
              unawaited(_restartLocationTracking());
            }
          },
          cancelOnError: true,
        );

    _syncProximityPolling(ride.value);
  }

  Future<void> _restartLocationTracking() async {
    if (_exiting || isClosed) return;
    final now = DateTime.now();
    final last = _lastLocationRestartAt;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _lastLocationRestartAt = now;

    final readiness = await _location.ensureReadyForOnline(
      requestIfDenied: false,
    );
    if (readiness != LocationReadiness.ready) {
      _locationTrackingDown = true;
      return;
    }

    _locationPermissionSnackShown = false;
    await _startLocationTracking();
  }

  void _syncProximityPolling(RideModel? current) {
    final needsPoll =
        current != null &&
        (RideStatus.isPreArrivingAssignedStatus(current.status) ||
            current.status == RideStatus.driverArriving ||
            current.isTripInProgress);

    if (!needsPoll) {
      _proximityPollTimer?.cancel();
      _proximityPollTimer = null;
      return;
    }

    if (_proximityPollTimer != null) return;

    _proximityPollTimer = Timer.periodic(_proximityPollInterval, (_) {
      unawaited(_pollProximity());
    });
  }

  Future<void> _pollProximity() async {
    if (_exiting) return;
    final current = ride.value;
    if (current == null) return;
    if (!RideStatus.isPreArrivingAssignedStatus(current.status) &&
        current.status != RideStatus.driverArriving &&
        !current.isTripInProgress) {
      _proximityPollTimer?.cancel();
      _proximityPollTimer = null;
      return;
    }

    final fresh = await _location.getCurrentPosition(requestIfDenied: false);
    final position = fresh ?? driverPosition.value;
    if (position == null) return;

    if (fresh != null) {
      final previous = driverPosition.value;
      driverPosition.value = fresh;
      _location.cachePosition(fresh);
      // Skip marker churn when the poll returns an unchanged fix.
      if (previous == null ||
          previous.latitude != fresh.latitude ||
          previous.longitude != fresh.longitude) {
        _syncDriverMarker();
      }
    }
    await _handleLocationUpdate(position);
  }

  Future<void> _stopLocationTracking() async {
    _locationWriteRetry?.cancel();
    _locationWriteRetry = null;
    _proximityPollTimer?.cancel();
    _proximityPollTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  bool get _shouldPersistLocation {
    final current = ride.value;
    if (current == null) return false;
    return RideStatus.isPreArrivingAssignedStatus(current.status) ||
        current.status == RideStatus.driverArriving ||
        current.status == RideStatus.driverArrived ||
        current.status == RideStatus.passengerArriving ||
        current.isTripInProgress ||
        current.status == RideStatus.riderArrived;
  }

  Future<void> _maybePersistDriverLocation(
    LatLng position, {
    double? heading,
    bool force = false,
  }) async {
    if (_exiting || !_shouldPersistLocation) return;

    final rideId = ride.value?.id;
    if (rideId == null || rideId.isEmpty) return;

    final now = DateTime.now();
    final last = _lastPersistedLocation;
    if (!force && last != null) {
      final meters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      final elapsed = _lastPersistedAt == null
          ? _locationPersistMaxInterval
          : now.difference(_lastPersistedAt!);
      final movedEnough = meters >= _locationPersistMinMeters;
      final intervalElapsed = elapsed >= _locationPersistMaxInterval;
      if (!movedEnough && !intervalElapsed) return;
    }

    if (_locationWriteInFlight) {
      _pendingLocationWrite = position;
      _pendingLocationHeading = heading ?? _lastHeading;
      return;
    }
    _locationWriteInFlight = true;

    try {
      await _firestore.updateDriverLocation(
        rideId: rideId,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: heading ?? _lastHeading,
      );
      _lastPersistedLocation = position;
      _lastPersistedAt = now;
      _locationWriteRetry?.cancel();
      _locationWriteRetry = null;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('updateDriverLocation failed: $error');
      }
      // Keep local GPS; retry once with the latest coordinates.
      _locationWriteRetry?.cancel();
      _locationWriteRetry = Timer(const Duration(seconds: 5), () {
        final latest = driverPosition.value;
        if (latest == null || _exiting || isClosed) return;
        unawaited(
          _maybePersistDriverLocation(
            latest,
            heading: _lastHeading,
            force: true,
          ),
        );
      });
    } finally {
      _locationWriteInFlight = false;
      final pending = _pendingLocationWrite;
      if (pending != null && !_exiting && !isClosed) {
        _pendingLocationWrite = null;
        final pendingHeading = _pendingLocationHeading;
        _pendingLocationHeading = null;
        unawaited(
          _maybePersistDriverLocation(
            pending,
            heading: pendingHeading,
            force: true,
          ),
        );
      }
    }
  }

  Future<void> _showLocationRequired(LocationReadiness readiness) async {
    if (_locationPermissionSnackShown) return;
    _locationPermissionSnackShown = true;

    final String message;
    final String buttonLabel;
    final Future<bool> Function() openSettings;

    switch (readiness) {
      case LocationReadiness.serviceDisabled:
        message = 'Turn on location services to track this ride.';
        buttonLabel = 'Enable';
        openSettings = _location.openLocationSettings;
      case LocationReadiness.permissionDeniedForever:
        message =
            'Location permission is permanently denied. Open settings to enable it for active rides.';
        buttonLabel = 'Settings';
        openSettings = _location.openAppSettings;
      case LocationReadiness.permissionDenied:
        message = 'Location permission is required to track this ride.';
        buttonLabel = 'Settings';
        openSettings = _location.openAppSettings;
      case LocationReadiness.ready:
        return;
    }

    AppSnackbar.error(
      title: 'Location required',
      message: message,
      duration: const Duration(seconds: 6),
      actionLabel: buttonLabel,
      onAction: () async {
        await openSettings();
      },
    );
  }

  void onCameraMoveStartedByUser() {
    if (_programmaticCameraMove) return;
    if (isFollowingDriver.value) {
      isFollowingDriver.value = false;
    }
  }

  Future<void> recenterOnDriver() async {
    isFollowingDriver.value = true;
    final driver = driverPosition.value;
    if (driver != null) {
      await _animateCameraToDriver(driver);
    }
  }

  Future<void> _animateCameraToDriver(LatLng target) async {
    if (_routeFetchInFlight || _programmaticCameraMove) return;
    final controller = _mapController;
    if (controller == null || _exiting) return;

    final now = DateTime.now();
    final lastPos = _lastCameraFollowPos;
    final lastAt = _lastCameraFollowAt;
    if (lastPos != null && lastAt != null) {
      final meters = Geolocator.distanceBetween(
        lastPos.latitude,
        lastPos.longitude,
        target.latitude,
        target.longitude,
      );
      final elapsed = now.difference(lastAt);
      if (meters < _cameraFollowMinMeters &&
          elapsed < _cameraFollowMinInterval) {
        return;
      }
    }

    _programmaticCameraMove = true;
    _lastCameraFollowPos = target;
    _lastCameraFollowAt = now;
    try {
      await controller.animateCamera(CameraUpdate.newLatLng(target));
    } catch (_) {
    } finally {
      // Allow gesture detection again after the programmatic animation settles.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        _programmaticCameraMove = false;
      });
    }
  }

  /// Evaluates GPS-driven lifecycle transitions from the single location stream.
  Future<void> _handleLocationUpdate(LatLng position) async {
    if (_exiting) return;

    final current = ride.value;
    if (current == null) return;

    final status = current.status;
    if (RideStatus.isTerminalStatus(status)) {
      return;
    }

    // Capture pre-arriving anchor once (driver_selected / legacy accepted).
    if (RideStatus.isPreArrivingAssignedStatus(status) &&
        _acceptedAnchor == null) {
      _acceptedAnchor = position;
      debugPrint(
        '[RideStatus] Current status: $status — '
        'anchor set at ${position.latitude}, ${position.longitude}',
      );
    }

    final pickup = current.pickupLatLng;
    final dropoff = current.dropoffLatLng;

    if (pickup == null &&
        (RideStatus.isPreArrivingAssignedStatus(status) ||
            status == RideStatus.driverArriving)) {
      debugPrint(
        '[RideStatus] Current status: $status — '
        'pickupLatLng is NULL; cannot auto-arrive',
      );
    }

    final toPickup = _statusEvaluator.distanceToPickup(position, pickup);
    if (toPickup != null &&
        (RideStatus.isPreArrivingAssignedStatus(status) ||
            status == RideStatus.driverArriving)) {
      final last = _lastLoggedPickupDistance;
      final shouldLog =
          last == null ||
          (toPickup - last).abs() >= 15 ||
          toPickup <= _statusEvaluator.config.pickupArrivalRadiusMeters;
      if (shouldLog) {
        _lastLoggedPickupDistance = toPickup;
        debugPrint(
          '[RideStatus] Current status: $status — '
          'distance to pickup: ${toPickup.toStringAsFixed(0)}m '
          '(radius ${_statusEvaluator.config.pickupArrivalRadiusMeters}m)',
        );
      }
    }

    nearDropoff.value = _statusEvaluator.isNearDropoff(
      status: status,
      current: position,
      dropoff: dropoff,
      hasRemainingStops: current.hasRemainingStops,
    );

    if (_statusEvaluator.shouldBecomeArriving(
      status: status,
      current: position,
      acceptedAnchor: _acceptedAnchor,
      pickup: pickup,
    )) {
      await _transitionToDriverArriving(current, position);
      return;
    }

    if (_statusEvaluator.shouldBecomeArrived(
      status: status,
      current: position,
      pickup: pickup,
    )) {
      await _transitionToDriverArrived(current, position);
      return;
    }

    if (_statusEvaluator.shouldArriveAtStop(
      status: status,
      current: position,
      stop: current.currentTripTargetLatLng,
      hasRemainingStops: current.hasRemainingStops,
    )) {
      await _advanceToNextStop(current);
      return;
    }

    if (_statusEvaluator.shouldComplete(
      status: status,
      current: position,
      dropoff: dropoff,
      hasRemainingStops: current.hasRemainingStops,
    )) {
      await _transitionToCompleted(current, position);
    }
  }

  Future<void> _transitionToDriverArriving(
    RideModel current,
    LatLng position,
  ) async {
    if (_exiting || _arrivingWriteInFlight) return;
    if (!RideStatus.isPreArrivingAssignedStatus(ride.value?.status ?? '')) {
      return;
    }

    final moved = _acceptedAnchor == null
        ? null
        : _statusEvaluator.distanceMeters(_acceptedAnchor!, position);
    final toPickup = _statusEvaluator.distanceToPickup(
      position,
      current.pickupLatLng,
    );

    _arrivingWriteInFlight = true;
    try {
      final fromStatus = ride.value?.status ?? current.status;
      debugPrint(
        '[RideStatus] Current status: $fromStatus\n'
        '[RideStatus] Driver distance moved: ${moved?.toStringAsFixed(0) ?? '?'}m'
        '${toPickup != null ? ', distance to pickup: ${toPickup.toStringAsFixed(0)}m' : ''}\n'
        '[RideStatus] Transition: $fromStatus → driver_arriving',
      );
      await _firestore.updateRideLifecycle(
        rideId: current.id,
        action: 'setArriving',
        driverId: Get.find<AuthController>().uid,
      );
      _acceptedAnchor = null;

      // Always re-check arrival with the latest GPS after setArriving — the
      // position that triggered movement may already be inside the pickup radius,
      // or watchRide may still lag behind the CF write.
      final latest = driverPosition.value ?? position;
      final latestToPickup = _statusEvaluator.distanceToPickup(
        latest,
        current.pickupLatLng,
      );
      if (latestToPickup != null &&
          latestToPickup <= _statusEvaluator.config.pickupArrivalRadiusMeters) {
        await _transitionToDriverArrived(current, latest, assumeArriving: true);
      }
    } catch (error) {
      debugPrint('[RideStatus] setArriving failed: $error');
      _showLifecycleErrorOnce(
        'Could not update ride to arriving. Check connection / Firebase deploy.',
        error,
      );
    } finally {
      _arrivingWriteInFlight = false;
    }
  }

  Future<void> _transitionToDriverArrived(
    RideModel current,
    LatLng position, {
    bool assumeArriving = false,
  }) async {
    if (_exiting || _pickupArrivalWritten || isUpdating.value) return;
    final status = ride.value?.status;
    if (!assumeArriving && status != RideStatus.driverArriving) return;
    if (assumeArriving &&
        status != RideStatus.driverArriving &&
        !RideStatus.isPreArrivingAssignedStatus(status ?? '')) {
      return;
    }

    final toPickup = _statusEvaluator.distanceToPickup(
      position,
      current.pickupLatLng,
    );

    _pickupArrivalWritten = true;
    try {
      debugPrint(
        '[RideStatus] Current status: driver_arriving\n'
        '[RideStatus] Distance to pickup: ${toPickup?.toStringAsFixed(0) ?? '?'}m\n'
        '[RideStatus] Transition: driver_arriving → driver_arrived',
      );
      await _firestore.updateRideLifecycle(
        rideId: current.id,
        action: 'arrivePickup',
        driverId: Get.find<AuthController>().uid,
      );
    } catch (error) {
      _pickupArrivalWritten = false;
      debugPrint('[RideStatus] arrivePickup failed: $error');
      _showLifecycleErrorOnce(
        'Could not mark arrived at pickup. Check connection / Firebase rules.',
        error,
      );
    }
  }

  void _showLifecycleErrorOnce(String message, Object error) {
    if (_lifecycleErrorSnackShown || _exiting) return;
    _lifecycleErrorSnackShown = true;
    debugPrint('[RideStatus] $message — $error');
    AppSnackbar.error(
      title: 'Ride status update failed',
      message: message,
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _transitionToCompleted(
    RideModel current,
    LatLng position,
  ) async {
    if (_exiting || _completionWriteInFlight || isUpdating.value) return;
    final latest = ride.value;
    if (latest == null || !latest.canComplete) return;

    final toDropoff = _statusEvaluator.distanceToDropoff(
      position,
      current.dropoffLatLng,
    );

    _completionWriteInFlight = true;
    isUpdating.value = true;
    try {
      debugPrint(
        '[RideStatus] Current status: ${latest.status}\n'
        '[RideStatus] Distance to dropoff: ${toDropoff?.toStringAsFixed(0) ?? '?'}m\n'
        '[RideStatus] Transition: ${latest.status} → completed',
      );
      await _firestore.updateRideLifecycle(
        rideId: current.id,
        action: 'complete',
        driverId: Get.find<AuthController>().uid,
      );
      await _exitAfterRideCompleted(completedRide: latest);
    } catch (error) {
      _completionWriteInFlight = false;
      debugPrint('[RideStatus] auto-complete failed: $error');
      _showLifecycleErrorOnce('Could not complete ride automatically.', error);
    } finally {
      isUpdating.value = false;
    }
  }

  /// Marks the current intermediate stop reached and retargets the next one.
  /// Never completes the ride — only the final destination does that.
  Future<void> _advanceToNextStop(RideModel current) async {
    if (_exiting || _stopAdvanceWriteInFlight) return;
    if (!current.isTripInProgress || !current.hasRemainingStops) return;
    if (RideStatus.isTerminalStatus(ride.value?.status ?? '')) return;

    final nextIndex = current.currentStopIndex + 1;
    _stopAdvanceWriteInFlight = true;
    try {
      debugPrint(
        '[RideStatus] Current status: ${current.status}\n'
        '[RideStatus] Stop ${current.currentStopDisplayNumber} reached\n'
        '[RideStatus] currentStopIndex ${current.currentStopIndex} → $nextIndex',
      );
      await _firestore.updateCurrentStopIndex(
        rideId: current.id,
        index: nextIndex,
      );
      if (_exiting) return;

      final latest = ride.value;
      if (latest != null &&
          latest.id == current.id &&
          latest.currentStopIndex < nextIndex) {
        ride.value = latest.withCurrentStopIndex(nextIndex);
      }

      _lastRouteKey = null;
      _rebuildMarkers(ride.value ?? current.withCurrentStopIndex(nextIndex));
      await _refreshRoute(force: true, fitCamera: true);
    } catch (error) {
      debugPrint('[RideStatus] advance stop failed: $error');
      _showLifecycleErrorOnce(
        'Could not update stop progress. Check connection / Firebase rules.',
        error,
      );
    } finally {
      _stopAdvanceWriteInFlight = false;
    }
  }

  void _scheduleRouteRefresh() {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(seconds: 2), () {
      _refreshRoute(fitCamera: false);
    });
  }

  Future<void> _refreshRoute({
    bool force = false,
    bool fitCamera = false,
  }) async {
    if (_exiting || isClosed) return;
    if (_routeFetchInFlight) {
      _pendingRouteRefresh = true;
      _pendingRouteForce = _pendingRouteForce || force;
      _pendingRouteFit = _pendingRouteFit || fitCamera;
      return;
    }

    final current = ride.value;
    if (current == null) return;

    // Arrived at pickup: keep the last route polyline until Start Ride so the
    // map does not blank out. Clear only the ETA chips. Still fetch once if
    // the line never landed (resume / Directions miss).
    if (current.isDriverArrived &&
        !current.isTripInProgress &&
        polylines.isNotEmpty &&
        !force) {
      routeEtaText.value = '';
      routeDistanceText.value = '';
      return;
    }

    final bool isTripRoute = current.isTripInProgress;

    // Pre-trip → pickup. In-trip → the current stop or dropoff only.
    // Drawing the whole remaining multi-stop path as one request made the
    // line jump/chord. Later stops stay as markers until that leg starts.
    final LatLng? destination = isTripRoute
        ? current.currentTripTargetLatLng
        : current.pickupLatLng;

    _routeFetchInFlight = true;
    final requestGen = ++_routeRequestGeneration;
    LatLng? origin;
    try {
      var driverOrigin = driverPosition.value;
      driverOrigin ??=
          await _location.getPositionQuick() ??
          await _location.getCurrentPosition();
      if (driverOrigin != null) {
        driverPosition.value = driverOrigin;
        _location.cachePosition(driverOrigin);
        _syncDriverMarker();
      }
      origin = driverOrigin;

      if (destination == null) {
        routeError.value =
            'Pickup/dropoff coordinates are missing for this ride.';
        return;
      }

      if (origin == null) {
        routeError.value =
            'Waiting for GPS to draw the driving route. Enable location and try again.';
        if (!_routeErrorSnackShown) {
          _routeErrorSnackShown = true;
          AppSnackbar.info(
            title: 'Route unavailable',
            message: routeError.value!,
          );
        }
        if (fitCamera) await _fitCamera();
        return;
      }

      final routeKey =
          '${current.status}|${current.currentStopIndex}|${origin.latitude.toStringAsFixed(5)},${origin.longitude.toStringAsFixed(5)}|${destination.latitude.toStringAsFixed(5)},${destination.longitude.toStringAsFixed(5)}';

      final now = DateTime.now();
      if (!force &&
          routeKey == _lastRouteKey &&
          _lastRouteFetchAt != null &&
          now.difference(_lastRouteFetchAt!) < _minRouteRefresh) {
        return;
      }

      if (current.isDriverArrived && !current.isTripInProgress) {
        routeEtaText.value = '';
        routeDistanceText.value = '';
      }

      final route = await _directions.getDrivingRoute(
        origin: origin,
        destination: destination,
      );

      if (_exiting ||
          isClosed ||
          requestGen != _routeRequestGeneration ||
          ride.value?.id != current.id) {
        return;
      }

      _setRoutePolyline(route.points);

      if (current.isTripInProgress || !current.isDriverArrived) {
        routeEtaText.value = route.durationText;
        routeDistanceText.value = route.distanceText;
      }
      routeError.value = null;
      _lastRouteKey = routeKey;
      _lastRouteFetchAt = now;
      _routeErrorSnackShown = false;

      if (fitCamera || !_cameraFittedForPhase) {
        await _fitCamera(routePoints: route.points);
        _cameraFittedForPhase = true;
      }
    } on DirectionsException catch (error) {
      if (requestGen != _routeRequestGeneration || isClosed) return;
      if (kDebugMode) {
        debugPrint('Directions failed: $error');
      }
      routeError.value = error.message;
      if (origin != null && destination != null) {
        _setRoutePolyline(
          straightRoutePoints(origin: origin, destination: destination),
        );
      }
      if (!_routeErrorSnackShown) {
        _routeErrorSnackShown = true;
        AppSnackbar.error(
          title: 'Route unavailable',
          message: error.message,
          duration: const Duration(seconds: 4),
        );
      }
      // Keep map usable: fit markers only, never leave a dead camera state.
      if (fitCamera) await _fitCamera();
    } catch (error) {
      if (requestGen != _routeRequestGeneration || isClosed) return;
      if (kDebugMode) {
        debugPrint('Directions unexpected error: $error');
      }
      routeError.value = 'Could not load the route. Try again.';
      if (origin != null && destination != null) {
        _setRoutePolyline(
          straightRoutePoints(origin: origin, destination: destination),
        );
      }
      if (fitCamera) await _fitCamera();
    } finally {
      if (requestGen == _routeRequestGeneration) {
        _routeFetchInFlight = false;
        if (_pendingRouteRefresh && !_exiting && !isClosed) {
          final replayForce = _pendingRouteForce;
          final replayFit = _pendingRouteFit;
          _pendingRouteRefresh = false;
          _pendingRouteForce = false;
          _pendingRouteFit = false;
          unawaited(_refreshRoute(force: replayForce, fitCamera: replayFit));
        }
      }
    }
  }

  void _setRoutePolyline(List<LatLng> points) {
    if (points.length < 2) {
      polylines.clear();
      polylines.refresh();
      return;
    }
    polylines.assignAll({
      buildMapRoutePolyline(
        id: PolylineId('active_route_$_routeRequestGeneration'),
        points: points,
      ),
    });
    polylines.refresh();
  }

  void _startEtaTicker(RideModel current) {
    _etaTimer?.cancel();

    if (current.isTripInProgress ||
        current.isWaitingAtPickup ||
        current.hasRiderArrived) {
      remainingEta.value = null;
      return;
    }

    if (!RideStatus.isPreArrivingAssignedStatus(current.status) &&
        current.status != RideStatus.driverArriving) {
      remainingEta.value = null;
      return;
    }

    void tick() {
      final latest = ride.value ?? current;
      final start = latest.acceptedAt ?? DateTime.now();
      final end = start.add(Duration(minutes: latest.etaMinutes));
      final left = end.difference(DateTime.now());
      remainingEta.value = left.isNegative ? Duration.zero : left;
    }

    tick();
    _etaTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _applyCachedIconsIfReady() {
    final cache = MarkerIconCache.instance;
    _driverIcon ??= cache.driverOrNull;
    _pickupIcon ??= cache.pickupOrNull;
    _dropoffIcon ??= cache.dropoffOrNull;
    _stopIcon ??= cache.stopOrNull;
  }

  Future<void> _ensureMarkerIcons() async {
    _applyCachedIconsIfReady();
    if (_driverIcon != null &&
        _pickupIcon != null &&
        _dropoffIcon != null &&
        _stopIcon != null) {
      return;
    }

    final cache = MarkerIconCache.instance;
    try {
      await cache.ensureLoaded();
    } catch (error, stack) {
      debugPrint('Marker cache ensure failed: $error\n$stack');
    }

    _driverIcon ??= cache.driverOrNull;
    _pickupIcon ??= cache.pickupOrNull;
    _dropoffIcon ??= cache.dropoffOrNull;
    _stopIcon ??= cache.stopOrNull;

    debugPrint(
      'Marker icons ready: '
      'driver=${_driverIcon != null}, '
      'pickup=${_pickupIcon != null}, '
      'dropoff=${_dropoffIcon != null}, '
      'stop=${_stopIcon != null}',
    );

    final current = ride.value;
    if (current != null) {
      _rebuildMarkers(current);
    } else if (driverPosition.value != null) {
      _syncDriverMarker();
    }
  }

  void _rebuildMarkers(RideModel current) {
    final next = <Marker>{};

    final pickup = current.pickupLatLng;
    // Pickup pin is only useful while heading to / waiting at pickup.
    // After Start Ride (`ride_started`) drop it so the map shows dropoff + car.
    if (pickup != null && !current.isTripInProgress) {
      next.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: 'Pickup',
            snippet: current.pickupLocation,
          ),
          icon:
              _pickupIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    final dropoff = current.dropoffLatLng;
    if (dropoff != null) {
      next.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: 'Dropoff',
            snippet: current.dropoffLocation,
          ),
          icon:
              _dropoffIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    final showAllStops = !current.isTripInProgress;
    for (var i = 0; i < current.stops.length; i++) {
      if (!showAllStops && i < current.currentStopIndex) continue;
      final stop = current.stops[i];
      final position = stop.latLng;
      if (position == null) continue;
      next.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: position,
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: 'Stop ${i + 1}',
            snippet: stop.location,
          ),
          icon:
              _stopIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    final driver = driverPosition.value;
    if (driver != null) {
      next.add(_driverMarker(driver));
      _lastDriverMarkerPos = driver;
    }

    markers.assignAll(next);
  }

  void _syncDriverMarker() {
    if (isWaitingAtPickup) return;
    final driver = driverPosition.value;
    if (driver == null) return;

    final last = _lastDriverMarkerPos;
    if (last != null &&
        last.latitude == driver.latitude &&
        last.longitude == driver.longitude) {
      return;
    }
    _lastDriverMarkerPos = driver;

    final next = markers
        .where((marker) => marker.markerId != _driverMarkerId)
        .toSet();
    next.add(_driverMarker(driver));
    markers.assignAll(next);
  }

  Marker _driverMarker(LatLng position) {
    final heading = _lastHeading;
    final rotation = heading != null && heading >= 0 && !heading.isNaN
        ? heading
        : 0.0;
    return Marker(
      markerId: _driverMarkerId,
      position: position,
      anchor: const Offset(0.5, 0.5),
      zIndexInt: 2,
      flat: true,
      rotation: rotation,
      infoWindow: const InfoWindow(title: 'You'),
      icon:
          _driverIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
    );
  }

  Future<void> onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    await _fitCamera();
    _cameraFittedForPhase = true;
  }

  Future<void> _fitCamera({List<LatLng>? routePoints}) async {
    final controller = _mapController;
    if (controller == null) return;

    final current = ride.value;
    if (current == null) return;

    final points = <LatLng>[
      ...?routePoints,
      ?driverPosition.value,
      if (!current.isTripInProgress) ?current.pickupLatLng,
      if (current.isTripInProgress || routePoints == null)
        ?current.dropoffLatLng,
      if (current.isTripInProgress)
        ...current.remainingStopWaypoints()
      else
        ...current.allStopWaypoints(),
    ];

    if (points.isEmpty) return;

    _programmaticCameraMove = true;
    try {
      if (points.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 14),
        );
        return;
      }

      var minLat = points.first.latitude;
      var maxLat = points.first.latitude;
      var minLng = points.first.longitude;
      var maxLng = points.first.longitude;

      for (final point in points.skip(1)) {
        minLat = point.latitude < minLat ? point.latitude : minLat;
        maxLat = point.latitude > maxLat ? point.latitude : maxLat;
        minLng = point.longitude < minLng ? point.longitude : minLng;
        maxLng = point.longitude > maxLng ? point.longitude : maxLng;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 80),
        );
      } catch (_) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 14),
        );
      }
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        _programmaticCameraMove = false;
      });
    }
  }

  Future<void> onPrimaryCta() async {
    final current = ride.value;
    if (current == null || isUpdating.value) return;

    if (current.canStart) {
      await startRide();
      return;
    }

    if (current.canComplete) {
      if (!nearDropoff.value) {
        AppSnackbar.info(
          title: 'Not at dropoff yet',
          message: 'Move closer to the destination to complete the ride.',
        );
        return;
      }
      await completeRide();
      return;
    }

    AppSnackbar.info(
      title: 'Unavailable',
      message: current.isDriverArrived
          ? 'Wait for the passenger to confirm they are coming.'
          : current.isDriverArriving
          ? 'Arrive at pickup before starting the ride.'
          : 'This ride cannot be updated right now.',
    );
  }

  Future<void> startRide() async {
    final current = ride.value;
    if (current == null || isUpdating.value || _exiting || isClosed) return;

    // Lock immediately so double-taps cannot race past validation.
    isUpdating.value = true;
    try {
      if (!current.canStart) {
        AppSnackbar.error(
          title: 'Cannot start',
          message: current.isDriverArrived
              ? 'Wait for the passenger to confirm they are coming.'
              : 'You must arrive at pickup before starting the ride.',
        );
        return;
      }

      final position = driverPosition.value;
      if (position == null) {
        AppSnackbar.info(
          title: 'Location needed',
          message: 'Waiting for GPS before starting the ride.',
        );
        return;
      }
      final toPickup = _statusEvaluator.distanceToPickup(
        position,
        current.pickupLatLng,
      );
      if (toPickup == null ||
          toPickup > _statusEvaluator.config.pickupArrivalRadiusMeters) {
        AppSnackbar.info(
          title: 'Not at pickup',
          message: 'Move closer to the pickup location to start the ride.',
        );
        return;
      }

      if (kDebugMode) {
        debugPrint(
          '[RideStatus] Current status: passenger_arriving\n'
          '[RideStatus] Action: Start Ride pressed\n'
          '[RideStatus] Distance to pickup: ${toPickup.toStringAsFixed(0)}m\n'
          '[RideStatus] Transition: passenger_arriving → ride_started',
        );
      }
      await _firestore.updateRideLifecycle(
        rideId: current.id,
        action: 'start',
        driverId: Get.find<AuthController>().uid,
      );

      if (isClosed || _exiting) return;

      AppSnackbar.success(title: 'Ride started');
      // Route + camera refresh happens once via watchRide phase change.
    } on FirebaseFunctionsException catch (error) {
      if (isClosed) return;
      AppSnackbar.error(
        title: 'Update failed',
        message: _lifecycleErrorMessage(error),
      );
    } catch (error) {
      if (isClosed) return;
      AppSnackbar.error(
        title: 'Update failed',
        message: _userFacingError(error),
      );
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> completeRide() async {
    final current = ride.value;
    if (current == null || isUpdating.value || _exiting || isClosed) return;
    if (_completionWriteInFlight) return;

    isUpdating.value = true;
    try {
      if (!current.canComplete) {
        AppSnackbar.error(
          title: 'Cannot complete',
          message: current.hasRemainingStops
              ? 'Finish remaining stops before completing the ride.'
              : 'Start the ride before completing it.',
        );
        return;
      }

      if (kDebugMode) {
        debugPrint(
          '[RideStatus] Current status: ${current.status}\n'
          '[RideStatus] Action: Complete Ride pressed\n'
          '[RideStatus] Transition: ${current.status} → completed',
        );
      }
      await _firestore.updateRideLifecycle(
        rideId: current.id,
        action: 'complete',
        driverId: Get.find<AuthController>().uid,
      );

      if (isClosed || _exiting) return;
      await _exitAfterRideCompleted(completedRide: current);
    } on FirebaseFunctionsException catch (error) {
      if (isClosed) return;
      AppSnackbar.error(
        title: 'Update failed',
        message: _lifecycleErrorMessage(error),
      );
    } catch (error) {
      if (isClosed) return;
      AppSnackbar.error(
        title: 'Update failed',
        message: _userFacingError(error),
      );
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> onCancelRide() async {
    final current = ride.value;
    if (current == null || isUpdating.value || _exiting || isClosed) return;

    if (_isTerminalRideStatus(current.status)) {
      AppSnackbar.error(
        title: 'Could not cancel',
        message: 'This ride cannot be cancelled.',
      );
      return;
    }

    final confirmed = await showAppBlurGetDialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.inputBackground,
        title: const Text(
          'Cancel ride?',
          style: TextStyle(color: AppColors.white),
        ),
        content: const Text(
          'The passenger will be notified and this trip will end.',
          style: TextStyle(color: AppColors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Keep ride'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'Cancel ride',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || isClosed) return;

    isUpdating.value = true;
    _driverInitiatedCancel = true;
    try {
      await _firestore.updateRideLifecycle(
        rideId: current.id,
        action: 'cancel',
        driverId: Get.find<AuthController>().uid,
      );
      if (isClosed || _exiting) return;
      await _clearAndExit(message: 'Ride cancelled.');
    } on FirebaseFunctionsException catch (error) {
      _driverInitiatedCancel = false;
      if (isClosed) return;
      AppSnackbar.error(
        title: 'Could not cancel',
        message: _lifecycleErrorMessage(error, forCancel: true),
      );
    } catch (error) {
      _driverInitiatedCancel = false;
      if (isClosed) return;
      AppSnackbar.error(
        title: 'Could not cancel',
        message: _userFacingError(error),
      );
    } finally {
      isUpdating.value = false;
    }
  }

  String _userFacingError(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Something went wrong. Please try again.';
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    if (raw.startsWith('StateError: ')) {
      return raw.substring('StateError: '.length);
    }
    // Never surface stack-like / verbose Firebase dumps.
    if (raw.length > 140 || raw.contains('\n')) {
      return 'Something went wrong. Please try again.';
    }
    return raw;
  }

  /// Maps Cloud Function errors to short, actionable copy.
  String _lifecycleErrorMessage(
    FirebaseFunctionsException error, {
    bool forCancel = false,
  }) {
    switch (error.code) {
      case 'not-found':
        return forCancel
            ? 'Cancel is temporarily unavailable. Please try again.'
            : 'Ride update is temporarily unavailable. Please try again.';
      case 'failed-precondition':
        return error.message ??
            (forCancel
                ? 'This ride cannot be cancelled.'
                : 'This ride cannot be updated.');
      case 'permission-denied':
        return error.message ?? 'You are not allowed to update this ride.';
      case 'unauthenticated':
        return 'Please sign in again and retry.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Network issue. Check your connection and try again.';
      default:
        final message = error.message?.trim();
        if (message == null || message.isEmpty) {
          return forCancel
              ? 'Could not cancel this ride. Please try again.'
              : 'Could not update this ride. Please try again.';
        }
        if (message.toLowerCase().contains('deploy')) {
          return 'Service temporarily unavailable. Try again shortly.';
        }
        return message;
    }
  }

  void onContactUnavailable() {
    AppSnackbar.info(
      title: 'Contact unavailable',
      message: 'Passenger phone number is not available for this ride.',
    );
  }

  /// Opens in-ride chat for the current assigned active ride only.
  void openChat() {
    final current = ride.value;
    final rideId = current?.id.trim() ?? '';
    final uid = Get.find<AuthController>().uid?.trim() ?? '';
    final assignedDriverId = current?.driverId?.trim() ?? '';

    if (current == null || rideId.isEmpty) {
      AppSnackbar.info(
        title: ChatConstants.title,
        message: ChatConstants.rideNotFound,
      );
      return;
    }

    if (!RideStatus.isActiveAssignedStatus(current.status) ||
        assignedDriverId.isEmpty ||
        uid.isEmpty ||
        assignedDriverId != uid) {
      AppSnackbar.info(
        title: ChatConstants.title,
        message: ChatConstants.chatUnavailable,
      );
      return;
    }

    // Get.toNamed(AppRoutes.chat, arguments: rideId);
    AppNavigator.toChat(rideId);
  }

  void _startChatUnreadWatch(String rideId) {
    _stopChatUnreadWatch();
    final id = rideId.trim();
    if (id.isEmpty) return;

    _chatUnreadSubscription = _chatService
        .watchUnreadFromRiderCount(id)
        .listen(
          (count) {
            chatUnreadCount.value = count < 0 ? 0 : count;
          },
          onError: (_) {
            chatUnreadCount.value = 0;
          },
        );
  }

  void _stopChatUnreadWatch() {
    _chatUnreadSubscription?.cancel();
    _chatUnreadSubscription = null;
    chatUnreadCount.value = 0;
  }

  Future<void> openExternalNavigation() async {
    final current = ride.value;
    final target = current?.isTripInProgress == true
        ? current?.currentTripTargetLatLng
        : current?.pickupLatLng;

    if (target == null) {
      AppSnackbar.info(
        title: 'Navigation',
        message: 'Location is not available for this ride.',
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}&travelmode=driving',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      AppSnackbar.error(title: 'Navigation', message: 'Could not open maps.');
    }
  }

  /// Message shown when Firestore reports the ride ended remotely.
  String _remoteCancelMessage(RideModel updated) {
    final status = updated.status.toLowerCase().trim();
    if (status == RideStatus.expired) {
      return 'Ride cancelled.';
    }

    final cancelledByDriver =
        _driverInitiatedCancel ||
        (updated.cancelledBy?.toLowerCase() == 'driver');
    if (cancelledByDriver) {
      return 'Ride cancelled.';
    }

    // Passenger cancel (cancelledBy rider/user, or missing but not driver).
    if (updated.isFromReservation) {
      return 'Your reservation has been cancelled by user';
    }
    return 'Ride cancelled by user';
  }

  /// Reservation trips return to the dashboard with a snackbar.
  /// Instant rides still open the completed-ride receipt.
  Future<void> _exitAfterRideCompleted({
    RideModel? completedRide,
    bool fromReservation = false,
  }) {
    final ride = completedRide ?? this.ride.value;
    if (fromReservation || ride?.isFromReservation == true) {
      return _clearAndExit(message: 'Reservation completed', success: true);
    }
    return _clearAndExit(completedRide: ride);
  }

  Future<void> _clearAndExit({
    String? message,
    RideModel? completedRide,
    bool success = false,
  }) async {
    if (_exiting) return;
    _exiting = true;

    _etaTimer?.cancel();
    _routeDebounce?.cancel();
    _locationWriteRetry?.cancel();
    _proximityPollTimer?.cancel();

    // Never await cancel while still inside the watchRide listen callback —
    // that deadlocks and leaves the driver stuck on the map.
    final rideSub = _rideSubscription;
    _rideSubscription = null;
    unawaited(rideSub?.cancel() ?? Future<void>.value());

    final reservationSub = _reservationSubscription;
    _reservationSubscription = null;
    unawaited(reservationSub?.cancel() ?? Future<void>.value());

    _stopChatUnreadWatch();

    unawaited(_stopLocationTracking());

    // Leave Active Ride immediately. Never await Firestore here — a hung
    // clearCurrentRideId used to set _exiting=true and leave the driver
    // stuck on the map forever (later cancel snapshots were ignored).
    if (completedRide != null) {
      // Get.offAllNamed(
      //   AppRoutes.completedRideDetail,
      //   arguments: {
      //     'ride': completedRide,
      //     'returnToDashboard': true,
      //   },
      // );
      AppNavigator.toCompletedRideDetail(
        ride: completedRide,
        returnToDashboard: true,
      );
    } else {
      // Prefer popping back to the shell when Active Ride was pushed with
      // toNamed; fall back to offAll when opened as a root (cold start).
      if (Get.key.currentState?.canPop() == true) {
        Get.back();
      } else {
        Get.offAllNamed(
          AppRoutes.dashboard,
          arguments: {'navIndex': DashboardController.homeNavIndex},
        );
      }

      if (message != null && message.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (success) {
            AppSnackbar.success(
              title: message,
              duration: const Duration(seconds: 2),
            );
          } else {
            AppSnackbar.info(
              title: message,
              duration: const Duration(seconds: 2),
            );
          }
        });
      }
    }

    final uid = Get.find<AuthController>().uid;
    if (uid != null) {
      unawaited(() async {
        try {
          await _firestore.clearCurrentRideId(uid);
        } catch (error) {
          if (kDebugMode) {
            debugPrint('clearCurrentRideId failed: $error');
          }
        }
      }());
    }
  }
}
