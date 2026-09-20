import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/driver_model.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';
import '../routes/app_routes.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/map_warmup_service.dart';
import '../services/notification_service.dart';
import '../utilis/firestore_paths.dart';
import '../widgets/app_snackbar_widget.dart';
import 'auth_controller.dart';
import 'ride_history_feed_controller.dart';

/// Exclusive driver presence: ride XOR reservation (never both).
enum DriverOnlineMode { offline, ride, reservation }

class DashboardController extends GetxController {
  DashboardController({
    FirestoreService? firestore,
    NotificationService? notifications,
    LocationService? location,
    MapWarmupService? mapWarmup,
  }) : _firestore = firestore ?? FirestoreService(),
       _notifications = notifications ?? NotificationService(),
       _location = location ??
           (Get.isRegistered<LocationService>()
               ? Get.find<LocationService>()
               : LocationService()),
       _mapWarmup = mapWarmup ??
           (Get.isRegistered<MapWarmupService>()
               ? Get.find<MapWarmupService>()
               : MapWarmupService());

  final FirestoreService _firestore;
  final NotificationService _notifications;
  final LocationService _location;
  final MapWarmupService _mapWarmup;

  final rideRequests = <RideRequestModel>[].obs;
  final rides = <RideModel>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString(null);

  /// Single source of truth for UI online state (mutually exclusive modes).
  final onlineMode = DriverOnlineMode.offline.obs;

  final isTogglingOnline = false.obs;

  bool get isRideOnline => onlineMode.value == DriverOnlineMode.ride;

  bool get isReservationOnline =>
      onlineMode.value == DriverOnlineMode.reservation;

  /// True while a ride accept/claim is in flight.
  final isAccepting = false.obs;

  /// Ride id currently being accepted (for per-card loading UI).
  final acceptingRideId = RxnString(null);

  /// Display name shown in the dashboard greeting.
  final greetingName = 'Driver'.obs;

  /// Full name / email shown on Settings (kept in sync via Firestore).
  final profileName = 'Driver'.obs;
  final profileEmail = ''.obs;

  /// Completed rides only (matches "Rides taken" label).
  final ridesTaken = 0.obs;

  /// Average of passenger ratings on completed rides (`0` when none).
  final averageRating = 0.0.obs;

  /// Number of completed rides that have a passenger rating.
  final reviewCount = 0.obs;

  /// Active ride id from driver doc (null when free).
  final currentRideId = RxnString(null);

  static const int homeNavIndex = 0;
  /// Confirm Reservations tab in [MainShellView] IndexedStack.
  static const int reservationNavIndex = 1;

  /// Bottom-nav selection (home = 0).
  final selectedNavIndex = 0.obs;

  /// Guards opening Pending / Active Ride from duplicate taps.
  final _isNavigating = false.obs;

  /// Dedicated lock so Pending-open does not block post-accept navigation.
  bool _isOpeningActiveRide = false;

  /// Local-only dismissals so the pending stream does not re-add swiped cards.
  final Set<String> _dismissedRideIds = <String>{};

  /// After a failed go-online (or restore), retry when the app resumes.
  bool _pendingGoOnline = false;

  /// Which mode to retry after a failed go-online (ride or reservation).
  DriverOnlineMode? _pendingOnlineMode;

  /// User explicitly went offline; do not auto-online until they tap Online.
  bool _userChoseOffline = false;

  /// Survives shell dispose within this process (accept → Active Ride → back).
  static DriverOnlineMode? _lastPreferredMode;

  bool get isNavigating => _isNavigating.value;

  StreamSubscription<List<RideRequestModel>>? _requestsSubscription;
  StreamSubscription<List<RideModel>>? _ridesSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<DriverModel?>? _driverSubscription;
  Worker? _historyFeedWorker;

  @override
  void onInit() {
    super.onInit();
    _applyLaunchArguments();
    _ensureApprovedThenStart();
  }

  void _applyLaunchArguments() {
    final args = Get.arguments;
    if (args is! Map) return;
    final navIndex = args['navIndex'];
    if (navIndex is int) selectedNavIndex.value = navIndex;
  }

