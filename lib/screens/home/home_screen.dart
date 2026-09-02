import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_bottom_nav.dart';
import '../chat/room_chat_screen.dart';
import '../matches/matches_screen.dart';
import '../messages/messages_screen.dart';
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

  void _enterRoom() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomChatScreen(
          profileName: widget.profileName,
        ),
      ),
    );
  }

  void _openMatches() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MatchesScreen(
          profileName: widget.profileName,
          preferences: preferences,
        ),
      ),
    );
  }

  void _openMessages() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          profileName: widget.profileName,
          preferences: preferences,
        ),
      ),
    );
  }

  void _openProfile() {
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
              child: Column(
                children: [
                  Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
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
                              ],
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              flex: 6,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: RoomRadar(onTap: _enterRoom),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '6 kişi. 15 dk.\nGerçek sohbet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 34,
                                height: .98,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.profileName.isEmpty
                                  ? '${preferences.locationLabel} çevresindeki kişilerle sohbet et.'
                                  : '${widget.profileName}, ${preferences.locationLabel} çevresindeki kişilerle sohbet et.',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 13.2,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 9),
                            InkWell(
                              onTap: _openPreferences,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
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
                                      size: 17,
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        '${preferences.locationLabel} · ${preferences.distanceLabel}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.navy,
                                          fontSize: 11.8,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.tune_rounded,
                                      color: AppColors.navy,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            InkWell(
                              onTap: _enterRoom,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.30),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.navy.withOpacity(.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: AppColors.navy,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.touch_app_rounded,
                                        color: AppColors.lime,
                                        size: 19,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Odaya girmek için 6’ya dokun',
                                            style: TextStyle(
                                              color: AppColors.navy,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Sana uygun 5 kişiyle sohbet başlar.',
                                            style: TextStyle(
                                              color: AppColors.navy,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: AppColors.navy,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  MainBottomNav(
                    selectedIndex: 0,
                    unreadMessages: 2,
                    onTap: (index) {
                      if (index == 1) _openMatches();
                      if (index == 2) _openMessages();
                      if (index == 3) _openProfile();
                    },
                  ),
                ],
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
