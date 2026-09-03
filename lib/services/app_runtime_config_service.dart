import 'package:flutter/foundation.dart';

import 'runtime_app_config_service.dart';

typedef AppRuntimeConfig = RuntimeAppConfig;

class AppRuntimeConfigService {
  const AppRuntimeConfigService._();

  static ValueNotifier<RuntimeAppConfig> get value =>
      RuntimeAppConfigService.listenable;

  static Future<RuntimeAppConfig> refresh() =>
      RuntimeAppConfigService.load(force: true);
}
