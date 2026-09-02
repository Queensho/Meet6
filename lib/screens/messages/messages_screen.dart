import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/api_service.dart';
import '../../services/live_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/phone_frame.dart';
import '../home/home_screen.dart';
import '../matches/matches_screen.dart';
import '../profile/profile_screen.dart';
import 'private_chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.profileName,
    required this.preferences,
  });

  final String profileName;
  final MatchingPreferences preferences;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late MatchingPreferences preferences;
  List<Map<String, dynamic>> chats = const [];
  int unreadTotal = 0;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    preferences = widget.preferences;
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await LiveService.matches();
      final raw = data['matches'];
      if (!mounted) return;
      final all = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      setState(() {
        chats = all;
        unreadTotal = (data['unreadTotal'] as num?)?.toInt() ?? 0;
        loading = false;
        error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    }
  }

  Future<void> _openChat(Map<String, dynamic> item) async {
    final matchId = item['match_id']?.toString() ?? '';
    if (matchId.isEmpty) return;
    final rawPhotos = item['photo_urls'];
    final photo = rawPhotos is List && rawPhotos.isNotEmpty ? rawPhotos.first.toString() : '';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          matchId: matchId,
          name: item['display_name']?.toString() ?? 'Meet6',
          userId: item['user_id']?.toString() ?? '',
          photoUrl: photo,
        ),
      ),
    );
    if (mounted) _load();
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          profileName: widget.profileName,
          city: preferences.city,
          country: preferences.country,
          latitude: preferences.latitude,
          longitude: preferences.longitude,
          distanceKm: preferences.distanceKm,
          lookingFor: preferences.lookingFor,
          minAge: preferences.minAge,
          maxAge: preferences.maxAge,
          purpose: preferences.purpose,
        ),
      ),
    );
  }

  void _goMatches() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MatchesScreen(
          profileName: widget.profileName,
          preferences: preferences,
        ),
      ),
    );
  }

  void _goProfile() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          profileName: widget.profileName,
          initialPreferences: preferences,
          asRootTab: true,
          onPreferencesChanged: (value) {
            if (mounted) setState(() => preferences = value);
          },
        ),
      ),
    );
  }

  String _timeLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    if (now.year == date.year && now.month == date.month && now.day == date.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mesajlar',
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 30,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    unreadTotal > 0 ? '$unreadTotal okunmamış mesaj' : 'Özel sohbetlerin',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 43,
                              height: 43,
                              decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
                              child: const Icon(Icons.chat_bubble_rounded, color: AppColors.navy),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
                      )
                    else if (error != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(error!, style: TextStyle(color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                            ],
                          ),
                        ),
                      )
                    else if (chats.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.forum_outlined, color: AppColors.blue, size: 48),
                                const SizedBox(height: 14),
                                Text(
                                  'Henüz özel sohbet yok',
                                  style: TextStyle(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Karşılıklı bir eşleşme olduğunda sohbet burada açılır.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList.separated(
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 88,
                          endIndent: 20,
                          color: scheme.outlineVariant,
                        ),
                        itemBuilder: (context, index) {
                          final item = chats[index];
                          final photos = item['photo_urls'];
                          final photo = photos is List && photos.isNotEmpty ? photos.first.toString() : '';
                          final name = item['display_name']?.toString() ?? 'Meet6';
                          final unread = (item['unread_count'] as num?)?.toInt() ?? 0;
                          final hasMessage = item['last_message'] != null;
                          return InkWell(
                            onTap: () => _openChat(item),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                              child: Row(
                                children: [
                                  _Avatar(photo: photo, name: name),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: scheme.onSurface,
                                                  fontSize: 14.5,
                                                  fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _timeLabel(item['last_message_at'] ?? item['matched_at']),
                                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                hasMessage
                                                    ? item['last_message'].toString()
                                                    : 'Yeni eşleşme — ilk mesajı gönder.',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: unread > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
                                                  fontSize: 11.8,
                                                  fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (unread > 0) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                constraints: const BoxConstraints(minWidth: 21, minHeight: 21),
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                                decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  unread > 99 ? '99+' : '$unread',
                                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  ],
                ),
              ),
            ),
            MainBottomNav(
              selectedIndex: 2,
              unreadMessages: unreadTotal,
              onTap: (index) {
                if (index == 0) _goHome();
                if (index == 1) _goMatches();
                if (index == 3) _goProfile();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photo, required this.name});
  final String photo;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
      child: photo.isEmpty
          ? Center(
              child: Text(
                name.characters.first.toUpperCase(),
                style: const TextStyle(color: AppColors.lime, fontSize: 21, fontWeight: FontWeight.w900),
              ),
            )
          : Image.network(
              ApiService.absoluteMediaUrl(photo),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: AppColors.lime),
            ),
    );
  }
}
