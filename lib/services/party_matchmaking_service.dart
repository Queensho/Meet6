import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'api_service.dart';
import 'session_service.dart';

class PartyMatchmakingService {
  const PartyMatchmakingService._();

  static const _partnerKey = 'meet6_active_party_partner_user_id';
  static const _roomKey = 'meet6_active_party_room_id';

  static Future<void> _rememberPartner(Map<String, dynamic> result) async {
    final prefs = await SharedPreferences.getInstance();
    final state = result['state']?.toString() ?? '';
    final rawParty = result['party'];
    if (state == 'idle' || rawParty is! Map) {
      await clearActivePartner();
      return;
    }

    final party = Map<String, dynamic>.from(rawParty);
    final myId = await SessionService.loadAuthUserId();
    final ownerId = party['ownerUserId']?.toString() ?? '';
    final guestId = party['guestUserId']?.toString() ?? '';
    String partnerId = '';
    if (myId != null && myId == ownerId) {
      partnerId = guestId;
    } else if (myId != null && myId == guestId) {
      partnerId = ownerId;
    }

    if (partnerId.isEmpty || partnerId == 'null') {
      await prefs.remove(_partnerKey);
    } else {
      await prefs.setString(_partnerKey, partnerId);
    }

    final rawRoom = result['room'];
    final roomId = rawRoom is Map ? rawRoom['id']?.toString().trim() ?? '' : '';
    if (state == 'room' && roomId.isNotEmpty && roomId != 'null') {
      await prefs.setString(_roomKey, roomId);
    }
  }

  static Future<String?> loadActivePartnerUserId({String? roomId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (roomId != null && roomId.isNotEmpty) {
      final storedRoomId = prefs.getString(_roomKey)?.trim();
      if (storedRoomId == null || storedRoomId != roomId) return null;
    }
    final value = prefs.getString(_partnerKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> clearActivePartner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_partnerKey);
    await prefs.remove(_roomKey);
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
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
      throw const ApiException('İstek tamamlanamadı.');
    }

    final decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final result = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final raw = result['message'];
      throw ApiException(raw is List ? raw.join('\n') : raw?.toString() ?? 'İstek tamamlanamadı.');
    }
    await _rememberPartner(result);
    return result;
  }

  static Future<Map<String, dynamic>> create({
    required String roomMode,
    required int roomDurationMinutes,
    String? gameKey,
  }) {
    return _request(
      'POST',
      '/api/rooms/party',
      body: {
        'roomMode': roomMode,
        'roomDurationMinutes': roomDurationMinutes,
        if (gameKey != null) 'gameKey': gameKey,
      },
    );
  }

  static Future<Map<String, dynamic>> accept(String code) {
    return _request(
      'POST',
      '/api/rooms/party/accept',
      body: {'code': code.trim().toUpperCase()},
    );
  }

  static Future<Map<String, dynamic>> search(String code) {
    return _request(
      'POST',
      '/api/rooms/party/search',
      body: {'code': code.trim().toUpperCase()},
    );
  }

  static Future<Map<String, dynamic>> status(String code) {
    return _request(
      'GET',
      '/api/rooms/party?code=${Uri.encodeQueryComponent(code.trim().toUpperCase())}',
    );
  }

  static Future<Map<String, dynamic>> cancel(String code) async {
    final result = await _request(
      'DELETE',
      '/api/rooms/party?code=${Uri.encodeQueryComponent(code.trim().toUpperCase())}',
    );
    await clearActivePartner();
    return result;
  }
}
