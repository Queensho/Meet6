import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_service.dart';
import 'session_service.dart';

class MiniGameApiService {
  const MiniGameApiService._();

  static Future<Map<String, dynamic>> state(String roomId) {
    return _request('GET', '/api/rooms/game/$roomId/state');
  }

  static Future<Map<String, dynamic>> submitStatements(
    String roomId,
    List<String> statements,
    int lieIndex,
  ) {
    return _request(
      'POST',
      '/api/rooms/game/$roomId/statements',
      body: {'statements': statements, 'lieIndex': lieIndex},
    );
  }

  static Future<Map<String, dynamic>> vote(String roomId, int choice) {
    return _request(
      'POST',
      '/api/rooms/game/$roomId/vote',
      body: {'choice': choice},
    );
  }

  static Future<Map<String, dynamic>> next(String roomId) {
    return _request('POST', '/api/rooms/game/$roomId/next');
  }

  static Future<Map<String, dynamic>> selectMatch(
    String roomId,
    String selectedUserId,
  ) {
    return _request(
      'PUT',
      '/api/rooms/$roomId/selection',
      body: {'selectedUserId': int.tryParse(selectedUserId)},
    );
  }

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
    late final http.Response response;
    if (method == 'GET') {
      response = await http
          .get(AppConfig.apiUri(path), headers: headers)
          .timeout(const Duration(seconds: 15));
    } else if (method == 'PUT') {
      response = await http
          .put(
            AppConfig.apiUri(path),
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } else {
      response = await http
          .post(
            AppConfig.apiUri(path),
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    }

    final decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(data['message']?.toString() ?? 'Mini oyun isteği başarısız.');
    }
    return data;
  }
}
