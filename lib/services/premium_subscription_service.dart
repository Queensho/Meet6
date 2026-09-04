import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_config.dart';
import 'api_service.dart';
import 'session_service.dart';

class PremiumStatus {
  const PremiumStatus({
    required this.premium,
    required this.status,
    required this.productId,
    required this.expiresAt,
    required this.willRenew,
  });

  final bool premium;
  final String status;
  final String? productId;
  final DateTime? expiresAt;
  final bool willRenew;

  factory PremiumStatus.fromJson(Map<String, dynamic> json) {
    final rawSubscription = json['subscription'];
    final subscription = rawSubscription is Map
        ? Map<String, dynamic>.from(rawSubscription)
        : const <String, dynamic>{};
    final rawExpiry = subscription['expiresAt']?.toString();
    return PremiumStatus(
      premium: json['premium'] == true,
      status: subscription['status']?.toString() ?? 'inactive',
      productId: subscription['productId']?.toString(),
      expiresAt: rawExpiry == null ? null : DateTime.tryParse(rawExpiry),
      willRenew: subscription['willRenew'] == true,
    );
  }
}

class PremiumSubscriptionService {
  const PremiumSubscriptionService._();

  static Future<Map<String, dynamic>> _authorizedRequest(
    String path, {
    String method = 'GET',
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
    final response = method == 'POST'
        ? await http.post(uri, headers: headers).timeout(const Duration(seconds: 20))
        : await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

    final decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final raw = body['message'];
      final message = raw is List
          ? raw.join('\n')
          : raw?.toString() ?? 'Premium bilgisi alınamadı.';
      throw ApiException(message);
    }
    return body;
  }

  static Future<PremiumStatus> status() async {
    final body = await _authorizedRequest('/api/billing/me');
    return PremiumStatus.fromJson(body);
  }

  static Future<PremiumStatus> refreshBackend() async {
    final body = await _authorizedRequest('/api/billing/me/refresh', method: 'POST');
    return PremiumStatus.fromJson(body);
  }

  static Future<void> configurePurchases() async {
    if (kIsWeb) {
      throw const ApiException('Premium satın alma bu ekranda yalnız mobil uygulamada kullanılabilir.');
    }

    final userId = await SessionService.loadAuthUserId();
    if (userId == null || userId.isEmpty) {
      throw const ApiException('Premium için aktif kullanıcı oturumu gerekli.');
    }

    final apiKey = Platform.isAndroid
        ? AppConfig.revenueCatAndroidApiKey.trim()
        : Platform.isIOS
            ? AppConfig.revenueCatIosApiKey.trim()
            : '';
    if (apiKey.isEmpty) {
      throw const ApiException('RevenueCat mağaza anahtarı bu build için yapılandırılmadı.');
    }

    if (await Purchases.isConfigured) {
      final currentId = await Purchases.appUserID;
      if (currentId != userId) {
        await Purchases.logIn(userId);
      }
      return;
    }

    final configuration = PurchasesConfiguration(apiKey)..appUserID = userId;
    await Purchases.configure(configuration);
  }

  static Future<List<Package>> packages() async {
    await configurePurchases();
    final offerings = await Purchases.getOfferings();
    return offerings.current?.availablePackages ?? const <Package>[];
  }

  static Future<PremiumStatus> purchase(Package package) async {
    await configurePurchases();
    await Purchases.purchase(PurchaseParams.package(package));
    return refreshBackend();
  }

  static Future<PremiumStatus> restore() async {
    await configurePurchases();
    await Purchases.restorePurchases();
    return refreshBackend();
  }
}
