import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_service.dart';
import 'mini_game_selection_service.dart';
import 'session_service.dart';

class RoomQueueApiService {
  const RoomQueueApiService._();

  static Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Object? body,
    String fallbackMessage = 'İstek tamamlanamadı.',
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
      throw ApiException(fallbackMessage);
    }

    final decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final result = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final raw = result['message'];
      final message = raw is List
          ? raw.join('\n')
          : raw?.toString() ?? fallbackMessage;
      throw ApiException(message);
    }
    return result;
  }

  static Future<Map<String, dynamic>> joinQueue({
    int roomDurationMinutes = 15,
  }) {
    return _requestJson(
      'POST',
      '/api/rooms/queue',
      body: {'roomDurationMinutes': roomDurationMinutes},
      fallbackMessage: 'Oda araması başlatılamadı.',
    );
  }

  static Future<Map<String, dynamic>> createGameTestRoom({
    String? gameKey,
  }) {
    final selectedGameKey = gameKey ?? MiniGameSelectionService.selectedGameKey;
    if (selectedGameKey == 'tabu') {
      return joinTabuQueue();
    }
    return joinMiniGameQueue(gameKey: selectedGameKey);
  }

  static Future<Map<String, dynamic>> joinMiniGameQueue({String? gameKey}) {
    final selectedGameKey = gameKey ?? MiniGameSelectionService.selectedGameKey;
    return _requestJson(
      'POST',
      '/api/rooms/mini-game/queue',
      body: {'gameKey': selectedGameKey},
      fallbackMessage: 'Mini oyun oyuncu araması başlatılamadı.',
    );
  }

  static Future<Map<String, dynamic>> miniGameQueueStatus({String? gameKey}) {
    final selectedGameKey = gameKey ?? MiniGameSelectionService.selectedGameKey;
    return _requestJson(
      'GET',
      '/api/rooms/mini-game/queue?gameKey=${Uri.encodeQueryComponent(selectedGameKey)}',
      fallbackMessage: 'Mini oyun sıra durumu alınamadı.',
    );
  }

  static Future<Map<String, dynamic>> cancelMiniGameQueue() {
    return _requestJson(
      'DELETE',
      '/api/rooms/mini-game/queue',
      fallbackMessage: 'Mini oyun araması iptal edilemedi.',
    );
  }

  static Future<Map<String, dynamic>> joinTabuQueue() {
    return _requestJson(
      'POST',
      '/api/rooms/tabu/queue',
      fallbackMessage: 'Tabu oyuncu araması başlatılamadı.',
    );
  }

  static Future<Map<String, dynamic>> tabuQueueStatus() {
    return _requestJson(
      'GET',
      '/api/rooms/tabu/queue',
      fallbackMessage: 'Tabu sıra durumu alınamadı.',
    );
  }

  static Future<Map<String, dynamic>> cancelTabuQueue() {
    return _requestJson(
      'DELETE',
      '/api/rooms/tabu/queue',
      fallbackMessage: 'Tabu araması iptal edilemedi.',
    );
  }
}
