import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

class AdminSettingsApiService {
  const AdminSettingsApiService._();

  static Future<Map<String, dynamic>> get() => _request('GET');

  static Future<Map<String, dynamic>> update(Map<String, dynamic> body) =>
      _request('POST', body: body);

  static Future<Map<String, dynamic>> _request(
    String method, {
    Map<String, dynamic>? body,
  }) async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) {
      throw const ApiException('Admin oturumu bulunamadı.', statusCode: 401);
    }
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final uri = AppConfig.apiUri('/api/admin/settings');
    final response = method == 'POST'
        ? await http
            .post(uri, headers: headers, body: jsonEncode(body ?? const {}))
            .timeout(const Duration(seconds: 20))
        : await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

    Map<String, dynamic> data = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final raw = data['message'];
    final message = raw is List
        ? raw.join('\n')
        : raw is String
            ? raw
            : 'Ayarlar kaydedilemedi.';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
