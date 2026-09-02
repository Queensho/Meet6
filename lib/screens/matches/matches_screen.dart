import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/api_service.dart';
import '../../services/live_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/phone_frame.dart';
import '../home/home_screen.dart';
import '../messages/messages_screen.dart';
import '../profile/profile_screen.dart';
import 'match_profile_detail_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({
    super.key,
    required this.profileName,
    required this.preferences,
  });

  final String profileName;
  final MatchingPreferences preferences;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  late MatchingPreferences preferences;
  List<Map<String, dynamic>> matches = const [];
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
      setState(() {
        matches = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : const [];
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

  void _goMessages() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
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

  Future<void> _open(Map<String, dynamic> item) async {
    final matchId = item['match_id']?.toString() ?? '';
    if (matchId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchProfileDetailScreen(
          matchId: matchId,
          profileName: widget.profileName,
          preferences: preferences,
        ),
      ),
    );
    if (mounted) _load();
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
                                    'Eşleşmeler',
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
                                    'Karşılıklı seçim yaptığın kişiler',
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
                              child: const Icon(Icons.favorite_rounded, color: AppColors.navy),
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
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 12),
                                FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (matches.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 78,
                                  height: 78,
                                  decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
                                  child: const Icon(Icons.favorite_border_rounded, color: AppColors.navy, size: 34),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz eşleşmen yok',
                                  style: TextStyle(color: scheme.onSurface, fontSize: 19, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Oda sonunda karşılıklı seçim yaptığınızda burada görünecek.',
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
                        itemCount: matches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final item = matches[index];
                          final photos = item['photo_urls'];
                          final photo = photos is List && photos.isNotEmpty ? photos.first.toString() : '';
                          final name = item['display_name']?.toString() ?? 'Meet6';
                          final age = (item['age'] as num?)?.toInt();
                          final city = item['city']?.toString() ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: InkWell(
                              onTap: () => _open(item),
                              borderRadius: BorderRadius.circular(21),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(21),
                                  border: Border.all(color: scheme.outlineVariant),
                                ),
                                child: Row(
                                  children: [
                                    _Avatar(photo: photo, name: name, size: 68),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            age == null ? name : '$name, $age',
                                            style: TextStyle(color: scheme.onSurface, fontSize: 15.5, fontWeight: FontWeight.w900),
                                          ),
                                          if (city.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(city, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5, fontWeight: FontWeight.w700)),
                                          ],
                                          const SizedBox(height: 6),
                                          Text(
                                            item['last_message']?.toString() ?? 'Yeni eşleşme — ilk mesajı gönder.',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 22)),
                  ],
                ),
              ),
            ),
            MainBottomNav(
              selectedIndex: 1,
              unreadMessages: unreadTotal,
              onTap: (index) {
                if (index == 0) _goHome();
                if (index == 2) _goMessages();
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
  const _Avatar({required this.photo, required this.name, required this.size});
  final String photo;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
      child: photo.isEmpty
          ? Center(
              child: Text(
                name.characters.first.toUpperCase(),
                style: const TextStyle(color: AppColors.lime, fontSize: 24, fontWeight: FontWeight.w900),
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
