import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BlockedAccount {
  const BlockedAccount({
    required this.name,
    required this.initial,
  });

  final String name;
  final String initial;

  Map<String, dynamic> toJson() => {
        'name': name,
        'initial': initial,
      };

  factory BlockedAccount.fromJson(Map<String, dynamic> json) {
    return BlockedAccount(
      name: (json['name'] as String? ?? '').trim(),
      initial: (json['initial'] as String? ?? '').trim(),
    );
  }
}

class BlockedAccountsService {
  const BlockedAccountsService._();

  static const _key = 'meet6_blocked_accounts';

  static Future<List<BlockedAccount>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];

    final result = <BlockedAccount>[];
    for (final value in raw) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map<String, dynamic>) continue;
        final account = BlockedAccount.fromJson(decoded);
        if (account.name.isNotEmpty) result.add(account);
      } catch (_) {
        // Ignore malformed local prototype data.
      }
    }
    return result;
  }

  static Future<bool> isBlocked(String name) async {
    final blocked = await load();
    return blocked.any(
      (account) => account.name.toLowerCase() == name.trim().toLowerCase(),
    );
  }

  static Future<void> block({
    required String name,
    required String initial,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;

    final current = await load();
    if (current.any(
      (account) => account.name.toLowerCase() == normalizedName.toLowerCase(),
    )) {
      return;
    }

    final updated = [
      ...current,
      BlockedAccount(name: normalizedName, initial: initial.trim()),
    ];
    await _save(updated);
  }

  static Future<void> unblock(String name) async {
    final current = await load();
    final normalizedName = name.trim().toLowerCase();
    final updated = current
        .where((account) => account.name.toLowerCase() != normalizedName)
        .toList();
    await _save(updated);
  }

  static Future<void> _save(List<BlockedAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      accounts.map((account) => jsonEncode(account.toJson())).toList(),
    );
  }
}
