import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_service.dart';
import 'observability_service.dart';

class PasswordAuthService {
  const PasswordAuthService._();

  static Future<AuthResult> Function({
    required String phone,
    required String password,
  })? debugRegisterOverride;

  static Future<AuthResult> Function({
    required String phone,
    required String password,
  })? debugLoginOverride;

  static void debugResetTestHooks() {
    debugRegisterOverride = null;
    debugLoginOverride = null;
  }

  static Future<AuthResult> register({
    required String phone,
    required String password,
  }) async {
    final fake = debugRegisterOverride;
    if (fake != null) {
      return fake(phone: phone, password: password);
    }

    final response = await http
        .post(
          AppConfig.apiUri('/api/auth/register'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'phone': phone, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    return _decodeAuth(response, registration: true);
  }

  static Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final fake = debugLoginOverride;
    if (fake != null) {
      return fake(phone: phone, password: password);
    }

    final response = await http
        .post(
          AppConfig.apiUri('/api/auth/login'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'phone': phone, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    return _decodeAuth(response, registration: false);
  }

  static Future<AuthResult> _decodeAuth(
    http.Response response, {
    required bool registration,
  }) async {
    Map<String, dynamic> data = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawMessage = data['message'];
      final message = rawMessage is List
          ? rawMessage.join('\n')
          : rawMessage is String
              ? rawMessage
              : 'Giriş isteği başarısız oldu.';
      throw ApiException(message, statusCode: response.statusCode);
    }

    final result = AuthResult(
      sessionId: data['sessionId']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      isNewUser: data['isNewUser'] == true,
      profileCompleted: data['profileCompleted'] == true,
    );
    if (result.sessionId.isEmpty || result.userId.isEmpty) {
      throw const ApiException('Sunucu oturum bilgisi döndürmedi.');
    }

    await ObservabilityService.setUserId(result.userId);
    if (registration || result.isNewUser) {
      await ObservabilityService.registrationCompleted(result.userId);
    }
    return result;
  }
}
