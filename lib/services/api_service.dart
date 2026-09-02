import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session_service.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthResult {
  const AuthResult({
    required this.sessionId,
    required this.userId,
    required this.profileCompleted,
  });

  final String sessionId;
  final String userId;
  final bool profileCompleted;
}

class ApiService {
  const ApiService._();

  static const baseUrl = 'https://meet6-api-185-165-46-213.nip.io';

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Map<String, String> _headers({String? sessionId}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (sessionId != null && sessionId.isNotEmpty)
          'Authorization': 'Bearer $sessionId',
      };

  static Future<void> requestOtp(String phone) async {
    final response = await http
        .post(
          _uri('/api/auth/request-code'),
          headers: _headers(),
          body: jsonEncode({'phone': phone}),
        )
        .timeout(const Duration(seconds: 15));
    _decode(response);
  }

  static Future<AuthResult> verifyOtp(String phone, String code) async {
    final response = await http
        .post(
          _uri('/api/auth/verify-code'),
          headers: _headers(),
          body: jsonEncode({'phone': phone, 'code': code}),
        )
        .timeout(const Duration(seconds: 15));
    final data = _decode(response);
    return AuthResult(
      sessionId: data['sessionId'] as String,
      userId: data['userId'] as String,
      profileCompleted: data['profileCompleted'] == true,
    );
  }

  static Future<Map<String, dynamic>> getMe({String? sessionId}) async {
    final token = sessionId ?? await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) {
      throw const ApiException('Oturum bulunamadı.');
    }
    final response = await http
        .get(_uri('/api/me'), headers: _headers(sessionId: token))
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  static Future<void> updateProfile({
    required String displayName,
    required String birthDate,
    required String gender,
    required String bio,
    required String city,
    required String country,
    required double? latitude,
    required double? longitude,
    required String profilePrompt,
    required String profileAnswer,
    required List<String> interests,
    required List<String> photoUrls,
    bool profileCompleted = true,
  }) async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null) throw const ApiException('Oturum bulunamadı.');
    final response = await http
        .put(
          _uri('/api/me/profile'),
          headers: _headers(sessionId: token),
          body: jsonEncode({
            'displayName': displayName,
            'birthDate': birthDate,
            'gender': gender,
            'bio': bio,
            'city': city,
            'country': country,
            'latitude': latitude,
            'longitude': longitude,
            'profilePrompt': profilePrompt,
            'profileAnswer': profileAnswer,
            'interests': interests,
            'photoUrls': photoUrls,
            'profileCompleted': profileCompleted,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _decode(response);
  }

  static Future<void> updatePreferences({
    required String lookingFor,
    required double minAge,
    required double maxAge,
    required int distanceKm,
    required String purpose,
  }) async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null) throw const ApiException('Oturum bulunamadı.');
    final response = await http
        .put(
          _uri('/api/me/preferences'),
          headers: _headers(sessionId: token),
          body: jsonEncode({
            'lookingFor': lookingFor,
            'minAge': minAge.round(),
            'maxAge': maxAge.round(),
            'distanceKm': distanceKm,
            'purpose': purpose,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _decode(response);
  }

  static Future<void> logout() async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null) return;
    try {
      await http
          .post(
            _uri('/api/auth/logout'),
            headers: _headers(sessionId: token),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Local logout must still work when the network is unavailable.
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // Fall through to a generic error below.
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final rawMessage = data['message'];
    final message = rawMessage is List
        ? rawMessage.join('\n')
        : rawMessage is String
            ? rawMessage
            : 'Sunucu isteği başarısız oldu.';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
