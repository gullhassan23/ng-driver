import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

/// Global network reachability (actual internet), not driver presence.
///
/// Distinct from [DashboardController] ride/reservation presence (`onlineMode`).
class ConnectivityController extends GetxController {
  ConnectivityController({
    Connectivity? connectivity,
    http.Client? httpClient,
  }) : _connectivity = connectivity ?? Connectivity(),
       _httpClient = httpClient ?? http.Client();

  static const Duration _probeTimeout = Duration(seconds: 5);
  static const Duration _debounce = Duration(milliseconds: 400);

  /// Lightweight endpoints that return quickly when the network can reach the internet.
  static final List<Uri> _probeUris = [
    Uri.parse('https://www.gstatic.com/generate_204'),
    Uri.parse('https://connectivitycheck.gstatic.com/generate_204'),
  ];

  final Connectivity _connectivity;
  final http.Client _httpClient;

  /// Optimistic default avoids overlay flash / loader on online cold start.
  final hasInternet = true.obs;
  final isRetrying = false.obs;

  /// True when internet is confirmed unavailable (network, not driver presence).
  bool get isOffline => !hasInternet.value;

  /// Convenience alias for callers that expect an "online" flag for internet.
  bool get isOnline => hasInternet.value;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounceTimer;
  int _probeGeneration = 0;
  bool _probeInFlight = false;

  @override
  void onInit() {
    super.onInit();
    _startMonitoring();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _httpClient.close();
    super.onClose();
  }

  Future<void> retry() async {
    if (isRetrying.value || _probeInFlight) return;
    isRetrying.value = true;
    try {
      await _verifyInternet(force: true);
    } finally {
      isRetrying.value = false;
    }
  }

  void _startMonitoring() {
    // Single subscription for the app lifetime (controller is permanent).
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (Object error, StackTrace stack) {
        debugPrint('Connectivity stream error: $error');
      },
    );

    // Silent initial probe — no loader.
    unawaited(_verifyInternet(force: true));
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      unawaited(_verifyInternet(force: false, linkResults: results));
    });
  }

  /// Confirms real internet. Link type alone is never treated as online.
  Future<void> _verifyInternet({
    required bool force,
    List<ConnectivityResult>? linkResults,
  }) async {
    if (_probeInFlight && !force) return;

    final results = linkResults ?? await _connectivity.checkConnectivity();
    final hasLink = results.any((r) => r != ConnectivityResult.none);

    if (!hasLink) {
      _setHasInternet(false);
      return;
    }

    final generation = ++_probeGeneration;
    _probeInFlight = true;
    try {
      final online = await _probeReachability();
      if (generation != _probeGeneration) return;
      _setHasInternet(online);
    } finally {
      if (generation == _probeGeneration) {
        _probeInFlight = false;
      }
    }
  }

  Future<bool> _probeReachability() async {
    for (final uri in _probeUris) {
      try {
        final response = await _httpClient
            .get(uri)
            .timeout(_probeTimeout);
        // generate_204 → 204; some networks rewrite to 200/204.
        if (response.statusCode >= 200 && response.statusCode < 400) {
          return true;
        }
      } catch (error) {
        debugPrint('Internet probe failed ($uri): $error');
      }
    }
    return false;
  }

  void _setHasInternet(bool value) {
    if (hasInternet.value == value) return;
    hasInternet.value = value;
  }
}
