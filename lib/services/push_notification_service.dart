import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_api_service.dart';

@pragma('vm:entry-point')
Future<void> meet6FirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  const PushNotificationService._();

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static bool _initialized = false;

  static bool get supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  static Future<void> initializeForAuthenticatedUser() async {
    if (!supportedPlatform || _initialized) return;

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(meet6FirebaseBackgroundHandler);

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

    final token = await messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await PushApiService.registerDevice(
        token: token,
        platform: _platform,
      );
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
      unawaited(
        PushApiService.registerDevice(
          token: newToken,
          platform: _platform,
        ).catchError((_) => <String, dynamic>{}),
      );
    });

    _initialized = true;
  }

  static Future<void> resetRuntimeState() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _initialized = false;
  }
}
