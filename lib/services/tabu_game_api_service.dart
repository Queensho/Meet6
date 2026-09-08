import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_service.dart';
import 'session_service.dart';

class TabuGameApiService {
  const TabuGameApiService._();

  static Future<Map<String, dynamic>> state(String roomId) =>
      _request('GET', '/api/rooms/game/$roomId/tabu/state');

  static Future<Map<String, dynamic>> clue(String roomId, String text) =>
      _request(
        'POST',
        '/api/rooms/game/$roomId/tabu/clue',
        body: {'text': text},
      );

  static Future<Map<String, dynamic>> guess(String roomId, String guess) =>
      _request(
        'POST',
        '/api/rooms/game/$roomId/tabu/guess',
        body: {'guess': guess},
      );

  static Future<Map<String, dynamic>> pass(String roomId) =>
      _request('POST', '/api/rooms/game/$roomId/tabu/pass');

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
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
    final response = method == 'GET'
        ? await http.get(uri, headers: headers).timeout(const Duration(seconds: 15))
        : await http
            .post(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
    final decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(data['message']?.toString() ?? 'Tabu isteği başarısız.');
    }
    return data;
  }
}
