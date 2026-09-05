import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';

import 'api_service.dart';
import 'premium_subscription_service.dart';
import 'session_service.dart';

class CoinPackOption {
  const CoinPackOption({
    required this.productId,
    required this.coinAmount,
    required this.package,
  });

  final String productId;
  final int coinAmount;
  final Package package;

  String get priceText => package.storeProduct.priceString;
}

class CoinStoreSnapshot {
  const CoinStoreSnapshot({
    required this.coinBalance,
    required this.options,
  });

  final int coinBalance;
  final List<CoinPackOption> options;
}

class CoinStoreService {
  const CoinStoreService._();

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

  static Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = const {};
    if (response.body.trim().isNotEmpty) {
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map) body = Map<String, dynamic>.from(raw);
      } catch (_) {}
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final raw = body['message'];
    final message = raw is List
        ? raw.join('\n')
        : raw?.toString() ?? 'Jeton mağazası işlemi başarısız oldu.';
    throw ApiException(message, statusCode: response.statusCode);
  }

  static Future<Map<String, dynamic>> _backendPacks() async {
    final response = await http
        .get(
          Uri.parse('${ApiService.baseUrl}/api/coins/packs'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> sync() async {
    final response = await http
        .post(
          Uri.parse('${ApiService.baseUrl}/api/coins/sync'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 25));
    return _decode(response);
  }

  static Future<CoinStoreSnapshot> load() async {
    final backend = await _backendPacks();
    final rawProducts = backend['products'];
    final products = rawProducts is List
        ? rawProducts
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    await PremiumSubscriptionService.configurePurchases();
    final offerings = await Purchases.getOfferings();
    final packagesByProduct = <String, Package>{};
    for (final offering in offerings.all.values) {
      for (final package in offering.availablePackages) {
        packagesByProduct[package.storeProduct.identifier] = package;
      }
    }

    final options = <CoinPackOption>[];
    for (final product in products) {
      final productId = product['productId']?.toString() ?? '';
      final package = packagesByProduct[productId];
      if (productId.isEmpty || package == null) continue;
      options.add(
        CoinPackOption(
          productId: productId,
          coinAmount: (product['coinAmount'] as num?)?.toInt() ?? 0,
          package: package,
        ),
      );
    }

    return CoinStoreSnapshot(
      coinBalance: (backend['coinBalance'] as num?)?.toInt() ?? 0,
      options: options,
    );
  }

  static Future<int> purchase(CoinPackOption option) async {
    await PremiumSubscriptionService.configurePurchases();
    await Purchases.purchase(PurchaseParams.package(option.package));
    final synced = await sync();
    return (synced['coinBalance'] as num?)?.toInt() ?? 0;
  }
}