  Future<void> _ensureApprovedThenStart() async {
    final auth = Get.find<AuthController>();
    final uid = auth.uid;

    if (uid == null) {
      Get.offAllNamed(AppRoutes.signIn);
      return;
    }

    try {
      final driver = await _firestore.fetchDriver(uid);

      if (isClosed) return;

      if (driver == null || !driver.isApproved) {
        auth.rememberApproval(false);
        Get.offAllNamed(AppRoutes.waitingApproval);
        return;
      }

      auth.rememberApproval(true);

      _applyDriverProfile(driver);
      currentRideId.value = driver.currentRideId;
      await _syncOnlineFromDriver(driver);
      if (isClosed) return;

      _watchDriverProfile(uid);

      // History/notifications always; pending ride streams only while ride-online.
      _bindRideHistoryFeed();
      _setUpNotifications();
      if (onlineMode.value == DriverOnlineMode.ride) {
        _startPendingRideListeners();
      }

      // Warm map icons + last-known GPS without blocking the shell UI.
      _mapWarmup.warmInBackground(requestPermission: false);
    } catch (error) {
      // Transient network/Firebase failures must not flip approval state.
      if (isClosed) return;
      debugPrint('Dashboard bootstrap failed: $error');
      AppSnackbar.error(
        title: 'Connection problem',
        message: 'Could not load your profile. Pull to refresh or try again.',
      );
    }
  }

  void _applyDriverProfile(DriverModel driver) {
    final fullName = driver.fullName.trim();
    final firstName = driver.firstName.trim();
    final email = driver.email.trim();

    greetingName.value = firstName.isNotEmpty
        ? firstName
        : (fullName.isEmpty ? 'Driver' : fullName);
    profileName.value = fullName.isEmpty ? 'Driver' : fullName;
    if (email.isNotEmpty) {
      profileEmail.value = email;
    } else {
      final authEmail =
          Get.find<AuthController>().currentUser?.email?.trim() ?? '';
      if (authEmail.isNotEmpty) profileEmail.value = authEmail;
    }
  }

  /// Restore online preference after shell recreate; never force online if the
  /// user previously chose offline in this process.
  Future<void> _syncOnlineFromDriver(DriverModel driver) async {
    if (_userChoseOffline ||
        _lastPreferredMode == DriverOnlineMode.offline) {
      onlineMode.value = DriverOnlineMode.offline;
      _pendingGoOnline = false;
      _pendingOnlineMode = null;
      if (driver.isOnline) {
        await _markOnline(false);
      }
      return;
    }

    final readiness = await _location.ensureReadyForOnline(
      requestIfDenied: false,
    );
    final preferOnline = driver.isOnline ||
        _lastPreferredMode == DriverOnlineMode.ride ||
        _lastPreferredMode == DriverOnlineMode.reservation;

    if (readiness == LocationReadiness.ready && preferOnline) {
      final mode = _lastPreferredMode == DriverOnlineMode.reservation
          ? DriverOnlineMode.reservation
          : DriverOnlineMode.ride;
      onlineMode.value = mode;
      _pendingGoOnline = false;
      _pendingOnlineMode = null;
      _userChoseOffline = false;
      if (mode == DriverOnlineMode.ride && !driver.isOnline) {
        await _markOnline(true);
      }
      if (mode == DriverOnlineMode.ride) {
        _startPendingRideListeners();
      }
      return;
    }

    // Location not ready or no online preference — stay offline.
    onlineMode.value = DriverOnlineMode.offline;
    if (preferOnline) {
      _pendingGoOnline = true;
      _pendingOnlineMode = _lastPreferredMode == DriverOnlineMode.reservation
          ? DriverOnlineMode.reservation
          : DriverOnlineMode.ride;
    }
    if (driver.isOnline) {
      await _markOnline(false);
    }
  }

  void _watchDriverProfile(String uid) {
    _driverSubscription?.cancel();
    _driverSubscription = _firestore.watchDriver(uid).listen((driver) {
      if (isClosed) return;

      // Soft-deleted / missing driver doc — end the session.
      if (driver == null) {
        unawaited(_forceSignOutMissingDriver());
        return;
      }

      // Admin revoked approval while session is live.
      if (!driver.isApproved) {
        unawaited(_handleApprovalRevoked());
        return;
      }

      _applyDriverProfile(driver);
      currentRideId.value = driver.currentRideId;
      // Keep local toggle authoritative during an in-progress tap.
      if (isTogglingOnline.value) return;
      // Firestore isOnline only mirrors ride mode; ignore when reservation-online.
      if (!driver.isOnline && onlineMode.value == DriverOnlineMode.ride) {
        onlineMode.value = DriverOnlineMode.offline;
      }
    });
  }

