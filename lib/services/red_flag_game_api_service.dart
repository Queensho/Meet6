import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_service.dart';
import 'session_service.dart';

class RedFlagGameApiService {
  const RedFlagGameApiService._();

  static Future<Map<String, dynamic>> state(String roomId) =>
      _request('GET', '/api/rooms/game/$roomId/red-flag/state');

  static Future<Map<String, dynamic>> choose(
    String roomId,
    String choice,
  ) =>
      _request(
        'POST',
        '/api/rooms/game/$roomId/red-flag/choice',
        body: {'choice': choice},
      );

  static Future<Map<String, dynamic>> finalChoice(
    String roomId, {
    required bool match,
  }) =>
      _request(
        'POST',
        '/api/rooms/game/$roomId/red-flag/final-choice',
        body: {'choice': match ? 'match' : 'continue'},
      );

  static Future<List<Map<String, dynamic>>> messages(
    String roomId, {
    int after = 0,
  }) async {
    final data = await _request(
      'GET',
      '/api/rooms/$roomId/messages?after=$after',
    );
    final raw = data['messages'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<Map<String, dynamic>> sendMessage(
    String roomId,
    String body,
  ) =>
      _request(
        'POST',
        '/api/rooms/$roomId/messages',
        body: {'body': body},
      );

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
      throw ApiException(
        data['message']?.toString() ?? 'Red Flag / Green Flag isteği başarısız.',
      );
    }
    return data;
  }
}
