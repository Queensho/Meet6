class AppConfig {
  const AppConfig._();

  static const environment = String.fromEnvironment(
    'MEET6_ENV',
    defaultValue: 'development',
  );

  static const _configuredApiBaseUrl = String.fromEnvironment(
    'MEET6_API_BASE_URL',
    defaultValue: '',
  );

  static const revenueCatAndroidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );

  static const revenueCatIosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: '',
  );

  static const revenueCatEntitlementId = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: 'premium',
  );

  // Development/test fallback only. Production builds must inject a real HTTPS
  // domain with --dart-define=MEET6_API_BASE_URL=...
  static const _developmentApiBaseUrl =
      'https://meet6-api-185-165-46-213.nip.io';

  static bool get isProduction => environment.trim().toLowerCase() == 'production';

  static String get apiBaseUrl {
    final configured = _configuredApiBaseUrl.trim();
    final value = configured.isNotEmpty ? configured : _developmentApiBaseUrl;
    final normalized = value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    final uri = Uri.tryParse(normalized);

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('MEET6_API_BASE_URL geçerli bir URL değil.');
    }

    if (isProduction) {
      if (configured.isEmpty) {
        throw StateError('Production build için MEET6_API_BASE_URL zorunlu.');
      }
      if (uri.scheme.toLowerCase() != 'https') {
        throw StateError('Production API yalnızca HTTPS kullanabilir.');
      }
      if (uri.host.toLowerCase().endsWith('.nip.io')) {
        throw StateError('Production build nip.io API adresi kullanamaz.');
      }
    }

    return normalized;
  }

  static Uri apiUri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$apiBaseUrl$normalizedPath');
    return query == null ? uri : uri.replace(queryParameters: query);
  }
}
