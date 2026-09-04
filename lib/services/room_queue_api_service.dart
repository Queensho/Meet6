import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_service.dart';
import 'session_service.dart';

class RoomQueueApiService {
  const RoomQueueApiService._();

  static Future<Map<String, dynamic>> joinQueue({
    int roomDurationMinutes = 15,
  }) async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) {
      throw const ApiException('Oturum bulunamadı.');
    }

    final response = await http
        .post(
          AppConfig.apiUri('/api/rooms/queue'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'roomDurationMinutes': roomDurationMinutes}),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final raw = body['message'];
      final message = raw is List
          ? raw.join('\n')
          : raw?.toString() ?? 'Oda araması başlatılamadı.';
      throw ApiException(message);
    }
    return body;
  }
}
