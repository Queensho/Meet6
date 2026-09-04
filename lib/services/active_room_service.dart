import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_service.dart';
import 'session_service.dart';

class ActiveRoomService {
  const ActiveRoomService._();

  static Future<Map<String, dynamic>> Function()? debugCurrentOverride;
  static Future<Map<String, dynamic>> Function(String roomId)? debugLeaveOverride;

  static Future<String> _token() async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) {
      throw const ApiException('Oturum bulunamadı.');
    }
    return token;
  }

  static Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static String _message(Map<String, dynamic> body, String fallback) {
    final raw = body['message'];
    if (raw is List) return raw.join('\n');
    return raw?.toString() ?? fallback;
  }

  static Future<Map<String, dynamic>> current() async {
    final fake = debugCurrentOverride;
    if (fake != null) return fake();

    final token = await _token();
    final response = await http
        .get(
          AppConfig.apiUri('/api/room-session/current'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 12));
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_message(body, 'Aktif oda kontrol edilemedi.'));
    }
    return body;
  }

  static Future<Map<String, dynamic>> leave(String roomId) async {
    final fake = debugLeaveOverride;
    if (fake != null) return fake(roomId);

    final token = await _token();
    final response = await http
        .delete(
          AppConfig.apiUri('/api/room-session/$roomId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 12));
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_message(body, 'Odadan ayrılamadın.'));
    }
    return body;
  }

  static void debugResetTestHooks() {
    debugCurrentOverride = null;
    debugLeaveOverride = null;
  }
}
