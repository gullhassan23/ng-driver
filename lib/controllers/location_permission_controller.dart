import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

/// Single source of truth for location permission + service status.
/// Uses Geolocator only to avoid MissingPluginException from a second plugin.
class LocationPermissionController extends GetxController
    with WidgetsBindingObserver {
  final RxBool isServiceEnabled = false.obs;
  final Rx<LocationPermission> permission = LocationPermission.denied.obs;
  final RxBool canUseLocation = false.obs;
  final RxBool isRequesting = false.obs;

  /// In-flight / last status check — reused so callers don't double-wait.
  Future<void>? _statusFuture;

  /// `null` when Play Services' service check threw (common false negative).
  bool? _serviceKnown;

  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  bool get isGranted =>
      permission.value == LocationPermission.always ||
      permission.value == LocationPermission.whileInUse;

  bool get isPermanentlyDenied =>
      permission.value == LocationPermission.deniedForever;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _statusFuture = refreshStatus();
    _listenServiceStatus();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = null;
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshStatus());
    }
  }

  void _listenServiceStatus() {
    _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen(
      (status) {
        final enabled = status == ServiceStatus.enabled;
        _serviceKnown = enabled;
        isServiceEnabled.value = enabled;
        _syncCanUse();
        unawaited(refreshStatus());
      },
      onError: (_) {},
    );
  }

  void _syncCanUse() {
    final serviceOk =
        isServiceEnabled.value || (isGranted && _serviceKnown == null);
    canUseLocation.value = serviceOk && isGranted;
  }

  Future<void> ensureStatus() => _statusFuture ?? refreshStatus();

  Future<void> refreshStatus() async {
    final future = _refreshStatusInternal();
    _statusFuture = future;
    await future;
  }

  Future<void> _refreshStatusInternal() async {
    await _readPermission();
    await _readServiceEnabled();
    _syncCanUse();
  }

  Future<void> _readPermission() async {
    try {
      permission.value = await Geolocator.checkPermission();
    } catch (_) {}
  }

  Future<void> _readServiceEnabled() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      _serviceKnown = enabled;
      isServiceEnabled.value = enabled;
    } catch (_) {
      _serviceKnown = null;
      if (isGranted) {
        isServiceEnabled.value = true;
      }
    }
  }

  Future<bool> onAppResumed() async {
    await refreshStatus();
    return canUseLocation.value;
  }

  /// Requests app permission. Only opens GPS settings when we *know* it is off.
  Future<bool> enableLocation({bool openSettings = true}) async {
    if (isRequesting.value) return isGranted;
    isRequesting.value = true;

    try {
      await refreshStatus();
      if (isGranted) {
        if (openSettings &&
            _serviceKnown == false &&
            !isServiceEnabled.value) {
          await Geolocator.openLocationSettings();
          await refreshStatus();
        }
        return isGranted;
      }

      if (isPermanentlyDenied) {
        if (openSettings) {
          await Geolocator.openAppSettings();
          await refreshStatus();
        }
        return isGranted;
      }

      try {
        permission.value = await Geolocator.requestPermission();
      } catch (_) {
        return isGranted;
      }

      await _readServiceEnabled();
      _syncCanUse();

      if (!isGranted && isPermanentlyDenied && openSettings) {
        await Geolocator.openAppSettings();
        await refreshStatus();
        return isGranted;
      }

      if (isGranted &&
          openSettings &&
          _serviceKnown == false &&
          !isServiceEnabled.value) {
        await Geolocator.openLocationSettings();
        await refreshStatus();
      }

      return isGranted;
    } catch (_) {
      return isGranted;
    } finally {
      isRequesting.value = false;
    }
  }
}
