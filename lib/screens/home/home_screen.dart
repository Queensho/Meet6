import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../chat/room_chat_screen.dart';
import '../preferences/matching_preferences_screen.dart';
import '../profile/profile_screen.dart';
import 'widgets/room_radar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.profileName = '',
    this.city = '',
    this.country = '',
    this.latitude,
    this.longitude,
    this.distanceKm = 25,
    this.lookingFor = 'Herkes',
    this.minAge = 20,
    this.maxAge = 35,
    this.purpose = 'Yeni insanlarla tanışma',
  });

  final String profileName;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;
  final int distanceKm;
  final String lookingFor;
  final double minAge;
  final double maxAge;
  final String purpose;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late MatchingPreferences preferences;

  @override
  void initState() {
    super.initState();
    preferences = MatchingPreferences(
      lookingFor: widget.lookingFor,
      minAge: widget.minAge,
      maxAge: widget.maxAge,
      distanceKm: widget.distanceKm,
      purpose: widget.purpose,
      city: widget.city,
      country: widget.country,
      latitude: widget.latitude,
      longitude: widget.longitude,
    );
  }

  Future<void> _openPreferences() async {
    final result = await Navigator.of(context).push<MatchingPreferences>(
      MaterialPageRoute(
        builder: (_) => MatchingPreferencesScreen(initial: preferences),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => preferences = result);
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          profileName: widget.profileName,
          initialPreferences: preferences,
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
      backgroundColor: AppColors.lime,
      body: LayoutBuilder(
        builder: (context, viewport) {
          final desktop = viewport.maxWidth > 520;
          final width = desktop ? 390.0 : viewport.maxWidth;
          final height = desktop ? 844.0 : viewport.maxHeight;

          return Container(
            color: desktop ? const Color(0xFFEFF1F7) : AppColors.lime,
            alignment: Alignment.center,
            child: Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius:
                    desktop ? BorderRadius.circular(32) : BorderRadius.zero,
                boxShadow: desktop
                    ? const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        ),
                      ]
                    : null,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 34,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'meet',
                                      style: TextStyle(color: AppColors.navy),
                                    ),
                                    TextSpan(
                                      text: '6',
                                      style: TextStyle(color: AppColors.blue),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          _TopIcon(
                            icon: Icons.tune_rounded,
                            onTap: _openPreferences,
                          ),
                          const SizedBox(width: 8),
                          _TopIcon(
                            icon: Icons.notifications_none_rounded,
                            showDot: true,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _TopIcon(
                            icon: Icons.person_rounded,
                            onTap: _openProfile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Expanded(
                        flex: 5,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: RoomRadar(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '6 kişi. 15 dk.\nGerçek sohbet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 40,
                          height: .98,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.8,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.profileName.isEmpty
                            ? '${preferences.locationLabel} çevresindeki kişilerle\nsohbete hemen başla.'
                            : '${widget.profileName}, ${preferences.locationLabel} çevresindeki kişilerle\nsohbete hemen başla.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _openPreferences,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.42),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.my_location_rounded,
                                color: AppColors.blue,
                                size: 18,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  '${preferences.locationLabel} · ${preferences.distanceLabel}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.tune_rounded,
                                color: AppColors.navy,
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Odaya gir',
                        dark: true,
                        height: 62,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RoomChatScreen(
                                profileName: widget.profileName,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.38),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.navy, size: 24),
          ),
          if (showDot)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
