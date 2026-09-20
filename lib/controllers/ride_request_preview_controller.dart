import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/ride_model.dart';
import '../services/directions_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/marker_icon_cache.dart';
import '../utilis/firestore_paths.dart';
import '../utilis/map_route_polyline.dart';
import '../widgets/app_snackbar_widget.dart';
import 'auth_controller.dart';

/// Map/route preview for a pending ride request (sheet only — does not claim).
class RideRequestPreviewController extends GetxController {
  RideRequestPreviewController({
    required this.ride,
    DirectionsService? directions,
    LocationService? location,
    FirestoreService? firestore,
    LatLng? driverPosition,
  })  : _directions = directions ??
            (Get.isRegistered<DirectionsService>()
                ? Get.find<DirectionsService>()
                : DirectionsService()),
        _location = location ??
            (Get.isRegistered<LocationService>()
                ? Get.find<LocationService>()
                : LocationService()),
        _firestore = firestore ?? FirestoreService(),
        _initialDriverPosition = driverPosition;

  RideModel ride;
  final DirectionsService _directions;
  final LocationService _location;
  final FirestoreService _firestore;
  final LatLng? _initialDriverPosition;

  final markers = <Marker>{}.obs;
  final polylines = <Polyline>{}.obs;
  final routeDistanceText = ''.obs;
  final routeDurationText = ''.obs;
  final isRouteLoading = true.obs;
  final isMapReady = false.obs;
  final routeError = RxnString();
  final isClaimable = true.obs;

  GoogleMapController? _mapController;
  StreamSubscription<RideModel?>? _rideSubscription;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _stopIcon;
  LatLng? _driverPosition;
  LatLng? _frozenInitialCameraTarget;
  List<LatLng>? _pendingRoutePoints;
  Set<Marker> _pendingMarkers = {};
  Set<Polyline> _pendingPolylines = {};
  bool _disposed = false;
  bool _initialCameraFitted = false;

  static const _polylineId = PolylineId('preview_route');
  static const _driverMarkerId = MarkerId('driver');

  /// Frozen once for GoogleMap init — prefer pickup over Seattle.
  LatLng get initialCameraTarget =>
      _frozenInitialCameraTarget ??
      ride.pickupLatLng ??
      ride.dropoffLatLng ??
      _location.cachedPosition ??
      const LatLng(0, 0);

  bool get hasMapCoords =>
      ride.pickupLatLng != null || ride.dropoffLatLng != null;

  @override
  void onInit() {
    super.onInit();
    _driverPosition =
        _initialDriverPosition ?? _location.cachedPosition;
    _freezeInitialCameraTarget(
      ride.pickupLatLng ??
          ride.dropoffLatLng ??
          _driverPosition,
    );
    _applyCachedIconsIfReady();
    _rebuildMarkers();
    _watchRideStatus();
    _bootstrap();
  }

  @override
  void onClose() {
    _disposed = true;
    _rideSubscription?.cancel();
    _rideSubscription = null;
    _mapController = null;
    super.onClose();
  }

