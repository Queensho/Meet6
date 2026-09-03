import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

class AdminApiService {
  const AdminApiService._();

  static Future<Map<String, dynamic>> me() => _get('/api/admin/me');

  static Future<Map<String, dynamic>> dashboard({int periodDays = 7}) =>
      _get('/api/admin/dashboard?period=${periodDays == 30 ? 30 : 7}');

  static Future<Map<String, dynamic>> _get(String path) async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) {
      throw const ApiException('Admin oturumu bulunamadı.', statusCode: 401);
    }
    final response = await http.get(
      AppConfig.apiUri(path),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 20));

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
            : 'Admin API isteği başarısız oldu.';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
