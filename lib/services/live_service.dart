import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'realtime_service.dart';
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

  // Oda, kuyruk, eşleşme ve mesajlaşma canlı veri akışları yalnızca
  // Socket.IO/WebSocket üzerinden gider. HTTP burada sadece profil, ayar,
  // moderasyon ve destek gibi gerçek zamanlı olmayan işlemler için kalır.
  static Future<Map<String, dynamic>> joinRoomQueue() => RealtimeService.joinQueue();
  static Future<Map<String, dynamic>> roomQueueStatus() => RealtimeService.queueStatus();

  static Future<void> cancelRoomQueue() async {
    await RealtimeService.cancelQueue();
  }

  static Future<Map<String, dynamic>> room(String roomId) async {
    final result = await RealtimeService.joinRoom(roomId);
    final raw = result['room'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw const ApiException('Oda verisi alınamadı.');
  }

  static Future<Map<String, dynamic>> roomForceSelectionCapability(String roomId) =>
      _get('/api/rooms/$roomId/force-selection-capability');

  static Future<Map<String, dynamic>> forceRoomSelection(String roomId) =>
      _send('PUT', '/api/rooms/$roomId/force-selection');

  static Future<List<Map<String, dynamic>>> roomMessages(
    String roomId, {
    int after = 0,
  }) =>
      RealtimeService.roomMessages(roomId, after: after);

  static Future<Map<String, dynamic>> sendRoomMessage(String roomId, String body) =>
      RealtimeService.sendRoomMessage(roomId, body);

  static Future<Map<String, dynamic>> voteRoomExtension(String roomId, bool vote) =>
      RealtimeService.voteRoomExtension(roomId, vote);

  static Future<Map<String, dynamic>> submitRoomSelection(
    String roomId,
    String selectedUserId,
  ) =>
      RealtimeService.submitRoomSelection(roomId, selectedUserId);

  static Future<Map<String, dynamic>> roomSelectionResult(String roomId) =>
      _get('/api/rooms/$roomId/selection-result');

  static Future<Map<String, dynamic>> matches() => RealtimeService.listMatches();

  static Future<Map<String, dynamic>> matchDetail(String matchId) =>
      RealtimeService.joinMatch(matchId);

  static Future<List<Map<String, dynamic>>> privateMessages(
    String matchId, {
    int after = 0,
  }) =>
      RealtimeService.privateMessages(matchId, after: after);

  static Future<Map<String, dynamic>> sendPrivateMessage(String matchId, String body) =>
      RealtimeService.sendPrivateMessage(matchId, body);

  static Future<void> markMatchRead(String matchId) async {
    await RealtimeService.markMatchRead(matchId);
  }

  static Future<void> unmatch(String matchId) async {
    await _send('DELETE', '/api/matches/$matchId');
  }

  static Future<List<Map<String, dynamic>>> blocks() async {
    final data = await _get('/api/blocks');
    final raw = data['blocked'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<void> blockUser(String userId) async {
    await _send('POST', '/api/users/$userId/block');
  }

  static Future<void> unblockUser(String userId) async {
    await _send('DELETE', '/api/users/$userId/block');
  }

  static Future<void> reportUser(
    String userId, {
    required String reason,
    String? detail,
    String? roomId,
  }) async {
    await _send(
      'POST',
      '/api/users/$userId/report',
      body: {
        'reason': reason,
        if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
        if (roomId != null && roomId.isNotEmpty) 'roomId': roomId,
      },
    );
  }

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

  static Future<void> markNotificationsRead() async {
    await _send('POST', '/api/notifications/read');
  }

  static Future<Map<String, dynamic>> createSupportRequest({
    required String topic,
    required String message,
  }) =>
      _send(
        'POST',
        '/api/support',
        body: {'topic': topic, 'message': message},
      );

  static Future<List<Map<String, dynamic>>> supportRequests() async {
    final data = await _get('/api/support');
    final raw = data['requests'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
}