  void _watchRideStatus() {
    _rideSubscription?.cancel();
    _rideSubscription = _firestore.watchRide(ride.id).listen(
      (updated) {
        if (_disposed || updated == null) return;
        ride = updated;
        final status = updated.status.toLowerCase().trim();
        final claimable =
            status == RideStatus.pending || status == RideStatus.expired;
        final assigned = updated.driverId?.trim() ?? '';
        final uid = Get.isRegistered<AuthController>()
            ? (Get.find<AuthController>().uid ?? '')
            : '';
        final stillMine = assigned.isEmpty || assigned == uid;
        isClaimable.value = claimable && stillMine;
        if (!isClaimable.value) {
          AppSnackbar.info(
            title: 'Ride unavailable',
            message: 'This ride is no longer available.',
          );
          if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
            Get.back();
          }
        }
      },
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('preview watchRide error: $error');
        }
      },
    );
  }

  void _freezeInitialCameraTarget(LatLng? target) {
    if (_frozenInitialCameraTarget != null || target == null) return;
    _frozenInitialCameraTarget = target;
  }

  Future<void> onMapCreated(GoogleMapController controller) async {
    if (_disposed) return;
    _mapController = controller;
    _publishDecorations();
    await _fitCamera(
      routePoints: _pendingRoutePoints,
      animate: false,
    );
    if (_disposed) return;
    _initialCameraFitted = true;
    isMapReady.value = true;
  }

  Future<void> _bootstrap() async {
    isRouteLoading.value = true;
    routeError.value = null;

    await _ensureMarkerIcons();
    if (_disposed) return;

    _driverPosition ??=
        await _location.getPositionQuick() ??
        await _location.getCurrentPosition();
    if (_disposed) return;
    if (_driverPosition != null) {
      _location.cachePosition(_driverPosition!);
    }

    _rebuildMarkers();

    final pickup = ride.pickupLatLng;
    final dropoff = ride.dropoffLatLng;

    if (pickup == null || dropoff == null) {
      isRouteLoading.value = false;
      routeError.value = hasMapCoords
          ? 'Pickup or dropoff coordinates are incomplete.'
          : 'Map coordinates are missing for this ride.';
      await _fitCamera(animate: _initialCameraFitted);
      return;
    }

    try {
      final route = await _directions.getDrivingRoute(
        origin: pickup,
        destination: dropoff,
        waypoints: ride.allStopWaypoints(),
      );
      if (_disposed) return;

      _pendingRoutePoints = route.points;
      _pendingPolylines = {
        buildMapRoutePolyline(
          id: _polylineId,
          points: route.points,
        ),
      };
      _publishDecorations();
      routeDistanceText.value = route.distanceText;
      routeDurationText.value = route.durationText;
      routeError.value = null;
      await _fitCamera(
        routePoints: route.points,
        animate: _initialCameraFitted,
      );
    } on DirectionsException catch (error) {
      debugPrint('Preview directions failed: $error');
      if (_disposed) return;
      routeError.value = error.message;
      _pendingPolylines = {
        buildMapRoutePolyline(
          id: _polylineId,
          points: straightRoutePoints(
            origin: pickup,
            destination: dropoff,
            waypoints: ride.allStopWaypoints(),
          ),
        ),
      };
      _publishDecorations();
      await _fitCamera(animate: _initialCameraFitted);
    } catch (error) {
      debugPrint('Preview directions unexpected: $error');
      if (_disposed) return;
      routeError.value = error.toString();
      _pendingPolylines = {
        buildMapRoutePolyline(
          id: _polylineId,
          points: straightRoutePoints(
            origin: pickup,
            destination: dropoff,
            waypoints: ride.allStopWaypoints(),
          ),
        ),
      };
      _publishDecorations();
      await _fitCamera(animate: _initialCameraFitted);
    } finally {
      if (!_disposed) isRouteLoading.value = false;
    }
  }

  void _applyCachedIconsIfReady() {
    final cache = MarkerIconCache.instance;
    _pickupIcon ??= cache.pickupOrNull;
    _dropoffIcon ??= cache.dropoffOrNull;
    _driverIcon ??= cache.driverOrNull;
    _stopIcon ??= cache.stopOrNull;
  }

  Future<void> _ensureMarkerIcons() async {
    _applyCachedIconsIfReady();
    if (_pickupIcon != null &&
        _dropoffIcon != null &&
        _driverIcon != null &&
        _stopIcon != null) {
      return;
    }

    final cache = MarkerIconCache.instance;
    try {
      await cache.ensureLoaded();
    } catch (error, stack) {
      debugPrint('Preview marker cache failed: $error\n$stack');
    }
    _pickupIcon ??= cache.pickupOrNull;
    _dropoffIcon ??= cache.dropoffOrNull;
    _driverIcon ??= cache.driverOrNull;
    _stopIcon ??= cache.stopOrNull;
  }

  void _rebuildMarkers() {
    final next = <Marker>{};

    final pickup = ride.pickupLatLng;
    if (pickup != null) {
      next.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: 'Pickup',
            snippet: ride.pickupLocation,
          ),
          icon: _pickupIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    final dropoff = ride.dropoffLatLng;
    if (dropoff != null) {
      next.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: 'Dropoff',
            snippet: ride.dropoffLocation,
          ),
          icon: _dropoffIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    for (var i = 0; i < ride.stops.length; i++) {
      final position = ride.stops[i].latLng;
      if (position == null) continue;
      next.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: position,
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: 'Stop ${i + 1}',
            snippet: ride.stops[i].location,
          ),
          icon: _stopIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    final driver = _driverPosition;
    if (driver != null) {
      next.add(
        Marker(
          markerId: _driverMarkerId,
          position: driver,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
          flat: true,
          infoWindow: const InfoWindow(title: 'You'),
          icon: _driverIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow,
              ),
        ),
      );
    }

    _pendingMarkers = next;
    _publishDecorations();
  }

  /// Push pending markers/polylines to reactive sets once the map exists,
  /// or immediately so ReactiveAppMap can show them when the platform is ready.
  void _publishDecorations() {
    if (_disposed) return;
    markers.assignAll(_pendingMarkers);
    polylines.assignAll(_pendingPolylines);
    markers.refresh();
    polylines.refresh();
  }

  Future<void> _fitCamera({
    List<LatLng>? routePoints,
    bool animate = true,
  }) async {
    final controller = _mapController;
    if (controller == null || _disposed) return;

    final points = <LatLng>[
      ...?routePoints,
      ?ride.pickupLatLng,
      ...ride.allStopWaypoints(),
      ?ride.dropoffLatLng,
      ?_driverPosition,
    ];

    if (points.isEmpty) return;

    Future<void> apply(CameraUpdate update) {
      return animate
          ? controller.animateCamera(update)
          : controller.moveCamera(update);
    }

    try {
      if (points.length == 1) {
        await apply(CameraUpdate.newLatLngZoom(points.first, 14));
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
        await apply(CameraUpdate.newLatLngBounds(bounds, 80));
      } catch (_) {
        await apply(CameraUpdate.newLatLngZoom(points.first, 14));
      }
    } catch (error) {
      debugPrint('Preview fitCamera failed: $error');
    }
  }
}
