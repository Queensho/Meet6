import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'session_service.dart';

class VoiceRoomConnection {
  const VoiceRoomConnection({
    required this.url,
    required this.token,
    required this.roomName,
  });

  final String url;
  final String token;
  final String roomName;
}

class VoiceRoomService {
  const VoiceRoomService._();

  static Future<Map<String, String>> _headers() async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) {
      throw const ApiException('Oturum bulunamadı.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = const {};
    if (response.body.trim().isNotEmpty) {
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map) data = Map<String, dynamic>.from(raw);
      } catch (_) {}
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final raw = data['message'];
    final message = raw is List
        ? raw.join('\n')
        : raw?.toString() ?? 'Sesli oda isteği başarısız oldu.';
    throw ApiException(message, statusCode: response.statusCode);
  }

  static Uri _uri(String path) => Uri.parse('${ApiService.baseUrl}$path');

  static Future<Map<String, dynamic>> joinQueue() async {
    final response = await http
        .post(_uri('/api/voice-rooms/queue'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> queueStatus() async {
    final response = await http
        .get(_uri('/api/voice-rooms/queue'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  static Future<void> cancelQueue() async {
    final response = await http
        .delete(_uri('/api/voice-rooms/queue'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _decode(response);
  }

  static Future<VoiceRoomConnection> connection(String roomId) async {
    final response = await http
        .post(
          _uri('/api/voice-rooms/$roomId/token'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final data = _decode(response);
    final url = data['url']?.toString() ?? '';
    final token = data['token']?.toString() ?? '';
    final roomName = data['roomName']?.toString() ?? '';
    if (url.isEmpty || token.isEmpty || roomName.isEmpty) {
      throw const ApiException('Sesli oda bağlantı bilgisi alınamadı.');
    }
    return VoiceRoomConnection(url: url, token: token, roomName: roomName);
  }
}
