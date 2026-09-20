import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Runs in a separate isolate, so Firebase has to be initialized again here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Data-only messages: ensure the payload is acknowledged in logs.
  // Display notifications are shown by the OS when a `notification` block
  // is present; this handler keeps Firebase warm for token/data work.
  if (kDebugMode) {
    debugPrint(
      'Background FCM: id=${message.messageId} '
      'data=${message.data} '
      'notification=${message.notification?.title}',
    );
  }
}

/// Wraps Firebase Cloud Messaging: permissions, the device token, and the
/// three ways a ride-request notification can arrive.
///
/// [listen] is idempotent process-wide so re-entering the dashboard does not
/// stack duplicate FCM handlers.
class NotificationService {
  NotificationService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onOpenedSub;
  static bool _initialMessageHandled = false;
  static NotificationService? _active;

  /// Called when a notification arrives while the app is in the foreground.
  ValueChanged<RemoteMessage>? onForegroundMessage;

  /// Called when the driver taps a notification, from either a background or
  /// a terminated state.
  ValueChanged<RemoteMessage>? onMessageOpened;

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> deviceToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      debugPrint('Could not read FCM token: $error');
    }
    return null;
  }

  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  /// Wires up the message listeners. Safe to call repeatedly.
  Future<void> listen() async {
    _active = this;

    _onMessageSub ??= FirebaseMessaging.onMessage.listen((message) {
      _active?.onForegroundMessage?.call(message);
    });

    _onOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _active?.onMessageOpened?.call(message);
    });

    // The app may have been launched by tapping a notification.
    if (!_initialMessageHandled) {
      _initialMessageHandled = true;
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _active?.onMessageOpened?.call(initialMessage);
      }
    }
  }

  /// Clears this instance as the active callback target. Does not tear down
  /// the process-wide FCM stream subscriptions (those stay for the app life).
  Future<void> cancelListen() async {
    if (_active == this) {
      onForegroundMessage = null;
      onMessageOpened = null;
      _active = null;
    }
  }

  /// Fully tears down process-wide listeners (e.g. on sign-out).
  static Future<void> resetListeners() async {
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    _onMessageSub = null;
    _onOpenedSub = null;
    _initialMessageHandled = false;
    _active = null;
  }
}
