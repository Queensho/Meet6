import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/live_service.dart';
import '../services/observability_service.dart';
import '../services/push_notification_service.dart';
import '../theme/app_colors.dart';

enum _NotificationPromptAction { enable, settings, later }

class NotificationPermissionOnboarding {
  const NotificationPermissionOnboarding._();

  static const _nextPromptAtKey = 'notification_permission_next_prompt_at_v1';
  static bool _showing = false;

  static Future<bool> _productNotificationsEnabled() async {
    try {
      final data = await LiveService.settings();
      final raw = data['settings'];
      if (raw is! Map) return true;
      final values = Map<String, dynamic>.from(raw);
      return values['notifications_enabled'] != false;
    } catch (_) {
      // If settings cannot be loaded, do not block the permission education flow.
      return true;
    }
  }

  static Future<bool> _canPromptNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = prefs.getInt(_nextPromptAtKey) ?? 0;
      return DateTime.now().millisecondsSinceEpoch >= next;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _snooze(Duration duration) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _nextPromptAtKey,
        DateTime.now().add(duration).millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  static Future<void> _clearSnooze() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_nextPromptAtKey);
    } catch (_) {}
  }

  static String _analyticsStatus(NotificationPermissionState state) {
    switch (state) {
      case NotificationPermissionState.unsupported:
        return 'unsupported';
      case NotificationPermissionState.notDetermined:
        return 'not_determined';
      case NotificationPermissionState.denied:
        return 'denied';
      case NotificationPermissionState.authorized:
        return 'authorized';
      case NotificationPermissionState.provisional:
        return 'provisional';
    }
  }

  static Future<void> maybeShow(BuildContext context) async {
    if (_showing || !PushNotificationService.supportedPlatform) return;
    if (!await _productNotificationsEnabled()) return;

    final state = await PushNotificationService.permissionState();
    if (state.enabled || state == NotificationPermissionState.unsupported) {
      await _clearSnooze();
      return;
    }
    if (!await _canPromptNow()) return;
    if (!context.mounted) return;

    _showing = true;
    try {
      await ObservabilityService.logEvent(
        'notification_permission_prompt_shown',
        parameters: {'status': _analyticsStatus(state)},
      );

      final action = await showModalBottomSheet<_NotificationPromptAction>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .45),
        builder: (_) => _NotificationPermissionSheet(state: state),
      );

      if (action == null || action == _NotificationPromptAction.later) {
        await _snooze(
          state == NotificationPermissionState.denied
              ? const Duration(days: 7)
              : const Duration(days: 3),
        );
        await ObservabilityService.logEvent(
          'notification_permission_prompt_later',
          parameters: {'status': _analyticsStatus(state)},
        );
        return;
      }

      if (action == _NotificationPromptAction.settings) {
        final opened = await PushNotificationService.openSystemNotificationSettings();
        if (opened) {
          await ObservabilityService.logEvent('notification_settings_opened');
        }
        await _snooze(const Duration(days: 7));
        return;
      }

      final requested = await PushNotificationService.requestPermission();
      if (requested.enabled) {
        await _clearSnooze();
        await ObservabilityService.logEvent(
          'notification_permission_enabled',
          parameters: {'status': _analyticsStatus(requested)},
        );
        return;
      }

      await ObservabilityService.logEvent(
        'notification_permission_denied',
        parameters: {'status': _analyticsStatus(requested)},
      );
      await _snooze(const Duration(days: 7));

      if (!context.mounted || requested != NotificationPermissionState.denied) return;
      final deniedAction = await showModalBottomSheet<_NotificationPromptAction>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .45),
        builder: (_) => const _NotificationPermissionSheet(
          state: NotificationPermissionState.denied,
        ),
      );
      if (deniedAction == _NotificationPromptAction.settings) {
        final opened = await PushNotificationService.openSystemNotificationSettings();
        if (opened) {
          await ObservabilityService.logEvent('notification_settings_opened');
        }
      }
    } finally {
      _showing = false;
    }
  }
}

class _NotificationPermissionSheet extends StatelessWidget {
  const _NotificationPermissionSheet({required this.state});

  final NotificationPermissionState state;

  @override
  Widget build(BuildContext context) {
    final denied = state == NotificationPermissionState.denied;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.navy,
                    size: 27,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(_NotificationPromptAction.later),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              denied
                  ? 'Bildirim izni kapalı'
                  : 'Mesajlarını ve oda davetlerini kaçırma',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                height: 1.04,
                fontWeight: FontWeight.w900,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              denied
                  ? 'Telefon ayarlarında Meet6 bildirimleri kapalı. Yeni mesaj, eşleşme ve oda bildirimlerini alabilmek için izni açabilirsin.'
                  : 'Odan bulunduğunda, yeni bir eşleşme olduğunda veya mesaj geldiğinde sana haber verelim.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const _BenefitRow(
              icon: Icons.chat_bubble_outline_rounded,
              text: 'Yeni mesajları zamanında gör',
            ),
            const SizedBox(height: 10),
            const _BenefitRow(
              icon: Icons.groups_2_outlined,
              text: 'Oda bulunduğunda haberdar ol',
            ),
            const SizedBox(height: 10),
            const _BenefitRow(
              icon: Icons.favorite_border_rounded,
              text: 'Yeni eşleşmeleri kaçırma',
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  denied
                      ? _NotificationPromptAction.settings
                      : _NotificationPromptAction.enable,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: AppColors.lime,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  denied ? 'Sistem ayarlarını aç' : 'Bildirimleri aç',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(_NotificationPromptAction.later),
                child: const Text(
                  'Şimdi değil',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.lime.withValues(alpha: .23),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.navy, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13.5,
              fontWeight: FontWeight.w750,
            ),
          ),
        ),
      ],
    );
  }
}
