import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import '../preferences/matching_preferences_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'widgets/profile_hero.dart';
import 'widgets/profile_info_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.profileName = '',
    required this.initialPreferences,
    this.onPreferencesChanged,
  });

  final String profileName;
  final MatchingPreferences initialPreferences;
  final ValueChanged<MatchingPreferences>? onPreferencesChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String name;
  int age = 28;
  String bio =
      'Yeni insanlarla tanışmayı, güzel sohbetleri ve spontane planları seviyorum.';
  List<String> interests = ['Kahve', 'Seyahat', 'Müzik', 'Spor'];
  String prompt = 'Benimle iyi anlaşmanın yolu...';
  String promptAnswer = 'İyi kahve, bol kahkaha ve açık iletişim.';
  late MatchingPreferences preferences;

  @override
  void initState() {
    super.initState();
    name = widget.profileName.trim().isEmpty
        ? 'Tayfun'
        : widget.profileName.trim();
    preferences = widget.initialPreferences;
  }

  EditProfileResult get currentProfile => EditProfileResult(
        name: name,
        age: age,
        bio: bio,
        interests: interests,
        prompt: prompt,
        promptAnswer: promptAnswer,
      );

  Future<void> _openEditProfile() async {
    final result = await Navigator.of(context).push<EditProfileResult>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(initial: currentProfile),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      name = result.name;
      age = result.age;
      bio = result.bio;
      interests = result.interests;
      prompt = result.prompt;
      promptAnswer = result.promptAnswer;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profilin güncellendi.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openMatchingPreferences() async {
    final result = await Navigator.of(context).push<MatchingPreferences>(
      MaterialPageRoute(
        builder: (_) => MatchingPreferencesScreen(initial: preferences),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => preferences = result);
    widget.onPreferencesChanged?.call(result);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Eşleşme tercihlerin güncellendi.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

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
                    ProfileHero(name: name),
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
                                TextSpan(text: name),
                                TextSpan(
                                  text: ', $age',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.blue,
                                size: 17,
                              ),
                              Text(
                                preferences.locationLabel,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text(
                                '•',
                                style: TextStyle(color: AppColors.border),
                              ),
                              const Text(
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
                              onPressed: _openEditProfile,
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
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: _openMatchingPreferences,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      color: AppColors.lime,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.tune_rounded,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Eşleşme tercihleri',
                                          style: TextStyle(
                                            color: AppColors.navy,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          preferences.compactSummary,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 11.2,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ProfileSection(
                            title: 'Hakkımda',
                            child: Text(
                              bio,
                              style: const TextStyle(
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
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final interest in interests)
                                  ProfileInterestChip(label: interest),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ProfileSection(
                            title: 'Profil sorum',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prompt,
                                  style: const TextStyle(
                                    color: AppColors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  promptAnswer,
                                  style: const TextStyle(
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
                            title: 'Profil bilgilerim',
                            child: Wrap(
                              spacing: 18,
                              runSpacing: 13,
                              children: [
                                ProfileMiniInfo(
                                  icon: Icons.cake_outlined,
                                  text: '$age yaş',
                                ),
                                ProfileMiniInfo(
                                  icon: Icons.location_on_outlined,
                                  text: preferences.locationLabel,
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
                                  Icons.shield_outlined,
                                  color: AppColors.blue,
                                  size: 22,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Mesafe ve eşleşme tercihlerin profil içeriğinden ayrıdır; oda oluşturulurken kullanılır.',
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
                onTap: _openSettings,
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
