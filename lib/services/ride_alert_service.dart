import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// Plays [rideComing.wav] and triggers a 2-second vibration pattern every time
/// a new ride request arrives. Call [stop] when the alert is no longer needed.
class RideAlertService {
  RideAlertService();

  final AudioPlayer _player = AudioPlayer();

  bool _isAlerting = false;

  /// Plays the ride-coming ringtone and vibrates for ~2 seconds.
  /// Safe to call multiple times — will not stack if already alerting.
  Future<void> playNewRideAlert() async {
    if (_isAlerting) return;
    _isAlerting = true;

    try {
      // ── Vibration ────────────────────────────────────────────────────────
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        // Pattern: wait 0 ms → vibrate 500 ms → pause 200 ms → vibrate 500 ms
        // → pause 200 ms → vibrate 500 ms  ≈ 2 s total vibration time.
        final hasAmplitude = await Vibration.hasAmplitudeControl();
        if (hasAmplitude) {
          Vibration.vibrate(
            pattern: [0, 500, 200, 500, 200, 500],
            intensities: [0, 200, 0, 200, 0, 200],
          );
        } else {
          Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
        }
      }

      // ── Audio ────────────────────────────────────────────────────────────
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(
        AssetSource('tune/rideComing.wav'),
        volume: 1.0,
      );
    } catch (error) {
      debugPrint('[RideAlertService] playNewRideAlert error: $error');
    }
  }

  /// Stops both the ringtone and any ongoing vibration immediately.
  Future<void> stop() async {
    _isAlerting = false;
    try {
      await _player.stop();
      Vibration.cancel();
    } catch (error) {
      debugPrint('[RideAlertService] stop error: $error');
    }
  }

  /// Releases the audio player. Call when the controller owning this service
  /// is permanently closed.
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
