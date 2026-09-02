import 'package:flutter/material.dart';

import '../../models/match_profile.dart';
import '../../models/matching_preferences.dart';
import '../../services/blocked_accounts_service.dart';
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

  static const _seedMatches = [
    MatchProfile(
      name: 'Ece',
      age: 26,
      city: 'İstanbul, Türkiye',
      initial: 'E',
      bio: 'Kahve, sahil yürüyüşleri ve yeni yerler keşfetmeyi seviyorum. İyi bir sohbet her şeyi değiştirir.',
      interests: ['Kahve', 'Seyahat', 'Müzik', 'Sinema'],
      prompt: 'Benimle iyi anlaşmanın yolu...',
      promptAnswer: 'Doğal ol, bol bol gül ve kahve konusunda iddialı ol.',
      matchedAt: 'Bugün',
      isOnline: true,
    ),
    MatchProfile(
      name: 'Selin',
      age: 25,
      city: 'İstanbul, Türkiye',
      initial: 'S',
      bio: 'Hafta sonu planlarını son anda yapanlardanım. Konser, yemek ve uzun sohbet üçlüsünü severim.',
      interests: ['Müzik', 'Yemek', 'Dans', 'Seyahat'],
      prompt: 'İlk buluşmada ideal planım...',
      promptAnswer: 'Sessiz olmayan bir mekân, iyi müzik ve saatlere bakmayı unuttuğumuz bir sohbet.',
      matchedAt: '12 dk önce',
      isOnline: true,
    ),
    MatchProfile(
      name: 'Mert',
      age: 29,
      city: 'Tekirdağ, Türkiye',
      initial: 'M',
      bio: 'Spor, teknoloji ve yolculuk. Gereksiz küçük konuşmalardan çok gerçekten tanımayı seviyorum.',
      interests: ['Spor', 'Teknoloji', 'Doğa', 'Oyun'],
      prompt: 'Beni en çok güldüren şey...',
      promptAnswer: 'Kötü yapılan ama özgüvenle anlatılan şakalar.',
      matchedAt: '1 saat önce',
    ),
    MatchProfile(
      name: 'Deniz',
      age: 27,
      city: 'Tekirdağ, Türkiye',
      initial: 'D',
      bio: 'Kitapçıda saatler geçirebilirim. Yeni insanlarda en çok merak duygusunu seviyorum.',
      interests: ['Kitap', 'Kahve', 'Doğa', 'Fotoğraf'],
      prompt: 'Birlikte kesin yapmalıyız...',
      promptAnswer: 'Daha önce ikimizin de gitmediği bir yere günübirlik kaçmalıyız.',
      matchedAt: 'Dün',
    ),
  ];

  final matches = <MatchProfile>[];

  @override
  void initState() {
    super.initState();
    preferences = widget.preferences;
    matches.addAll(_seedMatches);
    _filterBlockedMatches();
  }

  Future<void> _filterBlockedMatches() async {
    final blocked = await BlockedAccountsService.load();
    if (!mounted) return;
    final names = blocked.map((account) => account.name.toLowerCase()).toSet();
    setState(() {
      matches.removeWhere((profile) => names.contains(profile.name.toLowerCase()));
    });
  }

  Future<void> _openProfile(MatchProfile profile) async {
    final blocked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MatchProfileDetailScreen(profile: profile),
      ),
    );
    if (blocked != true || !mounted) return;

    setState(() => matches.removeWhere((item) => item.name == profile.name));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${profile.name} engellendi ve eşleşmelerden kaldırıldı.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            if (!mounted) return;
            setState(() => preferences = value);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PhoneFrame(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Eşleşmeler',
                                  style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 30,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.1,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Karşılıklı seçim yaptığın kişiler',
                                  style: TextStyle(
                                    color: AppColors.muted,
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
                            decoration: const BoxDecoration(
                              color: AppColors.lime,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.lime.withOpacity(.38),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.blue,
                              size: 19,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                '${matches.length} eşleşmen var. Bir kişiye dokunarak profilini açabilirsin.',
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 11.8,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (matches.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyMatches(),
                    )
                  else
                    SliverList.separated(
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final profile = matches[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: InkWell(
                            onTap: () => _openProfile(profile),
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.94),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 66,
                                        height: 66,
                                        decoration: const BoxDecoration(
                                          color: AppColors.navy,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          profile.initial,
                                          style: const TextStyle(
                                            color: AppColors.lime,
                                            fontSize: 25,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (profile.isOnline)
                                        Positioned(
                                          right: 1,
                                          bottom: 1,
                                          child: Container(
                                            width: 15,
                                            height: 15,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF36C76C),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${profile.name}, ${profile.age}',
                                                style: const TextStyle(
                                                  color: AppColors.navy,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              profile.matchedAt,
                                              style: const TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on_outlined,
                                              color: AppColors.blue,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                profile.city,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.muted,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          profile.bio,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.navy,
                                            fontSize: 11.5,
                                            height: 1.3,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Profili gör',
                                              style: TextStyle(
                                                color: AppColors.blue,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            SizedBox(width: 2),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: AppColors.blue,
                                              size: 17,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
            MainBottomNav(
              selectedIndex: 1,
              unreadMessages: 2,
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

class _EmptyMatches extends StatelessWidget {
  const _EmptyMatches();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                color: AppColors.navy,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Görüntülenecek eşleşme yok',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Yeni bir odada karşılıklı seçim yaptığında eşleşmen burada görünür.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
