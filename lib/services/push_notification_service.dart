import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/push/push_target_screen.dart';
import '../theme/app_colors.dart';
import 'app_navigator.dart';
import 'push_api_service.dart';
import 'realtime_service.dart';

@pragma('vm:entry-point')
Future<void> meet6FirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  const PushNotificationService._();

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static Timer? _foregroundBannerTimer;
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

  static Future<void> _setupMessageHandling() async {
    if (_tapHandlingInitialized) return;
    _tapHandlingInitialized = true;

    await _openedAppSubscription?.cancel();
    await _foregroundSubscription?.cancel();

    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(_openNotification(message)),
    );
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundAlert,
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      unawaited(_openNotification(initialMessage));
    }
  }

  static void _showForegroundAlert(RemoteMessage message) {
    final type = message.data['type']?.toString() ?? '';
    final roomId = message.data['roomId']?.toString() ?? '';

    // Kullanıcı zaten aynı canlı oda ekranındaysa mesaj sohbet içinde WebSocket
    // üzerinden anında görünür. Aynı mesajı ayrıca banner olarak göstermeyiz.
    if (type == 'room_message' &&
        roomId.isNotEmpty &&
        RealtimeService.activeRoomId == roomId) {
      return;
    }

    final navigator = AppNavigator.key.currentState;
    final context = navigator?.context;
    if (context == null) return;

    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Meet6 bildirimi';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        '';
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    _foregroundBannerTimer?.cancel();
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        dividerColor: AppColors.border,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.lime,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.navy, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withOpacity(.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '6',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 27,
              height: .9,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
            ),
          ),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (body.trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (message.data.isNotEmpty)
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                unawaited(_openNotification(message));
              },
              child: const Text(
                'Aç',
                style: TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Kapat',
            onPressed: messenger.hideCurrentMaterialBanner,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.navy,
              size: 20,
            ),
          ),
        ],
      ),
    );
    _foregroundBannerTimer = Timer(const Duration(seconds: 8), () {
      messenger.hideCurrentMaterialBanner();
    });
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
      await _setupMessageHandling();

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
    _foregroundBannerTimer?.cancel();
    _foregroundBannerTimer = null;
    await _tokenRefreshSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _openedAppSubscription = null;
    _foregroundSubscription = null;
    _initialized = false;
    _initializing = false;
    _tapHandlingInitialized = false;
    _lastOpenedNotificationId = null;
  }
}
