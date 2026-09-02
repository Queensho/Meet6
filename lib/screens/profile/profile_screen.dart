import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'widgets/profile_hero.dart';
import 'widgets/profile_info_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.profileName = '',
    this.initialCity = '',
    this.initialCountry = '',
    this.initialLatitude,
    this.initialLongitude,
    this.initialDistanceKm = 25,
  });

  final String profileName;
  final String initialCity;
  final String initialCountry;
  final double? initialLatitude;
  final double? initialLongitude;
  final int initialDistanceKm;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String name;
  int age = 28;
  late String city;
  late String country;
  late double? latitude;
  late double? longitude;
  String bio = 'Yeni insanlarla tanışmayı, güzel sohbetleri ve spontane planları seviyorum.';
  List<String> interests = ['Kahve', 'Seyahat', 'Müzik', 'Spor'];
  String prompt = 'Benimle iyi anlaşmanın yolu...';
  String promptAnswer = 'İyi kahve, bol kahkaha ve açık iletişim.';
  String lookingFor = 'Herkes';
  late int distanceKm;
  String purpose = 'Yeni insanlarla tanışma';

  String get locationLabel {
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (city.isNotEmpty) return city;
    if (country.isNotEmpty) return country;
    return latitude != null && longitude != null ? 'Konum alındı' : 'Konum yok';
  }

  @override
  void initState() {
    super.initState();
    name = widget.profileName.trim().isEmpty ? 'Tayfun' : widget.profileName.trim();
    city = widget.initialCity;
    country = widget.initialCountry;
    latitude = widget.initialLatitude;
    longitude = widget.initialLongitude;
    distanceKm = widget.initialDistanceKm;
  }

  EditProfileResult get currentProfile => EditProfileResult(
        name: name,
        age: age,
        city: city,
        country: country,
        latitude: latitude,
        longitude: longitude,
        bio: bio,
        interests: interests,
        prompt: prompt,
        promptAnswer: promptAnswer,
        lookingFor: lookingFor,
        distanceKm: distanceKm,
        purpose: purpose,
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
      city = result.city;
      country = result.country;
      latitude = result.latitude;
      longitude = result.longitude;
      bio = result.bio;
      interests = result.interests;
      prompt = result.prompt;
      promptAnswer = result.promptAnswer;
      lookingFor = result.lookingFor;
      distanceKm = result.distanceKm;
      purpose = result.purpose;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profilin güncellendi.'),
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
                                  style: const TextStyle(fontWeight: FontWeight.w700),
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
                                locationLabel,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text('•', style: TextStyle(color: AppColors.border)),
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
                            title: 'Bilgilerim',
                            child: Wrap(
                              spacing: 18,
                              runSpacing: 13,
                              children: [
                                ProfileMiniInfo(
                                  icon: Icons.cake_outlined,
                                  text: '$age yaş',
                                ),
                                ProfileMiniInfo(
                                  icon: Icons.people_outline_rounded,
                                  text: lookingFor,
                                ),
                                ProfileMiniInfo(
                                  icon: Icons.my_location_rounded,
                                  text: distanceKm == 100
                                      ? 'Mesafe fark etmez'
                                      : '$distanceKm km',
                                ),
                                ProfileMiniInfo(
                                  icon: Icons.favorite_border_rounded,
                                  text: purpose,
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
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.my_location_rounded,
                                  color: AppColors.blue,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '$locationLabel merkez alınarak ${distanceKm == 100 ? 'mesafe sınırı olmadan' : '$distanceKm km çevrede'} oda eşleştirmesi yapılır.',
                                    style: const TextStyle(
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
