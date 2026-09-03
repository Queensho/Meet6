import 'dart:async';

import 'package:flutter/foundation.dart';

import 'live_service.dart';
import 'realtime_service.dart';

class UnreadMessagesService {
  const UnreadMessagesService._();

  static final ValueNotifier<int> count = ValueNotifier<int>(0);
  static StreamSubscription<RealtimeEvent>? _subscription;
  static bool _initialized = false;

  static void applySnapshot(Map<String, dynamic> data) {
    final next = (data['unreadTotal'] as num?)?.toInt() ?? 0;
    count.value = next < 0 ? 0 : next;
  }

  static Future<void> refresh() async {
    try {
      final data = await LiveService.matches();
      applySnapshot(data);
    } catch (_) {
      // Ağ geçici olarak yoksa son doğru rozeti koru.
    }
  }

  static Future<void> initialize() async {
    if (_initialized) {
      await refresh();
      return;
    }
    _initialized = true;
    await _subscription?.cancel();
    _subscription = RealtimeService.events.listen((event) {
      if (event.type == 'matches:update') {
        applySnapshot(event.data);
      } else if (event.type == 'connection:connected') {
        unawaited(refresh());
      }
    });
    await refresh();
  }

  static Future<void> reset() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    count.value = 0;
  }
}
