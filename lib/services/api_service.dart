import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../models/picked_profile_photo.dart';
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

  static Future<void> Function()? beforeLogout;

  static String get baseUrl => AppConfig.apiBaseUrl;

  static Uri _uri(String path) => AppConfig.apiUri(path);

  static String absoluteMediaUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '$baseUrl${raw.startsWith('/') ? raw : '/$raw'}';
  }

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

  static Future<List<String>> uploadProfilePhotos(
    List<PickedProfilePhoto> photos,
  ) async {
    if (photos.isEmpty || photos.length > 4) {
      throw const ApiException('1 ile 4 arasında fotoğraf seçmelisin.');
    }

    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) {
      throw const ApiException('Oturum bulunamadı.');
    }

    final request = http.MultipartRequest('POST', _uri('/api/me/photos'))
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';

    for (final photo in photos) {
      if (photo.bytes.length > 8 * 1024 * 1024) {
        throw const ApiException('Her fotoğraf en fazla 8 MB olabilir.');
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'photos',
          photo.bytes,
          filename: photo.fileName,
          contentType: MediaType.parse(photo.mimeType),
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    final data = _decode(response);
    final rawUrls = data['urls'];
    if (rawUrls is! List) {
      throw const ApiException('Fotoğraf yükleme cevabı geçersiz.');
    }
    return rawUrls.map((value) => value.toString()).toList(growable: false);
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
        .timeout(const Duration(seconds: 20));
    _decode(response);
  }

  static Future<void> updateProfileLocation({
    required String city,
    required String country,
    required double latitude,
    required double longitude,
  }) async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null) throw const ApiException('Oturum bulunamadı.');
    final response = await http
        .put(
          _uri('/api/me/profile'),
          headers: _headers(sessionId: token),
          body: jsonEncode({
            'city': city,
            'country': country,
            'latitude': latitude,
            'longitude': longitude,
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

  static Future<void> deleteAccount() async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) {
      throw const ApiException('Oturum bulunamadı.');
    }
    final response = await http
        .delete(
          _uri('/api/me'),
          headers: _headers(sessionId: token),
        )
        .timeout(const Duration(seconds: 20));
    _decode(response);
  }

  static Future<void> logout() async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null) return;

    final cleanup = beforeLogout;
    if (cleanup != null) {
      try {
        await cleanup();
      } catch (_) {
        // Push token temizliği çıkışı engellememeli.
      }
    }

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
