import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

class AdminApiService {
  const AdminApiService._();

  static Future<Map<String, dynamic>> me() => _request('GET', '/api/admin/me');

  static Future<Map<String, dynamic>> dashboard({int periodDays = 7}) =>
      _request('GET', '/api/admin/dashboard?period=${periodDays == 30 ? 30 : 7}');

  static Future<Map<String, dynamic>> users({String search = '', String status = 'all', int page = 1, int limit = 20}) {
    final uri = Uri(path: '/api/admin/users', queryParameters: {'search': search, 'status': status, 'page': '$page', 'limit': '$limit'});
    return _request('GET', uri.toString());
  }

  static Future<Map<String, dynamic>> userDetail(String userId) => _request('GET', '/api/admin/users/$userId');
  static Future<Map<String, dynamic>> moderationHistory(String userId) => _request('GET', '/api/admin/users/$userId/moderation-history');

  static Future<Map<String, dynamic>> userAction(String userId, {required String action, String? reason, int? durationHours}) =>
      _request('POST', '/api/admin/users/$userId/action', body: {
        'action': action,
        if (reason != null) 'reason': reason,
        if (durationHours != null) 'durationHours': durationHours,
      });

  static Future<Map<String, dynamic>> removePhoto(String userId, String photoUrl) =>
      _request('POST', '/api/admin/users/$userId/remove-photo', body: {'photoUrl': photoUrl});

  static Future<Map<String, dynamic>> rooms({String status = 'live', int page = 1, int limit = 20}) {
    final uri = Uri(path: '/api/admin/rooms', queryParameters: {'status': status, 'page': '$page', 'limit': '$limit'});
    return _request('GET', uri.toString());
  }

  static Future<Map<String, dynamic>> roomDetail(String roomId) => _request('GET', '/api/admin/rooms/$roomId');
  static Future<Map<String, dynamic>> closeRoom(String roomId, String reason) =>
      _request('POST', '/api/admin/rooms/$roomId/close', body: {'reason': reason});
  static Future<Map<String, dynamic>> removeRoomMember(String roomId, String userId, String reason) =>
      _request('POST', '/api/admin/rooms/$roomId/members/$userId/remove', body: {'reason': reason});

  static Future<Map<String, dynamic>> matches({String status = 'all', String search = '', int page = 1, int limit = 20}) {
    final uri = Uri(path: '/api/admin/matches', queryParameters: {'status': status, 'search': search, 'page': '$page', 'limit': '$limit'});
    return _request('GET', uri.toString());
  }

  static Future<Map<String, dynamic>> matchDetail(String matchId) => _request('GET', '/api/admin/matches/$matchId');
  static Future<Map<String, dynamic>> endMatch(String matchId, String reason) =>
      _request('POST', '/api/admin/matches/$matchId/end', body: {'reason': reason});

  static Future<Map<String, dynamic>> reports({String status = 'open', String search = '', int page = 1, int limit = 20}) {
    final uri = Uri(path: '/api/admin/reports', queryParameters: {'status': status, 'search': search, 'page': '$page', 'limit': '$limit'});
    return _request('GET', uri.toString());
  }

  static Future<Map<String, dynamic>> reportDetail(String reportId) => _request('GET', '/api/admin/reports/$reportId');
  static Future<Map<String, dynamic>> reportAction(String reportId, {required String action, String? note, String? reason}) =>
      _request('POST', '/api/admin/reports/$reportId/action', body: {
        'action': action,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      });

  static Future<Map<String, dynamic>> markReportEvidence(String reportId, String evidenceId, bool keyEvidence) =>
      _request('POST', '/api/admin/reports/$reportId/evidence', body: {'messageId': evidenceId, 'keyEvidence': keyEvidence});

  static Future<Map<String, dynamic>> supportRequests({
    String status = 'open',
    String priority = 'all',
    String search = '',
    int page = 1,
    int limit = 20,
  }) {
    final uri = Uri(path: '/api/admin/support', queryParameters: {
      'status': status,
      'priority': priority,
      'search': search,
      'page': '$page',
      'limit': '$limit',
    });
    return _request('GET', uri.toString());
  }

  static Future<Map<String, dynamic>> supportRequestDetail(String requestId) =>
      _request('GET', '/api/admin/support/$requestId');

  static Future<Map<String, dynamic>> supportRequestAction(
    String requestId, {
    required String action,
    String? response,
    String? priority,
  }) =>
      _request('POST', '/api/admin/support/$requestId/action', body: {
        'action': action,
        if (response != null && response.trim().isNotEmpty) 'response': response.trim(),
        if (priority != null) 'priority': priority,
      });

  static String mediaUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${AppConfig.apiBaseUrl}${raw.startsWith('/') ? raw : '/$raw'}';
  }

  static Future<Map<String, dynamic>> _request(String method, String path, {Map<String, dynamic>? body}) async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) throw const ApiException('Admin oturumu bulunamadı.', statusCode: 401);
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final uri = AppConfig.apiUri(path);
    final response = method == 'POST'
        ? await http.post(uri, headers: headers, body: jsonEncode(body ?? const {})).timeout(const Duration(seconds: 20))
        : await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

    Map<String, dynamic> data = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final raw = data['message'];
    final message = raw is List ? raw.join('\n') : raw is String ? raw : 'Admin API isteği başarısız oldu.';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
