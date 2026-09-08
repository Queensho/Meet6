import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class PartyInviteLinkService {
  PartyInviteLinkService._();

  static const _pendingKey = 'meet6_pending_party_invite_v1';
  static const _host = 'meet6.com.tr';
  static const _base = 'https://meet6.com.tr';
  static AppLinks? _appLinks;
  static StreamSubscription<Uri>? _subscription;

  static String buildInviteUrl(String code) {
    final normalized = code.trim().toUpperCase();
    return '$_base/join/$normalized';
  }

  static String inviteMessage(String code) {
    final url = buildInviteUrl(code);
    return 'Meet6\'da benimle 6 kişilik odaya katıl! 👋\n'
        'Biz 2 kişi olacağız, Meet6 diğer 4 kişiyi bulacak.\n'
        '$url';
  }

  static Future<void> initialize() async {
    final webCode = codeFromUri(Uri.base);
    if (webCode != null) await savePendingCode(webCode);

    try {
      _appLinks ??= AppLinks();
      final initial = await _appLinks!.getInitialLink();
      final initialCode = initial == null ? null : codeFromUri(initial);
      if (initialCode != null) await savePendingCode(initialCode);

      await _subscription?.cancel();
      _subscription = _appLinks!.uriLinkStream.listen((uri) {
        final code = codeFromUri(uri);
        if (code != null) unawaited(savePendingCode(code));
      });
    } catch (_) {
      // Web and unsupported platforms can still use Uri.base.
    }
  }

  static String? codeFromUri(Uri uri) {
    final queryCode = uri.queryParameters['party'] ?? uri.queryParameters['join'];
    if (queryCode != null && queryCode.trim().isNotEmpty) {
      return _normalize(queryCode);
    }

    final segments = uri.pathSegments.where((e) => e.trim().isNotEmpty).toList();
    if (segments.length >= 2 && segments[0].toLowerCase() == 'join') {
      return _normalize(segments[1]);
    }

    if (uri.scheme == 'meet6' && uri.host.toLowerCase() == 'join' && segments.isNotEmpty) {
      return _normalize(segments.first);
    }

    return null;
  }

  static String? _normalize(String raw) {
    final code = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (code.length < 4 || code.length > 12) return null;
    return code;
  }

  static Future<void> savePendingCode(String code) async {
    final normalized = _normalize(code);
    if (normalized == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, normalized);
  }

  static Future<String?> pendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalize(prefs.getString(_pendingKey) ?? '');
  }

  static Future<void> clearPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  static Future<bool> shareWhatsApp(String code) async {
    final text = Uri.encodeComponent(inviteMessage(code));
    return launchUrl(Uri.parse('https://wa.me/?text=$text'), mode: LaunchMode.externalApplication);
  }

  static Future<bool> shareSms(String code) async {
    final text = Uri.encodeComponent(inviteMessage(code));
    return launchUrl(Uri.parse('sms:?body=$text'), mode: LaunchMode.externalApplication);
  }

  static bool isMeet6InviteHost(Uri uri) => uri.host.toLowerCase() == _host;
}
