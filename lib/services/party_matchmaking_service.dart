import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_service.dart';
import 'session_service.dart';

class PartyMatchmakingService {
  const PartyMatchmakingService._();

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
  }) async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) {
      throw const ApiException('Oturum bulunamadı.');
    }
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final uri = AppConfig.apiUri(path);
    late http.Response response;
    if (method == 'POST') {
      response = await http
          .post(uri, headers: headers, body: body == null ? null : jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } else if (method == 'GET') {
      response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    } else if (method == 'DELETE') {
      response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
    } else {
      throw const ApiException('İstek tamamlanamadı.');
    }

    final decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final result = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final raw = result['message'];
      throw ApiException(raw is List ? raw.join('\n') : raw?.toString() ?? 'İstek tamamlanamadı.');
    }
    return result;
  }

  static Future<Map<String, dynamic>> create({
    required String roomMode,
    required int roomDurationMinutes,
    String? gameKey,
  }) {
    return _request(
      'POST',
      '/api/rooms/party',
      body: {
        'roomMode': roomMode,
        'roomDurationMinutes': roomDurationMinutes,
        if (gameKey != null) 'gameKey': gameKey,
      },
    );
  }

  static Future<Map<String, dynamic>> accept(String code) {
    return _request(
      'POST',
      '/api/rooms/party/accept',
      body: {'code': code.trim().toUpperCase()},
    );
  }

  static Future<Map<String, dynamic>> search(String code) {
    return _request(
      'POST',
      '/api/rooms/party/search',
      body: {'code': code.trim().toUpperCase()},
    );
  }

  static Future<Map<String, dynamic>> status(String code) {
    return _request(
      'GET',
      '/api/rooms/party?code=${Uri.encodeQueryComponent(code.trim().toUpperCase())}',
    );
  }

  static Future<Map<String, dynamic>> cancel(String code) {
    return _request(
      'DELETE',
      '/api/rooms/party?code=${Uri.encodeQueryComponent(code.trim().toUpperCase())}',
    );
  }
}
