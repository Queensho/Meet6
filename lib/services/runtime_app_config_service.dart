import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class RuntimeAppConfig {
  const RuntimeAppConfig({
    this.roomDurationMinutes = 15,
    this.extensionMinutes = 5,
    this.selectionSeconds = 10,
    this.minimumUsers = 6,
    this.maintenanceEnabled = false,
    this.maintenanceMessage = 'Meet6 kısa süreli bakımda. Lütfen biraz sonra tekrar dene.',
    this.announcementEnabled = false,
    this.announcementTitle = '',
    this.announcementMessage = '',
  });

  final int roomDurationMinutes;
  final int extensionMinutes;
  final int selectionSeconds;
  final int minimumUsers;
  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final bool announcementEnabled;
  final String announcementTitle;
  final String announcementMessage;

  factory RuntimeAppConfig.fromJson(Map<String, dynamic> json) {
    final room = Map<String, dynamic>.from((json['room'] as Map?) ?? const {});
    final maintenance = Map<String, dynamic>.from((json['maintenance'] as Map?) ?? const {});
    final announcement = Map<String, dynamic>.from((json['announcement'] as Map?) ?? const {});
    return RuntimeAppConfig(
      roomDurationMinutes: (room['durationMinutes'] as num?)?.toInt() ?? 15,
      extensionMinutes: (room['extensionMinutes'] as num?)?.toInt() ?? 5,
      selectionSeconds: (room['selectionSeconds'] as num?)?.toInt() ?? 10,
      minimumUsers: (room['minimumUsers'] as num?)?.toInt() ?? 6,
      maintenanceEnabled: maintenance['enabled'] == true,
      maintenanceMessage: maintenance['message']?.toString() ??
          'Meet6 kısa süreli bakımda. Lütfen biraz sonra tekrar dene.',
      announcementEnabled: announcement['enabled'] == true,
      announcementTitle: announcement['title']?.toString() ?? '',
      announcementMessage: announcement['message']?.toString() ?? '',
    );
  }
}

class RuntimeAppConfigService {
  const RuntimeAppConfigService._();

  static RuntimeAppConfig _cached = const RuntimeAppConfig();
  static DateTime? _loadedAt;

  static RuntimeAppConfig get cached => _cached;

  static Future<RuntimeAppConfig> load({bool force = false}) async {
    final loadedAt = _loadedAt;
    if (!force && loadedAt != null && DateTime.now().difference(loadedAt) < const Duration(seconds: 20)) {
      return _cached;
    }
    try {
      final response = await http
          .get(AppConfig.apiUri('/api/app-config'), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return _cached;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return _cached;
      _cached = RuntimeAppConfig.fromJson(Map<String, dynamic>.from(decoded));
      _loadedAt = DateTime.now();
    } catch (_) {}
    return _cached;
  }
}
