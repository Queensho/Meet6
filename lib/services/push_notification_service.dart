import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/push/push_target_screen.dart';
import 'app_navigator.dart';
import 'push_api_service.dart';

@pragma('vm:entry-point')
Future<void> meet6FirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  const PushNotificationService._();

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;
  static bool _initialized = false;
  static bool _initializing = false;
  static bool _tapHandlingInitialized = false;
  static String? _lastOpenedNotificationId;

  static bool get supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  static Future<void> _registerToken(String token) async {
    final clean = token.trim();
    if (clean.isEmpty) return;

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await PushApiService.registerDevice(
          token: clean,
          platform: _platform,
        );
        return;
      } catch (error) {
        lastError = error;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(seconds: 2 + (attempt * 2)));
        }
      }
    }
    throw lastError ?? StateError('FCM token kaydı başarısız.');
  }

  static Future<void> _setupTapHandling() async {
    if (_tapHandlingInitialized) return;
    _tapHandlingInitialized = true;

    await _openedAppSubscription?.cancel();
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(_openNotification(message)),
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      unawaited(_openNotification(initialMessage));
    }
  }

  static Future<void> _openNotification(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    if (data.isEmpty) return;

    final notificationId = data['notificationId']?.toString();
    if (notificationId != null &&
        notificationId.isNotEmpty &&
        notificationId == _lastOpenedNotificationId) {
      return;
    }
    if (notificationId != null && notificationId.isNotEmpty) {
      _lastOpenedNotificationId = notificationId;
    }

    final type = data['type']?.toString() ?? '';

    for (var attempt = 0; attempt < 40; attempt++) {
      final navigator = AppNavigator.key.currentState;
      if (navigator != null) {
        navigator.push(
          MaterialPageRoute(
            settings: RouteSettings(
              name: 'push:$type:${notificationId ?? ''}',
            ),
            builder: (_) => PushTargetScreen(data: data),
          ),
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  static Future<void> initializeForAuthenticatedUser() async {
    if (!supportedPlatform || _initialized || _initializing) return;
    _initializing = true;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(meet6FirebaseBackgroundHandler);
      await _setupTapHandling();

      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
        unawaited(_registerToken(newToken).catchError((_) {}));
      });

      final token = await messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _registerToken(token);
      }

      _initialized = true;
    } finally {
      _initializing = false;
    }
  }

  static Future<void> resetRuntimeState() async {
    await _tokenRefreshSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _openedAppSubscription = null;
    _initialized = false;
    _initializing = false;
    _tapHandlingInitialized = false;
    _lastOpenedNotificationId = null;
  }
}
