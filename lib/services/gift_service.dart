import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'session_service.dart';

class GiftService {
  const GiftService._();

  static final Random _random = Random.secure();

  static String _clientGiftId() {
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final a = _random.nextInt(1 << 31).toRadixString(36);
    final b = _random.nextInt(1 << 31).toRadixString(36);
    return 'gift-$micros-$a-$b';
  }

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

  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('${ApiService.baseUrl}$path');
    return query == null ? base : base.replace(queryParameters: query);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final raw = data['message'];
    final message = raw is List
        ? raw.join('\n')
        : raw is String
            ? raw
            : 'Hediye işlemi başarısız oldu.';
    throw ApiException(message, statusCode: response.statusCode);
  }

  static Future<Map<String, dynamic>> catalog() async {
    final response = await http
        .get(_uri('/api/gifts/catalog'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> me() async {
    final response = await http
        .get(_uri('/api/gifts/me'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> userSummary(String userId) async {
    final response = await http
        .get(_uri('/api/gifts/users/$userId'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  static Future<List<Map<String, dynamic>>> roomHistory(
    String roomId, {
    int after = 0,
  }) async {
    final response = await http
        .get(
          _uri('/api/gifts/rooms/$roomId', {'after': '$after'}),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final data = _decode(response);
    final raw = data['gifts'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<Map<String, dynamic>> sendRoomGift({
    required String roomId,
    required String recipientUserId,
    required String giftCode,
  }) async {
    final response = await http
        .post(
          _uri('/api/gifts/rooms/$roomId/send'),
          headers: await _headers(),
          body: jsonEncode({
            'recipientUserId': int.parse(recipientUserId),
            'giftCode': giftCode,
            'clientGiftId': _clientGiftId(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }
}
