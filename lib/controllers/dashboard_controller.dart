import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/notification_constants.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';
import '../routes/app_navigator.dart';
import '../routes/app_routes.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/map_warmup_service.dart';
import '../services/notification_service.dart';
import '../services/ride_alert_service.dart';
import '../utilis/firestore_paths.dart';
import '../utilis/geo.dart';
import '../views/reservations/new_reservation_request_view.dart';
import '../views/reservations/reservation_detail_view.dart';
import '../widgets/app_snackbar_widget.dart';
import 'active_ride_controller.dart';
import 'auth_controller.dart';
import 'chat_controller.dart';
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

  /// Plays ringtone + vibration when a new ride appears in the pending feed.
  final RideAlertService _rideAlert = RideAlertService();

  /// Tracks ride IDs already seen so we only alert on genuinely new arrivals.
  final Set<String> _knownRideIds = <String>{};

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

  // ── Driver-decline cooldown ─────────────────────────────────────────────
  //
  // When a driver taps "Decline" the ride is hidden locally for [driverDeclineCooldown].
  // The ride status in Firestore stays `pending` — it is NEVER cancelled.
  // After cooldown expires the ride reappears naturally via the existing
  // reactive Firestore listener (no manual refresh required).
  //
  // Separate from rider cancellation / ride expiry — those change Firestore status.
  // This is purely a driver-local, in-memory, timed suppression.

  /// How long a declined ride is hidden from this driver before it may reappear.
  ///
  /// Matches the ride-expiry window (5 min) so a declined ride can come back
  /// exactly once before it expires. Adjust freely — change only this constant.
  static const Duration driverDeclineCooldown = Duration(seconds: 10);

  /// rideId → earliest DateTime at which this driver may see the ride again.
  final Map<String, DateTime> _declinedRideExpiry = {};

  /// Per-ride timers that trigger a listener restart when cooldown expires.
  final Map<String, Timer> _declinedRideTimers = {};

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
  StreamSubscription<Position>? _driverLocationSubscription;
  Worker? _historyFeedWorker;

  /// Current driver GPS fix used for client-side pending ride distance filtering.
  LatLng? _currentDriverPosition;

  /// Raw pending rides received from Firestore before client-side distance & cooldown filters.
  List<RideModel> _latestPendingRides = const [];

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
    _driverLocationSubscription?.cancel();
    _requestsSubscription?.cancel();
    _ridesSubscription?.cancel();
    _tokenSubscription?.cancel();
    _driverSubscription?.cancel();
    _historyFeedWorker?.dispose();
    _cancelAllDeclineTimers();
    unawaited(_notifications.cancelListen());
    unawaited(_rideAlert.dispose());
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

    _notifications.onForegroundMessage = _onForegroundNotification;
    _notifications.onMessageOpened = (message) {
      unawaited(_handleNotificationOpen(message));
    };

    await _notifications.listen();
  }

  String _notificationType(RemoteMessage message) {
    final raw = message.data[NotificationDataKeys.type];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    // Legacy new_ride payloads only carried rideId.
    final rideId = message.data[NotificationDataKeys.rideId];
    if (rideId is String && rideId.trim().isNotEmpty) {
      return NotificationTypes.newRide;
    }
    return '';
  }

  void _onForegroundNotification(RemoteMessage message) {
    if (Get.isRegistered<AuthController>() &&
        Get.find<AuthController>().notificationsPaused.value) {
      return;
    }

    final type = _notificationType(message);
    if (type == NotificationTypes.chatMessage) {
      final isReservation =
          message.data[NotificationDataKeys.isReservation] == 'true';
      final sessionId =
          (message.data[NotificationDataKeys.sessionId] as String?)?.trim() ??
          (isReservation
              ? (message.data[NotificationDataKeys.reservationId] as String?)
                    ?.trim()
              : (message.data[NotificationDataKeys.rideId] as String?)
                    ?.trim()) ??
          '';
      if (ChatController.isViewingSession(
        sessionId: sessionId,
        isReservationSession: isReservation,
      )) {
        return;
      }
    }

    final title =
        message.notification?.title ?? _defaultTitleForType(type);
    final data = message.data;
    String body;
    if (type == NotificationTypes.rideCancelled) {
      body = _cancelBodyFromData(data, isReservation: false);
    } else if (type == NotificationTypes.reservationCancelled) {
      body = _cancelBodyFromData(data, isReservation: true);
    } else {
      body = message.notification?.body ?? _defaultBodyForType(type);
    }

    final isError =
        type == NotificationTypes.rideCancelled ||
        type == NotificationTypes.reservationCancelled;

    if (isError) {
      AppSnackbar.error(
        title: title,
        message: body,
        position: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );
    } else {
      AppSnackbar.success(
        title: title,
        message: body,
        position: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );
    }
  }

  String _defaultTitleForType(String type) {
    switch (type) {
      case NotificationTypes.newReservation:
        return 'New reservation request';
      case NotificationTypes.chatMessage:
        return 'New message';
      case NotificationTypes.rideCancelled:
        return 'Ride cancelled';
      case NotificationTypes.reservationCancelled:
        return 'Reservation cancelled';
      case NotificationTypes.passengerArriving:
        return 'Passenger is coming';
      case NotificationTypes.driverApproved:
        return 'Account approved';
      case NotificationTypes.reservationReminder:
        return 'Upcoming reservation';
      case NotificationTypes.newRide:
      default:
        return 'New ride request';
    }
  }

  String _defaultBodyForType(String type) {
    switch (type) {
      case NotificationTypes.newReservation:
        return 'A rider booked a reservation. Open to review.';
      case NotificationTypes.chatMessage:
        return 'You have a new message from your rider.';
      case NotificationTypes.rideCancelled:
        return 'This ride was cancelled.';
      case NotificationTypes.reservationCancelled:
        return 'This reservation was cancelled.';
      case NotificationTypes.passengerArriving:
        return 'The rider is on the way to the pickup.';
      case NotificationTypes.driverApproved:
        return 'Your driver account is approved.';
      case NotificationTypes.reservationReminder:
        return 'You have a confirmed reservation within the next hour.';
      case NotificationTypes.newRide:
      default:
        return 'A rider is waiting nearby.';
    }
  }

  /// Prefer FCM `cancelledBy` so driver-initiated cancels are not blamed on the rider.
  String _cancelBodyFromData(
    Map<String, dynamic> data, {
    required bool isReservation,
  }) {
    final by =
        (data[NotificationDataKeys.cancelledBy] as String?)
            ?.trim()
            .toLowerCase() ??
        '';
    if (by == 'driver') {
      return isReservation
          ? 'You cancelled this reservation.'
          : 'You cancelled this ride.';
    }
    if (by == 'rider' || by == 'user') {
      return isReservation
          ? 'A rider cancelled your reservation.'
          : 'The rider cancelled this ride.';
    }
    return isReservation
        ? 'This reservation was cancelled.'
        : 'This ride was cancelled.';
  }

  Future<void> _handleNotificationOpen(RemoteMessage message) async {
    final type = _notificationType(message);
    final data = message.data;

    try {
      switch (type) {
        case NotificationTypes.newRide:
          final rideId =
              (data[NotificationDataKeys.rideId] as String?)?.trim() ?? '';
          if (rideId.isNotEmpty) await openRideById(rideId);
          break;
        case NotificationTypes.newReservation:
          await _openReservationFromNotification(
            (data[NotificationDataKeys.reservationId] as String?)?.trim() ?? '',
            preferPendingRequest: true,
          );
          break;
        case NotificationTypes.reservationReminder:
          await _openReservationFromNotification(
            (data[NotificationDataKeys.reservationId] as String?)?.trim() ?? '',
            preferPendingRequest: false,
          );
          break;
        case NotificationTypes.chatMessage:
          await _openChatFromNotification(data);
          break;
        case NotificationTypes.rideCancelled:
          selectNav(homeNavIndex);
          _leaveActiveRideAfterRemoteCancel();
          AppSnackbar.info(
            title: 'Ride cancelled',
            message: _cancelBodyFromData(data, isReservation: false),
          );
          break;
        case NotificationTypes.reservationCancelled:
          selectNav(reservationNavIndex);
          _leaveActiveRideAfterRemoteCancel();
          AppSnackbar.info(
            title: 'Reservation cancelled',
            message: _cancelBodyFromData(data, isReservation: true),
          );
          break;
        case NotificationTypes.passengerArriving:
          final rideId =
              (data[NotificationDataKeys.rideId] as String?)?.trim() ?? '';
          if (rideId.isNotEmpty) {
            final ride = await _firestore.fetchRide(rideId);
            if (ride != null &&
                RideStatus.isActiveAssignedStatus(ride.status)) {
              await _openActiveRide(ride);
            }
          }
          break;
        case NotificationTypes.driverApproved:
          if (Get.currentRoute != AppRoutes.dashboard) {
            Get.offAllNamed(AppRoutes.dashboard);
          }
          break;
        default:
          final rideId =
              (data[NotificationDataKeys.rideId] as String?)?.trim() ?? '';
          if (rideId.isNotEmpty) await openRideById(rideId);
      }
    } catch (error, stack) {
      debugPrint('Notification open failed: $error\n$stack');
      AppSnackbar.error(
        title: 'Could not open',
        message: 'This notification is no longer available.',
      );
    }
  }

  /// Closes Active Ride / in-ride Chat if still open after a remote cancel.
  /// Snackbar is left to the caller so messages are not duplicated.
  void _leaveActiveRideAfterRemoteCancel() {
    if (Get.isRegistered<ActiveRideController>()) {
      Get.find<ActiveRideController>().forceExitOnRemoteCancel(message: '');
      return;
    }
    if (AppNavigator.isOnActiveRideStack()) {
      AppNavigator.leaveActiveRideToDashboard(navIndex: homeNavIndex);
    }
  }

  Future<void> _openReservationFromNotification(
    String reservationId, {
    required bool preferPendingRequest,
  }) async {
    final id = reservationId.trim();
    if (id.isEmpty) return;

    final reservation = await _firestore.fetchReservation(id);
    if (reservation == null) {
      AppSnackbar.error(
        title: 'Reservation unavailable',
        message: 'This reservation could not be found.',
      );
      return;
    }

    if (ReservationStatus.isCancelled(reservation.status)) {
      AppSnackbar.info(
        title: 'Reservation cancelled',
        message: 'This reservation is no longer active.',
      );
      selectNav(homeNavIndex);
      return;
    }

    if (preferPendingRequest &&
        reservation.status.toLowerCase() == ReservationStatus.pending) {
      openNewReservationRequest(reservation);
      return;
    }

    if (ReservationStatus.isConfirm(reservation.status) ||
        ReservationStatus.isLiveActive(reservation.status) ||
        ReservationStatus.isCompleted(reservation.status)) {
      openReservationDetail(reservation);
      return;
    }

    if (reservation.status.toLowerCase() == ReservationStatus.pending) {
      openNewReservationRequest(reservation);
      return;
    }

    AppSnackbar.info(
      title: 'Reservation',
      message: 'This reservation is no longer available to open.',
    );
  }

  Future<void> _openChatFromNotification(Map<String, dynamic> data) async {
    final isReservation = data[NotificationDataKeys.isReservation] == 'true';
    final sessionId =
        (data[NotificationDataKeys.sessionId] as String?)?.trim() ??
        (isReservation
            ? (data[NotificationDataKeys.reservationId] as String?)?.trim()
            : (data[NotificationDataKeys.rideId] as String?)?.trim()) ??
        '';
    if (sessionId.isEmpty) return;

    if (isReservation) {
      final reservation = await _firestore.fetchReservation(sessionId);
      if (reservation == null) {
        AppSnackbar.error(
          title: 'Chat unavailable',
          message: 'This reservation chat is no longer available.',
        );
        return;
      }
      if (!ReservationStatus.isConfirmedOrActive(reservation.status)) {
        AppSnackbar.info(
          title: 'Chat unavailable',
          message: 'This reservation session has ended.',
        );
        return;
      }
      AppNavigator.toReservationChat(
        reservationId: sessionId,
        reservation: reservation,
        rideId: reservation.rideId,
      );
      return;
    }

    final ride = await _firestore.fetchRide(sessionId);
    if (ride == null) {
      AppSnackbar.error(
        title: 'Chat unavailable',
        message: 'This ride chat is no longer available.',
      );
      return;
    }
    if (!RideStatus.isActiveAssignedStatus(ride.status)) {
      AppSnackbar.info(
        title: 'Chat unavailable',
        message: 'This ride session has ended.',
      );
      return;
    }
    AppNavigator.toChat(sessionId);
  }

  void _startPendingRideListeners() {
    _startDriverLocationListener();
    _listenForRideRequests();
    _listenForPendingRides();
  }

  void _stopPendingRideListeners() {
    _stopDriverLocationListener();
    _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _ridesSubscription?.cancel();
    _ridesSubscription = null;
    _latestPendingRides = const [];
    // Clear known IDs so next online session detects fresh rides as new.
    _knownRideIds.clear();
    // Cancel pending cooldown timers — no rides to reappear while offline.
    _cancelAllDeclineTimers();
    unawaited(_rideAlert.stop());
  }

  void _startDriverLocationListener() {
    _driverLocationSubscription?.cancel();

    final cached = _location.cachedPosition;
    if (cached != null) {
      _currentDriverPosition = cached;
    }

    _location.getPositionQuick().then((pos) {
      if (isClosed || !isRideOnline) return;
      if (pos != null) {
        _currentDriverPosition = pos;
        _reapplyPendingRidesFilter();
      }
    });

    _driverLocationSubscription = _location
        .positionStream(distanceFilterMeters: 25, enableBackground: false)
        .listen(
      (pos) {
        final latLng = LatLng(pos.latitude, pos.longitude);
        _location.cachePosition(latLng);
        _currentDriverPosition = latLng;
        _reapplyPendingRidesFilter();
      },
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('Dashboard positionStream error: $error');
        }
      },
    );
  }

  void _stopDriverLocationListener() {
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
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
        _latestPendingRides = pending;
        _reapplyPendingRidesFilter();
      },
      onError: (Object error) {
        errorMessage.value = 'Could not load pending rides. Pull to retry.';
        isLoading.value = false;
      },
    );
  }

  void _reapplyPendingRidesFilter() {
    if (_ridesSubscription == null) return;

    // Filter pending rides by:
    // 1. Not declined and in cooldown window
    // 2. Offer window has not expired
    // 3. Driver current location is within 1.0 mile of ride pickup location
    final filtered = _latestPendingRides
        .where(
          (ride) =>
              !_isDeclinedAndCoolingDown(ride.id) &&
              _isRideAvailableForOffer(ride) &&
              _isRideWithinRadius(ride),
        )
        .toList();

    // Detect any ride IDs that weren't in our known set yet.
    // A ride that reappears after cooldown is already in _knownRideIds,
    // so no duplicate alert plays — correct behaviour.
    bool hasNewRide = false;
    for (final ride in filtered) {
      if (!_knownRideIds.contains(ride.id)) {
        hasNewRide = true;
        _knownRideIds.add(ride.id);
      }
    }

    rides.assignAll(filtered);
    errorMessage.value = null;
    isLoading.value = false;

    // Play alert only when a truly new ride arrives.
    if (hasNewRide && filtered.isNotEmpty) {
      unawaited(_rideAlert.playNewRideAlert());
    }
  }

  /// Returns `true` only when the ride pickup is within [rideRequestRadiusMiles]
  /// (1.0 mile) of the driver's current position.
  ///
  /// If the driver's location is unavailable or pickup coordinates are missing/invalid,
  /// returns `false` (never assume eligible when coordinates cannot be validated).
  bool _isRideWithinRadius(RideModel ride) {
    final driverPos = _currentDriverPosition;
    if (driverPos == null) return false;

    final pickupLat = ride.pickupLatitude;
    final pickupLng = ride.pickupLongitude;
    if (pickupLat == null || pickupLng == null) return false;

    final distanceMiles = milesBetween(
      driverPos.latitude,
      driverPos.longitude,
      pickupLat,
      pickupLng,
    );

    return distanceMiles <= rideRequestRadiusMiles;
  }

  // ── Decline-cooldown helpers ─────────────────────────────────────────────

  /// Returns `true` when [rideId] was declined and the cooldown has not yet
  /// expired for this driver.  Automatically removes stale entries so the
  /// next Firestore emission includes the ride again without any manual refresh.
  bool _isDeclinedAndCoolingDown(String rideId) {
    final expiry = _declinedRideExpiry[rideId];
    if (expiry == null) return false;
    if (DateTime.now().isAfter(expiry)) {
      // Cooldown expired — clean up so the ride is eligible again.
      _declinedRideExpiry.remove(rideId);
      _declinedRideTimers.remove(rideId)?.cancel();
      return false;
    }
    return true; // Still in cooldown window.
  }

  /// Returns `true` when the ride is genuinely available for the driver to
  /// accept: status must be `pending` and the offer window must not have closed.
  ///
  /// This is a client-side pre-filter that covers the ≤1-minute gap between
  /// when `expiresAt` passes and when the Cloud Function marks the ride as
  /// `expired`. The server (CF + Firestore Rules) remains the authority.
  bool _isRideAvailableForOffer(RideModel ride) {
    if (ride.status != RideStatus.pending) return false;
    return !ride.isOfferExpired;
  }

  /// Cancels all pending decline timers (used on offline toggle and onClose).
  void _cancelAllDeclineTimers() {
    for (final timer in _declinedRideTimers.values) {
      timer.cancel();
    }
    _declinedRideTimers.clear();
    _declinedRideExpiry.clear();
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
      // Reject stale FCM taps for rides that have already expired.
      final status = ride.status.toLowerCase().trim();
      final isExpiredStatus = status == RideStatus.expired;
      final isExpiredByTime = ride.isOfferExpired;
      if (isExpiredStatus || (status == RideStatus.pending && isExpiredByTime)) {
        rides.removeWhere((item) => item.id == rideId);
        _showRideTakenSnackbar();
        return;
      }
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
    // A ride is claimable only if status == pending AND it has not yet expired.
    final claimable =
        status == RideStatus.pending && !ride.isOfferExpired;

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

    // Stop the incoming-ride alert as soon as the driver taps Accept.
    unawaited(_rideAlert.stop());

    try {
      // Prefer a fresh fix when available; fallback to current position cache.
      final position = await _location.getPositionQuick();
      if (isClosed) return false;

      final driverLat = position?.latitude ?? _currentDriverPosition?.latitude;
      final driverLng =
          position?.longitude ?? _currentDriverPosition?.longitude;
      final pickupLat = ride.pickupLatitude;
      final pickupLng = ride.pickupLongitude;

      if (driverLat == null || driverLng == null) {
        AppSnackbar.error(
          title: 'Could not accept',
          message: 'Driver location is required to accept this ride.',
        );
        return false;
      }

      if (pickupLat == null || pickupLng == null) {
        AppSnackbar.error(
          title: 'Could not accept',
          message: 'Ride is no longer available.',
        );
        rides.removeWhere((item) => item.id == ride.id);
        return false;
      }

      final distance = milesBetween(driverLat, driverLng, pickupLat, pickupLng);
      if (distance > rideRequestRadiusMiles) {
        AppSnackbar.error(
          title: 'Could not accept',
          message: 'Ride is outside your 1-mile pickup radius.',
        );
        rides.removeWhere((item) => item.id == ride.id);
        return false;
      }

      await _firestore.acceptRide(
        rideId: ride.id,
        driverId: uid,
        offeredFare: offeredFare,
        driverLatitude: driverLat,
        driverLongitude: driverLng,
      );

      if (isClosed) return false;

      rides.removeWhere((item) => item.id == ride.id);
      // Clear any lingering decline-cooldown state for this ride so it can
      // never reappear — another driver already owns it after this accept.
      _declinedRideExpiry.remove(ride.id);
      _declinedRideTimers.remove(ride.id)?.cancel();
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
      if (_isRideTakenOrUnavailable(error.message) ||
          error.message.toLowerCase().contains('outside') &&
              error.message.toLowerCase().contains('radius')) {
        rides.removeWhere((item) => item.id == ride.id);
      }
      return false;
    } on FirebaseFunctionsException catch (error) {
      _showAcceptFailureSnackbar(error.message);
      final msg = error.message ?? '';
      if (_isRideTakenOrUnavailable(msg) ||
          msg.toLowerCase().contains('outside') &&
              msg.toLowerCase().contains('radius')) {
        rides.removeWhere((item) => item.id == ride.id);
      }
      return false;
    } on FirebaseException catch (error) {
      _showAcceptFailureSnackbar(error.message);
      final msg = error.message ?? '';
      if (_isRideTakenOrUnavailable(msg) ||
          msg.toLowerCase().contains('outside') &&
              msg.toLowerCase().contains('radius')) {
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

  /// Temporarily hides a pending ride for this driver only.
  ///
  /// **Does NOT cancel the ride in Firestore.**  The ride status remains
  /// `pending` so the rider continues to see it as active and other eligible
  /// drivers continue to receive it.
  ///
  /// After [driverDeclineCooldown] the ride becomes eligible again for this
  /// driver (naturally, via the reactive Firestore listener — no manual
  /// refresh required) provided it is still pending and no other driver has
  /// accepted it.
  Future<bool> dismissRide(RideModel ride) async {
    if (isAccepting.value) return false;

    // Record when this driver may see the ride again.
    final expiry = DateTime.now().add(driverDeclineCooldown);
    _declinedRideExpiry[ride.id] = expiry;

    // Cancel any existing timer for this ride (e.g. driver declined the same
    // ride a second time after it reappeared).
    _declinedRideTimers[ride.id]?.cancel();

    // Schedule re-evaluation at cooldown expiry.  The listener restart
    // re-queries Firestore and re-applies the filter, so the ride reappears
    // automatically if it is still pending and unclaimed.
    _declinedRideTimers[ride.id] = Timer(driverDeclineCooldown, () {
      if (isClosed) return;
      _declinedRideExpiry.remove(ride.id);
      _declinedRideTimers.remove(ride.id);
      // Remove from known IDs so the ride is treated as a fresh arrival
      // when the listener restarts — this triggers the alert tone + vibration.
      _knownRideIds.remove(ride.id);
      // Only restart if the driver is still ride-online.
      if (onlineMode.value == DriverOnlineMode.ride) {
        _listenForPendingRides();
      }
    });

    // Remove immediately from the visible list.
    rides.removeWhere((item) => item.id == ride.id);

    // Stop alert when driver declines — no more rides to alert for if list empty.
    if (rides.isEmpty) unawaited(_rideAlert.stop());

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
