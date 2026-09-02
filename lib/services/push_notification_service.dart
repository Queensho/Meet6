import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/push/push_target_screen.dart';
import 'app_navigator.dart';
import 'push_api_service.dart';
import 'session_service.dart';

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
    final screen = data['screen']?.toString() ?? '';

    for (var attempt = 0; attempt < 40; attempt++) {
      final navigator = AppNavigator.key.currentState;
      if (navigator != null) {
        if (type == 'push_test' || screen == 'home') {
          navigator.popUntil((route) => route.isFirst);
          return;
        }
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
      try {
        await PushApiService.status();
      } catch (_) {
        // Status ping is diagnostic only; Firebase setup can still continue.
      }

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

  static Future<String> diagnoseAndRegister() async {
    final lines = <String>[];

    if (!supportedPlatform) {
      return 'Bu cihazda native push testi desteklenmiyor.';
    }

    final sessionId = await SessionService.loadAuthSessionId();
    if (sessionId == null || sessionId.trim().isEmpty) {
      return '❌ Backend oturum tokenı yok.\nÇıkış yapıp yeniden giriş yap.';
    }
    lines.add('✅ Backend oturumu var');

    try {
      final status = await PushApiService.status();
      lines.add('✅ Meet6 API erişimi var');
      lines.add(
        'Backend cihaz sayısı: ${status['registeredDevices'] ?? 0}',
      );
    } catch (error) {
      lines.add('❌ Meet6 API erişimi başarısız');
      lines.add(error.toString());
      return lines.join('\n');
    }

    try {
      await Firebase.initializeApp();
      await _setupTapHandling();
      lines.add('✅ Firebase başlatıldı');
    } catch (error) {
      lines.add('❌ Firebase başlatılamadı');
      lines.add(error.toString());
      return lines.join('\n');
    }

    final messaging = FirebaseMessaging.instance;

    try {
      var settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      lines.add('Bildirim izni: ${settings.authorizationStatus.name}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        lines.add('❌ Android ayarlarından bildirim izni ver.');
        return lines.join('\n');
      }
    } catch (error) {
      lines.add('❌ Bildirim izni okunamadı');
      lines.add(error.toString());
      return lines.join('\n');
    }

    String? token;
    try {
      token = await messaging.getToken().timeout(const Duration(seconds: 20));
      if (token == null || token.trim().isEmpty) {
        lines.add('❌ Firebase FCM token döndürmedi');
        return lines.join('\n');
      }
      final clean = token.trim();
      final preview = clean.length > 14 ? clean.substring(0, 14) : clean;
      lines.add('✅ FCM token alındı: $preview…');
    } catch (error) {
      lines.add('❌ FCM token alınamadı');
      lines.add(error.toString());
      return lines.join('\n');
    }

    try {
      await _registerToken(token);
      lines.add('✅ Token Meet6 API’ye kaydedildi');
    } catch (error) {
      lines.add('❌ Meet6 API token kaydı başarısız');
      lines.add(error.toString());
      return lines.join('\n');
    }

    try {
      final status = await PushApiService.status();
      final count = status['registeredDevices'] ?? 0;
      final firebase = status['firebaseConfigured'] == true ? 'aktif' : 'pasif';
      lines.add('✅ Backend cihaz sayısı: $count');
      lines.add('Firebase worker: $firebase');
    } catch (error) {
      lines.add('⚠️ Backend push durumu okunamadı');
      lines.add(error.toString());
    }

    _initialized = true;
    return lines.join('\n');
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
