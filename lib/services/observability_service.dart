import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ObservabilityService {
  const ObservabilityService._();

  static FirebaseAnalytics? _analytics;
  static FirebaseCrashlytics? _crashlytics;
  static bool _initialized = false;
  static String? _userId;

  static final Set<String> _roomFound = <String>{};
  static final Set<String> _roomCompleted = <String>{};
  static final Set<String> _matchesCreated = <String>{};

  static bool get initialized => _initialized;
  static FirebaseAnalytics? get analytics => _analytics;

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;

      await _analytics!.setAnalyticsCollectionEnabled(!kDebugMode);
      await _crashlytics!.setCrashlyticsCollectionEnabled(!kDebugMode);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(_recordFlutterError(details));
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(recordError(error, stack, fatal: true, reason: 'platform_dispatcher'));
        return true;
      };

      _initialized = true;
      await logEvent('app_started');
    } catch (error, stack) {
      // Firebase configuration can be absent on a development platform. The app
      // must still boot; production Android/iOS builds should provide Firebase config.
      debugPrint('Observability init failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  static Future<void> setUserId(String? value) async {
    final clean = value?.trim();
    _userId = clean == null || clean.isEmpty ? null : clean;
    if (!_initialized) return;

    try {
      await _analytics?.setUserId(id: _userId);
      await _crashlytics?.setUserIdentifier(_userId ?? 'anonymous');
    } catch (_) {
      // Observability must never block the product flow.
    }
  }

  static Future<void> clearUser() => setUserId(null);

  static Map<String, Object> _cleanParameters(Map<String, Object?> input) {
    final output = <String, Object>{};
    for (final entry in input.entries) {
      final key = entry.key.trim();
      final value = entry.value;
      if (key.isEmpty || value == null) continue;
      if (value is String) {
        final clean = value.trim();
        if (clean.isNotEmpty) output[key] = clean.length > 100 ? clean.substring(0, 100) : clean;
      } else if (value is num) {
        output[key] = value;
      } else if (value is bool) {
        output[key] = value ? 1 : 0;
      }
    }
    return output;
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    if (!_initialized) return;
    try {
      final clean = _cleanParameters(parameters);
      await _analytics?.logEvent(
        name: name,
        parameters: clean.isEmpty ? null : clean,
      );
      await _crashlytics?.log(
        clean.isEmpty ? 'event:$name' : 'event:$name $clean',
      );
    } catch (_) {
      // Metrics must never break a user action.
    }
  }

  static Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String? reason,
    Map<String, Object?> context = const {},
  }) async {
    if (!_initialized) return;
    try {
      for (final entry in _cleanParameters(context).entries) {
        await _crashlytics?.setCustomKey(entry.key, entry.value);
      }
      await _crashlytics?.recordError(
        error,
        stack,
        fatal: fatal,
        reason: reason,
      );
    } catch (_) {
      // Crash reporting failure must not cascade into another crash.
    }
  }

  static Future<void> _recordFlutterError(FlutterErrorDetails details) async {
    if (!_initialized) return;
    try {
      await _crashlytics?.recordFlutterFatalError(details);
    } catch (_) {}
  }

  static Future<bool> _once(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(key) ?? false) return false;
      await prefs.setBool(key, true);
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> registrationCompleted(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return;
    if (!await _once('analytics_registration_completed_$cleanUserId')) return;
    await logEvent('registration_completed');
  }

  static Future<void> profileCompleted() async {
    final suffix = _userId ?? 'unknown';
    if (!await _once('analytics_profile_completed_$suffix')) return;
    await logEvent('profile_completed');
  }

  static Future<void> roomSearchStarted() => logEvent('room_search_started');

  static Future<void> roomFound(String roomId) async {
    final id = roomId.trim();
    if (id.isEmpty || !_roomFound.add(id)) return;
    await logEvent('room_found', parameters: {'room_id': id});
  }

  static Future<void> roomCompleted(String roomId) async {
    final id = roomId.trim();
    if (id.isEmpty || !_roomCompleted.add(id)) return;
    await logEvent('room_completed', parameters: {'room_id': id});
  }

  static Future<void> selectionSubmitted(String roomId) =>
      logEvent('selection_submitted', parameters: {'room_id': roomId});

  static Future<void> matchCreated(String matchId, {String? roomId}) async {
    final id = matchId.trim();
    if (id.isEmpty || !_matchesCreated.add(id)) return;
    await logEvent(
      'match_created',
      parameters: {
        'match_id': id,
        if (roomId != null) 'room_id': roomId,
      },
    );
  }

  static Future<void> firstMessageSent(String matchId) async {
    final id = matchId.trim();
    if (id.isEmpty) return;
    final suffix = _userId ?? 'unknown';
    if (!await _once('analytics_first_message_${suffix}_$id')) return;
    await logEvent('first_message_sent', parameters: {'match_id': id});
  }
}
