import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'session_service.dart';

class LiveService {
  const LiveService._();

  static Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${ApiService.baseUrl}$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  static Future<Map<String, String>> _headers() async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) throw const ApiException('Oturum bulunamadı.');
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = const {};
    if (response.body.isNotEmpty) {
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) data = raw;
      } catch (_) {}
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final rawMessage = data['message'];
    final message = rawMessage is List
        ? rawMessage.join('\n')
        : rawMessage?.toString() ?? 'Sunucu isteği başarısız oldu.';
    throw ApiException(message, statusCode: response.statusCode);
  }

  static Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await http
        .get(_uri(path, query), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    final headers = await _headers();
    final encoded = body == null ? null : jsonEncode(body);
    late http.Response response;
    if (method == 'POST') {
      response = await http.post(_uri(path), headers: headers, body: encoded);
    } else if (method == 'PUT') {
      response = await http.put(_uri(path), headers: headers, body: encoded);
    } else if (method == 'DELETE') {
      response = await http.delete(_uri(path), headers: headers, body: encoded);
    } else {
      throw const ApiException('Desteklenmeyen istek.');
    }
    return _decode(response);
  }

  static Future<Map<String, dynamic>> joinRoomQueue() => _send('POST', '/api/rooms/queue');
  static Future<Map<String, dynamic>> roomQueueStatus() => _get('/api/rooms/queue');
  static Future<void> cancelRoomQueue() async => _send('DELETE', '/api/rooms/queue');

  static Future<Map<String, dynamic>> room(String roomId) => _get('/api/rooms/$roomId');

  static Future<List<Map<String, dynamic>>> roomMessages(
    String roomId, {
    int after = 0,
  }) async {
    final data = await _get('/api/rooms/$roomId/messages', query: {'after': '$after'});
    final raw = data['messages'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<Map<String, dynamic>> sendRoomMessage(String roomId, String body) =>
      _send('POST', '/api/rooms/$roomId/messages', body: {'body': body});

  static Future<Map<String, dynamic>> voteRoomExtension(String roomId, bool vote) =>
      _send('PUT', '/api/rooms/$roomId/extension-vote', body: {'vote': vote});

  static Future<Map<String, dynamic>> submitRoomSelection(
    String roomId,
    String selectedUserId,
  ) =>
      _send(
        'PUT',
        '/api/rooms/$roomId/selection',
        body: {'selectedUserId': int.parse(selectedUserId)},
      );

  static Future<Map<String, dynamic>> roomSelectionResult(String roomId) =>
      _get('/api/rooms/$roomId/selection-result');

  static Future<Map<String, dynamic>> matches() => _get('/api/matches');
  static Future<Map<String, dynamic>> matchDetail(String matchId) => _get('/api/matches/$matchId');

  static Future<List<Map<String, dynamic>>> privateMessages(
    String matchId, {
    int after = 0,
  }) async {
    final data = await _get('/api/matches/$matchId/messages', query: {'after': '$after'});
    final raw = data['messages'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<Map<String, dynamic>> sendPrivateMessage(String matchId, String body) =>
      _send('POST', '/api/matches/$matchId/messages', body: {'body': body});

  static Future<void> markMatchRead(String matchId) async =>
      _send('POST', '/api/matches/$matchId/read');

  static Future<void> unmatch(String matchId) async => _send('DELETE', '/api/matches/$matchId');

  static Future<List<Map<String, dynamic>>> blocks() async {
    final data = await _get('/api/blocks');
    final raw = data['blocked'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<void> blockUser(String userId) async => _send('POST', '/api/users/$userId/block');
  static Future<void> unblockUser(String userId) async => _send('DELETE', '/api/users/$userId/block');

  static Future<void> reportUser(
    String userId, {
    required String reason,
    String? detail,
    String? roomId,
  }) async =>
      _send(
        'POST',
        '/api/users/$userId/report',
        body: {
          'reason': reason,
          if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
          if (roomId != null && roomId.isNotEmpty) 'roomId': roomId,
        },
      );

  static Future<Map<String, dynamic>> settings() => _get('/api/me/settings');

  static Future<Map<String, dynamic>> updateSettings({
    bool? notificationsEnabled,
    bool? roomReminders,
    bool? showOnline,
    bool? preciseLocation,
    bool? vibration,
  }) =>
      _send(
        'PUT',
        '/api/me/settings',
        body: {
          if (notificationsEnabled != null) 'notificationsEnabled': notificationsEnabled,
          if (roomReminders != null) 'roomReminders': roomReminders,
          if (showOnline != null) 'showOnline': showOnline,
          if (preciseLocation != null) 'preciseLocation': preciseLocation,
          if (vibration != null) 'vibration': vibration,
        },
      );

  static Future<Map<String, dynamic>> notifications() => _get('/api/notifications');
  static Future<void> markNotificationsRead() async => _send('POST', '/api/notifications/read');
}