  Future<void> _forceSignOutMissingDriver() async {
    if (isClosed) return;
    try {
      await Get.find<AuthController>().signOut();
    } catch (error) {
      debugPrint('signOut after missing driver failed: $error');
      Get.offAllNamed(AppRoutes.signIn);
    }
  }

  Future<void> _handleApprovalRevoked() async {
    if (isClosed) return;
    final auth = Get.find<AuthController>();
    auth.rememberApproval(false);
    onlineMode.value = DriverOnlineMode.offline;
    _userChoseOffline = true;
    try {
      final uid = auth.uid;
      if (uid != null) {
        await _firestore.setOnlineStatus(uid, false);
      }
    } catch (error) {
      debugPrint('go offline after approval revoked failed: $error');
    }
    if (isClosed) return;
    Get.offAllNamed(AppRoutes.waitingApproval);
  }

  /// Call after local profile edits so UI updates before the stream catches up.
  void refreshProfileDisplay({
    required String fullName,
    required String email,
  }) {
    final trimmed = fullName.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    final firstName = parts.isEmpty ? '' : parts.first;

    greetingName.value = firstName.isNotEmpty
        ? firstName
        : (trimmed.isEmpty ? 'Driver' : trimmed);
    profileName.value = trimmed.isEmpty ? 'Driver' : trimmed;
    if (email.trim().isNotEmpty) profileEmail.value = email.trim();
  }

  void selectNav(int index) {
    selectedNavIndex.value = index;
  }

  /// Placeholder until book-ride flow is wired.
  void bookRide() {
    AppSnackbar.success(
      title: 'Book a ride',
      message: 'Coming soon.',
    );
  }

  @override
  void onClose() {
    _requestsSubscription?.cancel();
    _ridesSubscription?.cancel();
    _tokenSubscription?.cancel();
    _driverSubscription?.cancel();
    _historyFeedWorker?.dispose();
    unawaited(_notifications.cancelListen());
    super.onClose();
  }

  // ==========================================
  // PUSH NOTIFICATIONS
  // ==========================================

  Future<void> _setUpNotifications() async {
    final granted = await _notifications.requestPermission();

    if (!granted) return;

    final uid = Get.find<AuthController>().uid;

    if (uid != null) {
      final token = await _notifications.deviceToken();

      if (token != null) {
        await _firestore.saveFcmToken(uid, token);
      }

      // Tokens rotate, so keep the driver document current.
      _tokenSubscription = _notifications.tokenRefreshes.listen((token) {
        _firestore.saveFcmToken(uid, token);
      });
    }

    _notifications.onForegroundMessage = (message) {
      if (Get.isRegistered<AuthController>() &&
          Get.find<AuthController>().notificationsPaused.value) {
        return;
      }
      AppSnackbar.success(
        title: message.notification?.title ?? 'New ride request',
        message: message.notification?.body ?? 'A rider is waiting nearby.',
        position: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );
    };

    _notifications.onMessageOpened = (message) {
      final rideId = message.data[_rideIdKey] as String?;

      if (rideId != null) {
        openRideById(rideId);
      }
    };

    await _notifications.listen();
  }

  /// Key the user app (or a Cloud Function) puts in the notification payload.
  static const String _rideIdKey = 'rideId';

  void _startPendingRideListeners() {
    _listenForRideRequests();
    _listenForPendingRides();
  }

  void _stopPendingRideListeners() {
    _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _ridesSubscription?.cancel();
    _ridesSubscription = null;
  }

  // ==========================================
  // RIDE REQUEST FEED
  // ==========================================

