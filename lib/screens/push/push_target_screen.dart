import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/api_service.dart';
import '../../services/live_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../chat/room_chat_screen.dart';
import '../matches/match_profile_detail_screen.dart';
import '../messages/private_chat_screen.dart';

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

      if (type == 'room_found' && roomId.isNotEmpty) {
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
