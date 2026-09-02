import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session_service.dart';

class PushApiService {
  const PushApiService._();

  static const _baseUrl = 'https://meet6-api-185-165-46-213.nip.io';

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final sessionId = await SessionService.loadAuthSessionId();
    if (sessionId == null || sessionId.isEmpty) {
      throw StateError('Push işlemi için oturum gerekli.');
    }

    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $sessionId',
      });
    if (body != null) request.body = jsonEncode(body);

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message'];
      throw StateError(message is String ? message : 'Push isteği başarısız.');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> status() =>
      _request('GET', '/api/push/status');

  static Future<Map<String, dynamic>> registerDevice({
    required String token,
    required String platform,
    String? appInstanceId,
  }) =>
      _request(
        'POST',
        '/api/push/devices',
        body: {
          'token': token,
          'platform': platform,
          if (appInstanceId != null && appInstanceId.trim().isNotEmpty)
            'appInstanceId': appInstanceId.trim(),
        },
      );

  static Future<void> unregisterDevice(String token) async {
    await _request(
      'DELETE',
      '/api/push/devices',
      body: {'token': token},
    );
  }

  static Future<Map<String, dynamic>> sendTestNotification() =>
      _request('POST', '/api/push/test');
}
