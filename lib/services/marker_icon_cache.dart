import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utilis/driver_car_marker.dart';

/// Process-wide cache for decoded map marker icons.
///
/// Decoding assets (codec + flood-fill + PNG encode) is expensive on the UI
/// isolate. Warm once after the main shell mounts so Active Ride / preview
/// screens do not pay that cost on the critical path.
class MarkerIconCache {
  MarkerIconCache._();
  static final MarkerIconCache instance = MarkerIconCache._();

  BitmapDescriptor? _driver;
  BitmapDescriptor? _pickup;
  BitmapDescriptor? _dropoff;
  BitmapDescriptor? _stop;
  Future<void>? _loading;

  BitmapDescriptor? get driverOrNull => _driver;
  BitmapDescriptor? get pickupOrNull => _pickup;
  BitmapDescriptor? get dropoffOrNull => _dropoff;
  BitmapDescriptor? get stopOrNull => _stop;

  bool get isReady =>
      _driver != null &&
      _pickup != null &&
      _dropoff != null &&
      _stop != null;

  /// Loads all marker icons once. Concurrent callers share the same future.
  Future<void> ensureLoaded() {
    if (isReady) return Future<void>.value();
    return _loading ??= _loadAll();
  }

  Future<BitmapDescriptor> driver() async {
    await ensureLoaded();
    return _driver ??
        await createDriverCarMarkerIcon().then((icon) {
          _driver = icon;
          return icon;
        });
  }

  Future<BitmapDescriptor> pickup() async {
    await ensureLoaded();
    return _pickup ??
        await createPickupMarkerIcon().then((icon) {
          _pickup = icon;
          return icon;
        });
  }

  Future<BitmapDescriptor> dropoff() async {
    await ensureLoaded();
    return _dropoff ??
        await createDropoffMarkerIcon().then((icon) {
          _dropoff = icon;
          return icon;
        });
  }

  Future<BitmapDescriptor> stop() async {
    await ensureLoaded();
    return _stop ??
        await createStopMarkerIcon().then((icon) {
          _stop = icon;
          return icon;
        });
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        createDriverCarMarkerIcon(),
        createPickupMarkerIcon(),
        createDropoffMarkerIcon(),
        createStopMarkerIcon(),
      ]);
      _driver = results[0];
      _pickup = results[1];
      _dropoff = results[2];
      _stop = results[3];
      debugPrint('MarkerIconCache: icons ready');
    } catch (error, stack) {
      debugPrint('MarkerIconCache load failed: $error\n$stack');
      // Allow retry on next ensureLoaded.
      _loading = null;
    }
  }
}
