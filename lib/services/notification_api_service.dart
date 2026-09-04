import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'session_service.dart';

class NotificationApiService {
  const NotificationApiService._();

  static const _messageTypes = <String>{
    'message',
    'private_message',
    'room_message',
  };

  static Future<Map<String, dynamic>> _request(
    String method,
    String path,
  ) async {
    final sessionId = await SessionService.loadAuthSessionId();
    if (sessionId == null || sessionId.isEmpty) {
      throw const ApiException('Oturum bulunamadı.');
    }

    final request = http.Request(
      method,
      Uri.parse('${ApiService.baseUrl}$path'),
    )
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $sessionId',
      });

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);

    Map<String, dynamic> data = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // Aşağıda standart API hatası döndürülür.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final rawMessage = data['message'];
    final message = rawMessage is List
        ? rawMessage.join('\n')
        : rawMessage is String
            ? rawMessage
            : 'Bildirim isteği başarısız oldu.';
    throw ApiException(message, statusCode: response.statusCode);
  }

  static Future<Map<String, dynamic>> list() async {
    final response = await _request('GET', '/api/notifications');
    final raw = response['notifications'];
    if (raw is! List) return response;

    final filtered = raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => !_messageTypes.contains(item['type']?.toString() ?? ''))
        .toList(growable: false);

    return <String, dynamic>{
      ...response,
      'notifications': filtered,
      'unread': filtered.where((item) => item['read_at'] == null).length,
    };
  }

  static Future<void> markRead(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;
    await _request('POST', '/api/notifications/$id/read');
  }

  static Future<void> markAllRead() async {
    await _request('POST', '/api/notifications/read');
  }
}
