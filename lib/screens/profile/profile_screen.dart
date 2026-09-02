import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import 'widgets/profile_hero.dart';
import 'widgets/profile_info_section.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.profileName = ''});

  final String profileName;

  String get displayName => profileName.trim().isEmpty ? 'Tayfun' : profileName.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PhoneFrame(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  children: [
                    ProfileHero(name: displayName),
                    const SizedBox(height: 72),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: [
                          Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 28,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                              children: [
                                TextSpan(text: displayName),
                                const TextSpan(
                                  text: ', 28',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 7),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: AppColors.blue,
                                size: 17,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'İstanbul',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(color: AppColors.border),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Şimdi aktif',
                                style: TextStyle(
                                  color: Color(0xFF28A745),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profil düzenleme ekranı sonraki adımda bağlanacak.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text(
                                'Profili düzenle',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ProfileSection(
                            title: 'Hakkımda',
                            child: const Text(
                              'Yeni insanlarla tanışmayı, güzel sohbetleri ve spontane planları seviyorum.',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 13.5,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ProfileSection(
                            title: 'İlgi alanlarım',
                            child: const Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ProfileInterestChip(label: 'Kahve'),
                                ProfileInterestChip(label: 'Seyahat'),
                                ProfileInterestChip(label: 'Müzik'),
                                ProfileInterestChip(label: 'Spor'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ProfileSection(
                            title: 'Profil sorum',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Benimle iyi anlaşmanın yolu...',
                                  style: TextStyle(
                                    color: AppColors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'İyi kahve, bol kahkaha ve açık iletişim.',
                                  style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 14,
                                    height: 1.35,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ProfileSection(
                            title: 'Bilgilerim',
                            child: const Wrap(
                              spacing: 18,
                              runSpacing: 13,
                              children: [
                                ProfileMiniInfo(
                                  icon: Icons.cake_outlined,
                                  text: '28 yaş',
                                ),
                                ProfileMiniInfo(
                                  icon: Icons.people_outline_rounded,
                                  text: 'Herkes',
                                ),
                                ProfileMiniInfo(
                                  icon: Icons.explore_outlined,
                                  text: '25 km',
                                ),
                                ProfileMiniInfo(
                                  icon: Icons.favorite_border_rounded,
                                  text: 'Yeni insanlarla tanışma',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.lime.withOpacity(.42),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.navy.withOpacity(.08),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: AppColors.blue,
                                  size: 22,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Profilin tamamlandı. Odalarda diğer kişiler bu bilgileri görecek.',
                                    style: TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 12,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 12,
              child: _CircleAction(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: _CircleAction(
                icon: Icons.settings_outlined,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ayarlar ekranını daha sonra bağlayacağız.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.88),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 43,
          height: 43,
          child: Icon(icon, color: AppColors.navy, size: 23),
        ),
      ),
    );
  }
}
