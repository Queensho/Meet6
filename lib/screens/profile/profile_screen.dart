import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../models/server_profile.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/phone_frame.dart';
import '../home/home_screen.dart';
import '../matches/matches_screen.dart';
import '../messages/messages_screen.dart';
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
    this.asRootTab = false,
  });

  final String profileName;
  final MatchingPreferences initialPreferences;
  final ValueChanged<MatchingPreferences>? onPreferencesChanged;
  final bool asRootTab;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String name;
  late MatchingPreferences preferences;
  ServerProfile? profile;
  bool loadingProfile = true;
  String? profileError;

  @override
  void initState() {
    super.initState();
    name = widget.profileName.trim();
    preferences = widget.initialPreferences;
    _loadProfile();
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        loadingProfile = true;
        profileError = null;
      });
    }
    try {
      final response = await ApiService.getMe();
      final raw = response['user'];
      if (raw is! Map) {
        throw const ApiException('Profil sunucudan alınamadı.');
      }
      final loaded = ServerProfile.fromUser(Map<String, dynamic>.from(raw));
      if (!mounted) return;
      setState(() {
        profile = loaded;
        name = loaded.name;
        preferences = loaded.preferences;
        loadingProfile = false;
        profileError = null;
      });
      widget.onPreferencesChanged?.call(loaded.preferences);
      await _cacheProfile(loaded);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        loadingProfile = false;
        profileError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingProfile = false;
        profileError = 'Profil sunucudan yüklenemedi.';
      });
    }
  }

  Future<void> _cacheProfile(ServerProfile value) {
    return SessionService.saveProfile(
      profileName: value.name,
      city: value.city,
      country: value.country,
      latitude: value.latitude,
      longitude: value.longitude,
      distanceKm: value.distanceKm,
      lookingFor: value.lookingFor,
      minAge: value.minAge,
      maxAge: value.maxAge,
      purpose: value.purpose,
    );
  }

  Future<void> _openEditProfile() async {
    var current = profile;
    if (current == null) {
      await _loadProfile();
      current = profile;
    }
    if (current == null || !mounted) return;

    final result = await Navigator.of(context).push<ServerProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(initial: current!),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      profile = result;
      name = result.name;
      preferences = result.preferences;
    });
    await _cacheProfile(result);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profilin sunucuda güncellendi.'),
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
    await _loadProfile(silent: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Eşleşme tercihlerin sunucuda güncellendi.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          profileName: name,
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
          profileName: name,
          preferences: preferences,
        ),
      ),
    );
  }

  void _goMessages() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          profileName: name,
          preferences: preferences,
        ),
      ),
    );
  }

  Widget _gallery(ServerProfile value) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: value.photoUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 88,
              color: scheme.surfaceContainerHigh,
              child: Image.network(
                ApiService.absoluteMediaUrl(value.photoUrls[index]),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _loadingOrError() {
    final scheme = Theme.of(context).colorScheme;
    if (loadingProfile) {
      return Center(
        child: CircularProgressIndicator(color: scheme.primary),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: scheme.onSurfaceVariant, size: 40),
            const SizedBox(height: 12),
            Text(
              profileError ?? 'Profil yüklenemedi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadProfile,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileContent() {
    final value = profile;
    if (value == null) return _loadingOrError();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final primaryPhoto = value.photoUrls.isEmpty ? '' : value.photoUrls.first;
    final ageText = value.age > 0 ? ', ${value.age}' : '';

    return Stack(
      children: [
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: () => _loadProfile(silent: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                children: [
                  ProfileHero(name: value.name, imageUrl: primaryPhoto),
                  const SizedBox(height: 72),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      children: [
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 28,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                            children: [
                              TextSpan(text: value.name),
                              TextSpan(
                                text: ageText,
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
                            Icon(
                              Icons.location_on_outlined,
                              color: scheme.primary,
                              size: 17,
                            ),
                            Text(
                              value.preferences.locationLabel,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text('•', style: TextStyle(color: scheme.outlineVariant)),
                            const Text(
                              'Şimdi aktif',
                              style: TextStyle(
                                color: Color(0xFF36C76C),
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
                              backgroundColor: dark ? AppColors.lime : AppColors.navy,
                              foregroundColor: dark ? AppColors.navy : Colors.white,
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
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: scheme.outlineVariant),
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
                                  child: const Icon(Icons.tune_rounded, color: AppColors.navy),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Eşleşme tercihleri',
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        preferences.compactSummary,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 11.2,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (value.photoUrls.isNotEmpty) ...[
                          ProfileSection(
                            title: 'Fotoğraflarım',
                            child: _gallery(value),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ProfileSection(
                          title: 'Hakkımda',
                          child: Text(
                            value.bio.isEmpty ? 'Henüz bio eklenmedi.' : value.bio,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ProfileSection(
                          title: 'İlgi alanlarım',
                          child: value.interests.isEmpty
                              ? Text(
                                  'Henüz ilgi alanı eklenmedi.',
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final interest in value.interests)
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
                                value.prompt,
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                value.promptAnswer,
                                style: TextStyle(
                                  color: scheme.onSurface,
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
                              if (value.age > 0)
                                ProfileMiniInfo(
                                  icon: Icons.cake_outlined,
                                  text: '${value.age} yaş',
                                ),
                              if (value.gender.isNotEmpty)
                                ProfileMiniInfo(
                                  icon: Icons.person_outline_rounded,
                                  text: value.gender,
                                ),
                              ProfileMiniInfo(
                                icon: Icons.location_on_outlined,
                                text: value.preferences.locationLabel,
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
        ),
        if (!widget.asRootTab)
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: widget.asRootTab
            ? Column(
                children: [
                  Expanded(child: _profileContent()),
                  MainBottomNav(
                    selectedIndex: 3,
                    unreadMessages: 2,
                    onTap: (index) {
                      if (index == 0) _goHome();
                      if (index == 1) _goMatches();
                      if (index == 2) _goMessages();
                    },
                  ),
                ],
              )
            : _profileContent(),
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
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withOpacity(.92),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 43,
          height: 43,
          child: Icon(icon, color: scheme.onSurface, size: 23),
        ),
      ),
    );
  }
}