  void _listenForRideRequests() {
    _requestsSubscription?.cancel();

    _requestsSubscription = _firestore.pendingRideRequests().listen(
      (requests) {
        rideRequests.assignAll(requests);
      },
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('pendingRideRequests error: $error');
        }
      },
    );
  }

  void _listenForPendingRides() {
    _ridesSubscription?.cancel();

    _ridesSubscription = _firestore.pendingRides().listen(
      (pending) {
        rides.assignAll(
          pending.where((ride) => !_dismissedRideIds.contains(ride.id)),
        );
        errorMessage.value = null;
        isLoading.value = false;
      },
      onError: (Object error) {
        errorMessage.value = 'Could not load pending rides. Pull to retry.';
        isLoading.value = false;
      },
    );
  }

  void _bindRideHistoryFeed() {
    if (!Get.isRegistered<RideHistoryFeedController>()) {
      Get.put(RideHistoryFeedController(), permanent: false);
    }
    final feed = Get.find<RideHistoryFeedController>();
    feed.ensureListening();
    _applyHistoryStats(feed);
    _historyFeedWorker?.dispose();
    _historyFeedWorker = ever(feed.history, (_) => _applyHistoryStats(feed));
  }

  void _applyHistoryStats(RideHistoryFeedController feed) {
    final completed = feed.completedRides;
    ridesTaken.value = completed.length;

    final rated = feed.ratedCompletedRides;
    reviewCount.value = rated.length;
    if (rated.isEmpty) {
      averageRating.value = 0;
    } else {
      final total = rated.fold<int>(
        0,
        (sum, ride) => sum + (ride.riderRating ?? 0),
      );
      averageRating.value = total / rated.length;
    }
  }

  void retry() {
    isLoading.value = true;
    errorMessage.value = null;
    if (onlineMode.value == DriverOnlineMode.ride) {
      _startPendingRideListeners();
    }
    if (Get.isRegistered<RideHistoryFeedController>()) {
      Get.find<RideHistoryFeedController>().retry();
    } else {
      _bindRideHistoryFeed();
    }
  }

  Future<void> toggleRideOnline() async {
    await _toggleOnlineMode(DriverOnlineMode.ride);
  }

  Future<void> toggleReservationOnline() async {
    await _toggleOnlineMode(DriverOnlineMode.reservation);
  }

  Future<void> _toggleOnlineMode(DriverOnlineMode mode) async {
    assert(mode != DriverOnlineMode.offline);
    if (isTogglingOnline.value) return;

    isTogglingOnline.value = true;
    try {
      if (onlineMode.value == mode) {
        onlineMode.value = DriverOnlineMode.offline;
        _pendingGoOnline = false;
        _pendingOnlineMode = null;
        _userChoseOffline = true;
        _lastPreferredMode = DriverOnlineMode.offline;
        await _markOnline(false);
        _stopPendingRideListeners();
        return;
      }

      _userChoseOffline = false;
      await _attemptGoOnline(mode: mode, promptIfNeeded: true);
    } finally {
      isTogglingOnline.value = false;
    }
  }

  /// Called when the app returns to foreground (e.g. after Settings).
  ///
  /// [forMode] limits the retry to the screen that resumed (ride vs reservation).
  Future<void> onAppResumed({DriverOnlineMode? forMode}) async {
    if (_userChoseOffline || isTogglingOnline.value) return;
    if (!_pendingGoOnline) return;

    final pending = _pendingOnlineMode ?? DriverOnlineMode.ride;
    if (forMode != null && forMode != pending) return;
    if (onlineMode.value == pending) return;

    isTogglingOnline.value = true;
    try {
      await _attemptGoOnline(mode: pending, promptIfNeeded: false);
    } finally {
      isTogglingOnline.value = false;
    }
  }

  Future<void> _attemptGoOnline({
    required DriverOnlineMode mode,
    required bool promptIfNeeded,
  }) async {
    assert(mode != DriverOnlineMode.offline);

    final readiness = await _location.ensureReadyForOnline(
      requestIfDenied: promptIfNeeded,
    );
    if (readiness == LocationReadiness.ready) {
      // Switching modes automatically forces the other section offline.
      onlineMode.value = mode;
      _pendingGoOnline = false;
      _pendingOnlineMode = null;
      _userChoseOffline = false;
      _lastPreferredMode = mode;
      // Firestore presence is ride-only (FCM eligibility).
      await _markOnline(mode == DriverOnlineMode.ride);
      // Permission is granted here — warm icons + GPS for later map screens.
      _mapWarmup.warmInBackground(requestPermission: false);
      if (mode == DriverOnlineMode.ride) {
        _startPendingRideListeners();
      } else {
        _stopPendingRideListeners();
      }
      return;
    }

    _pendingGoOnline = true;
    _pendingOnlineMode = mode;
    if (promptIfNeeded) {
      await _promptLocationRequired(readiness);
    }
  }

  Future<void> _promptLocationRequired(LocationReadiness readiness) async {
    final String message;
    final String buttonLabel;
    final VoidCallback onPressed;

    switch (readiness) {
      case LocationReadiness.serviceDisabled:
        message =
            'Turn on location services to go online and receive ride requests.';
        buttonLabel = 'Enable';
        onPressed = () {
          _location.openLocationSettings();
        };
      case LocationReadiness.permissionDeniedForever:
        message =
            'Enable location permission in settings to go online.';
        buttonLabel = 'Settings';
        onPressed = () {
          _location.openAppSettings();
        };
      case LocationReadiness.permissionDenied:
        message =
            'Location permission is required to go online and receive ride requests.';
        buttonLabel = 'Settings';
        onPressed = () {
          _location.openAppSettings();
        };
      case LocationReadiness.ready:
        return;
    }

    AppSnackbar.error(
      title: 'Location required',
      message: message,
      actionLabel: buttonLabel,
      onAction: onPressed,
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _markOnline(bool online) async {
    final uid = Get.find<AuthController>().uid;

    if (uid == null) return;

    try {
      await _firestore.setOnlineStatus(uid, online);
    } catch (_) {
      // Presence is best effort; it should not block the dashboard.
    }
  }

  // ==========================================
  // NAVIGATION
  // ==========================================

  /// Opens the pending-rides screen. Guards against the Dismissible firing twice.
  Future<void> openRideDetails(RideRequestModel ride) async {
    if (_isNavigating.value) return;

    _isNavigating.value = true;
    try {
      await Get.toNamed(AppRoutes.ridePending, arguments: ride);
    } finally {
      _isNavigating.value = false;
    }
  }

  /// Called when a ride-request push notification is tapped. Prefers the
  /// authoritative `rides` collection, then falls back to legacy requests.
  Future<void> openRideById(String rideId) async {
    // Prefer a fresh read so FCM taps do not open a stale pending card.
    final ride =
        await _firestore.fetchRide(rideId) ??
        rides.firstWhereOrNull((item) => item.id == rideId);

    if (ride != null) {
      await _openRideFromNotification(ride);
      return;
    }

    final request =
        rideRequests.firstWhereOrNull((item) => item.id == rideId) ??
        await _firestore.fetchRideRequest(rideId);

    if (request != null) {
      final status = request.status.toLowerCase().trim();
      if (status != RideStatus.pending && status != RideStatus.expired) {
        _showRideTakenSnackbar();
        return;
      }
      await openRideDetails(request);
    }
  }

  Future<void> _openRideFromNotification(RideModel ride) async {
    final uid = Get.find<AuthController>().uid;
    final assignedId = ride.driverId?.trim() ?? '';
    final isMine = uid != null && assignedId.isNotEmpty && assignedId == uid;
    final status = ride.status.toLowerCase().trim();
    final claimable =
        status == RideStatus.pending || status == RideStatus.expired;

    if (isMine && RideStatus.isActiveAssignedStatus(status)) {
      await _openActiveRide(ride);
      return;
    }

    if (!claimable || (assignedId.isNotEmpty && !isMine)) {
      rides.removeWhere((item) => item.id == ride.id);
      _showRideTakenSnackbar();
      return;
    }

    if (_isNavigating.value) return;
    _isNavigating.value = true;
    try {
      await Get.toNamed(AppRoutes.ridePending, arguments: ride);
    } finally {
      _isNavigating.value = false;
    }
  }

  /// Opens Active Ride. Does not share the Pending-open `_isNavigating` lock.
  Future<void> _openActiveRide(RideModel ride) async {
    if (_isOpeningActiveRide) return;
    _isOpeningActiveRide = true;
    try {
      // Keep shell under Active Ride so feeds/controllers are not torn down.
      await Get.toNamed(AppRoutes.activeRide, arguments: ride);
    } finally {
      _isOpeningActiveRide = false;
      _isNavigating.value = false;
    }
  }

  void resetNavigation() {
    _isNavigating.value = false;
    _isOpeningActiveRide = false;
  }

  // ==========================================
  // ACCEPTING A RIDE (atomic claim → driver_arriving)
  // ==========================================

  static const String _rideTakenMessage =
      'Another driver accepted this ride first.';

  /// True when the accept denial means the ride is gone / already claimed.
  static bool _isRideTakenOrUnavailable(String? message) {
    final lower = (message ?? '').toLowerCase();
    if (lower.isEmpty) return false;
    return lower.contains('already been accepted') ||
        lower.contains('already accepted') ||
        lower.contains('another driver') ||
        lower.contains('no longer available') ||
        lower.contains('has expired') ||
        lower.contains('expired');
  }

  String _acceptFailureMessage(String? raw) {
    if (_isRideTakenOrUnavailable(raw)) return _rideTakenMessage;
    final trimmed = raw?.trim() ?? '';
    return trimmed.isEmpty ? 'Ride is no longer available.' : trimmed;
  }

  void _showRideTakenSnackbar() {
    AppSnackbar.error(
      title: 'Could not accept',
      message: _rideTakenMessage,
    );
  }

  void _showAcceptFailureSnackbar(String? raw) {
    AppSnackbar.error(
      title: 'Could not accept',
      message: _acceptFailureMessage(raw),
    );
  }

  /// Claims the ride for this driver and opens Active Ride immediately.
  /// Returns `true` only when the claim succeeds.
  Future<bool> acceptRide(RideModel ride, {double? offeredFare}) async {
    if (isAccepting.value) return false;

    final uid = Get.find<AuthController>().uid;
    if (uid == null) return false;

    final activeId = currentRideId.value;
    if (activeId != null && activeId.isNotEmpty) {
      AppSnackbar.error(
        title: 'Already on a ride',
        message:
            'Finish or cancel your current ride before accepting another.',
      );
      return false;
    }

    isAccepting.value = true;
    acceptingRideId.value = ride.id;

    try {
      // Prefer a fresh fix when available; still claim if GPS is slow.
      final position = await _location.getPositionQuick();
      if (isClosed) return false;

      await _firestore.acceptRide(
        rideId: ride.id,
        driverId: uid,
        offeredFare: offeredFare,
        driverLatitude: position?.latitude,
        driverLongitude: position?.longitude,
      );

      if (isClosed) return false;

      rides.removeWhere((item) => item.id == ride.id);
      _dismissedRideIds.remove(ride.id);
      currentRideId.value = ride.id;

      final latest = await _firestore.fetchRide(ride.id) ?? ride;
      if (isClosed) return false;

      AppSnackbar.success(
        title: 'Ride accepted',
        message:
            'Head to ${latest.pickupLocation.isEmpty ? 'the pickup' : latest.pickupLocation}.',
      );

      // Always open Active Ride after a successful claim — never gated by
      // the Pending-open `_isNavigating` flag (FCM / legacy open path).
      await _openActiveRide(latest);
      return true;
    } on StateError catch (error) {
      _showAcceptFailureSnackbar(error.message);
      if (_isRideTakenOrUnavailable(error.message)) {
        rides.removeWhere((item) => item.id == ride.id);
      }
      return false;
    } on FirebaseFunctionsException catch (error) {
      _showAcceptFailureSnackbar(error.message);
      if (_isRideTakenOrUnavailable(error.message)) {
        rides.removeWhere((item) => item.id == ride.id);
      }
      return false;
    } on FirebaseException catch (error) {
      _showAcceptFailureSnackbar(error.message);
      if (_isRideTakenOrUnavailable(error.message)) {
        rides.removeWhere((item) => item.id == ride.id);
      }
      return false;
    } catch (error) {
      debugPrint('acceptRide unexpected error: $error');
      _showAcceptFailureSnackbar(null);
      return false;
    } finally {
      isAccepting.value = false;
      acceptingRideId.value = null;
    }
  }

  /// Hides a pending ride for this driver only (does not cancel in Firestore).
  Future<bool> dismissRide(RideModel ride) async {
    if (isAccepting.value) return false;

    _dismissedRideIds.add(ride.id);
    rides.removeWhere((item) => item.id == ride.id);
    AppSnackbar.info(
      title: 'Ride declined',
      message: 'This ride was hidden from your list.',
    );
    return true;
  }

  /// @deprecated Prefer [dismissRide] for Pending UI. Kept for assigned-ride
  /// admin/support paths that intentionally cancel in Firestore.
  Future<bool> cancelRide(RideModel ride) async {
    return dismissRide(ride);
  }

  // ==========================================
  // ASSIGNED RIDE LIFECYCLE (Cloud Functions)
  // ==========================================

  Future<void> startRide(RideModel ride) {
    return _callLifecycle(ride, 'start', successTitle: 'Ride started');
  }

  Future<void> completeRide(RideModel ride) {
    rides.removeWhere((item) => item.id == ride.id);
    return _callLifecycle(ride, 'complete', successTitle: 'Ride completed');
  }

  Future<void> _callLifecycle(
    RideModel ride,
    String action, {
    required String successTitle,
  }) async {
    try {
      await _firestore.updateRideLifecycle(rideId: ride.id, action: action);
      AppSnackbar.success(
        title: successTitle,
      );
    } on FirebaseFunctionsException catch (error) {
      AppSnackbar.error(
        title: 'Update failed',
        message: error.message ?? 'This ride cannot be updated.',
      );
    } catch (error) {
      AppSnackbar.error(
        title: 'Update failed',
        message: error.toString(),
      );
    }
  }
}
