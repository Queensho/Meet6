import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AppRuntimeConfig {
  const AppRuntimeConfig({
    this.maintenanceEnabled = false,
    this.maintenanceMessage = '',
    this.announcementEnabled = false,
    this.announcementTitle = '',
    this.announcementMessage = '',
    this.roomDurationMinutes = 15,
    this.extensionMinutes = 5,
    this.selectionSeconds = 10,
    this.minimumUsers = 6,
  });

  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final bool announcementEnabled;
  final String announcementTitle;
  final String announcementMessage;
  final int roomDurationMinutes;
  final int extensionMinutes;
  final int selectionSeconds;
  final int minimumUsers;

  factory AppRuntimeConfig.fromJson(Map<String, dynamic> json) {
    final maintenance = json['maintenance'] is Map
        ? Map<String, dynamic>.from(json['maintenance'] as Map)
        : <String, dynamic>{};
    final announcement = json['announcement'] is Map
        ? Map<String, dynamic>.from(json['announcement'] as Map)
        : <String, dynamic>{};
    final room = json['room'] is Map
        ? Map<String, dynamic>.from(json['room'] as Map)
        : <String, dynamic>{};
    int number(String key, int fallback) => (room[key] as num?)?.toInt() ?? fallback;

    return AppRuntimeConfig(
      maintenanceEnabled: maintenance['enabled'] == true,
      maintenanceMessage: maintenance['message']?.toString() ?? '',
      announcementEnabled: announcement['enabled'] == true,
      announcementTitle: announcement['title']?.toString() ?? '',
      announcementMessage: announcement['message']?.toString() ?? '',
      roomDurationMinutes: number('durationMinutes', 15),
      extensionMinutes: number('extensionMinutes', 5),
      selectionSeconds: number('selectionSeconds', 10),
      minimumUsers: number('minimumUsers', 6),
    );
  }
}

class AppRuntimeConfigService {
  const AppRuntimeConfigService._();

  static final ValueNotifier<AppRuntimeConfig> value =
      ValueNotifier<AppRuntimeConfig>(const AppRuntimeConfig());

  static Future<AppRuntimeConfig> refresh() async {
    try {
      final response = await http
          .get(AppConfig.apiUri('/api/app-config'), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return value.value;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return value.value;
      final next = AppRuntimeConfig.fromJson(Map<String, dynamic>.from(decoded));
      value.value = next;
      return next;
    } catch (_) {
      return value.value;
    }
  }
}
