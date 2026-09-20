import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utilis/map_style.dart';
import 'location_service.dart';
import 'marker_icon_cache.dart';

/// Warms map-related resources after auth / shell is ready.
///
/// Does **not** mount a hidden GoogleMap — Flutter cannot fully pre-paint the
/// native map surface without a real widget. This only preloads marker icons,
/// map style chrome, and a last-known GPS fix so the first map screen mounts
/// with less delay.
///
/// Never starts GPS streams, Firestore listeners, or Directions requests.
class MapWarmupService extends GetxService {
  MapWarmupService({
    LocationService? location,
    MarkerIconCache? icons,
  })  : _location = location ??
            (Get.isRegistered<LocationService>()
                ? Get.find<LocationService>()
                : LocationService()),
        _icons = icons ?? MarkerIconCache.instance;

  final LocationService _location;
  final MarkerIconCache _icons;

  bool _started = false;
  Future<void>? _inFlight;
  LatLng? _warmPosition;

  /// True when icons finished loading (GPS may still be null if denied).
  bool get isReady => _icons.isReady;

  LatLng? get warmPosition => _warmPosition ?? _location.cachedPosition;

  /// Fire-and-forget warmup. Safe to call multiple times.
  void warmInBackground({bool requestPermission = false}) {
    // ignore: discarded_futures
    warm(requestPermission: requestPermission);
  }

  Future<void> warm({bool requestPermission = false}) {
    if (_inFlight != null) return _inFlight!;
    if (_started && isReady) {
      return Future<void>.value();
    }
    _started = true;
    return _inFlight = _run(requestPermission: requestPermission).whenComplete(() {
      _inFlight = null;
    });
  }

  Future<void> _run({required bool requestPermission}) async {
    try {
      // Touch shared style so it is resident before the first map mounts.
      final styleChars = kDarkMapStyle.length;
      assert(styleChars > 0);

      await Future.wait([
        _icons.ensureLoaded(),
        _warmGps(requestPermission: requestPermission),
      ]);
      debugPrint(
        'MapWarmupService: ready '
        '(icons=${_icons.isReady}, gps=${_warmPosition != null}, '
        'styleChars=$styleChars)',
      );
    } catch (error) {
      debugPrint('MapWarmupService failed: $error');
      _started = false;
    }
  }

  Future<void> _warmGps({required bool requestPermission}) async {
    final readiness = await _location.ensureReadyForOnline(
      requestIfDenied: requestPermission,
    );
    if (readiness != LocationReadiness.ready) return;

    final position = await _location.getPositionQuick();
    if (position != null) {
      _warmPosition = position;
      _location.cachePosition(position);
    }
  }
}
