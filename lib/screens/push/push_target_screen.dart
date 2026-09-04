import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/api_service.dart';
import '../../services/live_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../chat/room_chat_screen.dart';
import '../matches/match_profile_detail_screen.dart';
import '../messages/private_chat_screen.dart';
import '../profile/settings/help_support_screen.dart';

class PushTargetScreen extends StatefulWidget {
  const PushTargetScreen({
    super.key,
    required this.data,
  });

  final Map<String, dynamic> data;

  @override
  State<PushTargetScreen> createState() => _PushTargetScreenState();
}

class _PushTargetScreenState extends State<PushTargetScreen> {
  String? error;
  String? noticeTitle;
  String? noticeBody;
  IconData noticeIcon = Icons.notifications_rounded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    try {
      final type = widget.data['type']?.toString() ?? '';
      final roomId = widget.data['roomId']?.toString() ?? '';
      final matchId = widget.data['matchId']?.toString() ?? '';

      if ((type == 'room_found' || type == 'room_message') &&
          roomId.isNotEmpty) {
        await LiveService.room(roomId);
        final saved = await SessionService.loadProfile();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RoomChatScreen(
              roomId: roomId,
              profileName: saved?.profileName ?? '',
            ),
          ),
        );
        return;
      }

      if (type == 'match' && matchId.isNotEmpty) {
        final saved = await SessionService.loadProfile();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MatchProfileDetailScreen(
              matchId: matchId,
              profileName: saved?.profileName ?? '',
              preferences: _preferences(saved),
            ),
          ),
        );
        return;
      }

      if ((type == 'message' || type == 'private_message') &&
          matchId.isNotEmpty) {
        final detail = await LiveService.matchDetail(matchId);
        final raw = detail['profile'];
        final profile = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        final photos = profile['photo_urls'];
        final photo = photos is List && photos.isNotEmpty
            ? photos.first.toString()
            : '';
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PrivateChatScreen(
              matchId: matchId,
              name: profile['display_name']?.toString() ?? 'Meet6',
              userId: profile['user_id']?.toString() ?? '',
              photoUrl: photo,
              isOnline: profile['online'] == true,
            ),
          ),
        );
        return;
      }

      if (type == 'support_reply') {
        final requestId = widget.data['supportRequestId']?.toString();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HelpSupportScreen(focusRequestId: requestId),
          ),
        );
        return;
      }

      if (type == 'moderation_warning' ||
          type == 'moderation_ban' ||
          type == 'moderation_unban' ||
          type == 'room_closed' ||
          type == 'room_removed' ||
          type == 'report_update') {
        if (!mounted) return;
        setState(() {
          noticeTitle = widget.data['title']?.toString().trim().isNotEmpty == true
              ? widget.data['title'].toString()
              : _fallbackNoticeTitle(type);
          noticeBody = widget.data['body']?.toString() ?? '';
          noticeIcon = _noticeIcon(type);
          error = null;
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Bildirim bağlantısı açılamadı: $e');
    }
  }

  String _fallbackNoticeTitle(String type) {
    switch (type) {
      case 'moderation_warning':
        return 'Meet6 uyarısı';
      case 'moderation_ban':
        return 'Hesap işlemi';
      case 'moderation_unban':
        return 'Meet6 banı kaldırıldı';
      case 'room_closed':
        return 'Meet6 odası kapatıldı';
      case 'room_removed':
        return 'Meet6 odasından çıkarıldın';
      case 'report_update':
        return 'Şikâyetin incelendi';
      default:
        return 'Meet6 bildirimi';
    }
  }

  IconData _noticeIcon(String type) {
    switch (type) {
      case 'moderation_warning':
        return Icons.warning_amber_rounded;
      case 'moderation_ban':
      case 'room_removed':
        return Icons.block_rounded;
      case 'moderation_unban':
        return Icons.verified_user_outlined;
      case 'room_closed':
        return Icons.meeting_room_outlined;
      case 'report_update':
        return Icons.shield_outlined;
      default:
        return Icons.notifications_rounded;
    }
  }

  MatchingPreferences _preferences(SavedSession? saved) {
    return MatchingPreferences(
      lookingFor: saved?.lookingFor ?? 'Herkes',
      minAge: saved?.minAge ?? 20,
      maxAge: saved?.maxAge ?? 35,
      distanceKm: saved?.distanceKm ?? 25,
      purpose: saved?.purpose ?? 'Yeni insanlarla tanışma',
      city: saved?.city ?? '',
      country: saved?.country ?? '',
      latitude: saved?.latitude,
      longitude: saved?.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (noticeTitle != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Meet6 bildirimi')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: const BoxDecoration(
                        color: AppColors.lime,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(noticeIcon, color: AppColors.navy, size: 31),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      noticeTitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((noticeBody ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        noticeBody!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Tamam'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: error == null
              ? const CircularProgressIndicator(color: AppColors.lime)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        color: scheme.onSurfaceVariant,
                        size: 42,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _resolve,
                        child: const Text('Tekrar dene'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Ana sayfaya dön'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
