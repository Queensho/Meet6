import 'dart:async';

import 'package:flutter/foundation.dart';

import 'realtime_service.dart';
import 'runtime_app_config_service.dart';

typedef AppRuntimeConfig = RuntimeAppConfig;

class AppRuntimeConfigService {
  const AppRuntimeConfigService._();

  static StreamSubscription<RealtimeEvent>? _subscription;

  static ValueNotifier<RuntimeAppConfig> get value =>
      RuntimeAppConfigService.listenable;

  static void _ensureRealtime() {
    if (_subscription != null) return;
    _subscription = RealtimeService.events.listen((event) {
      if (event.type == 'app:config') {
        unawaited(RuntimeAppConfigService.load(force: true));
      }
    });
  }

  static Future<RuntimeAppConfig> refresh() {
    _ensureRealtime();
    return RuntimeAppConfigService.load(force: true);
  }
}
