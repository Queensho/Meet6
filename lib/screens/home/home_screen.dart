import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/push_notification_service.dart';
import '../../services/realtime_service.dart';
import '../../services/runtime_app_config_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_bottom_nav.dart';
import '../matches/matches_screen.dart';
import '../messages/messages_screen.dart';
import '../notifications/notifications_screen.dart';
import '../preferences/matching_preferences_screen.dart';
import '../profile/profile_screen.dart';
import '../room/room_rules_screen.dart';
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
    RuntimeAppConfigService.listenable.addListener(_runtimeChanged);
    unawaited(RuntimeAppConfigService.load(force: true));
    _startAuthenticatedServices();
  }

  @override
  void dispose() {
    RuntimeAppConfigService.listenable.removeListener(_runtimeChanged);
    super.dispose();
  }

  void _runtimeChanged() {
    if (mounted) setState(() {});
  }

  void _startAuthenticatedServices() {
    unawaited(RealtimeService.connect().catchError((_) {}));
    unawaited(
      PushNotificationService.initializeForAuthenticatedUser()
          .catchError((_) {}),
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

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _enterRoom() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomRulesScreen(profileName: widget.profileName),
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

  void _handleBottomNavTap(int index) {
    switch (index) {
      case 0:
        return;
      case 1:
        _openMatches();
        return;
      case 2:
        _openMessages();
        return;
      case 3:
        _openProfile();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = RuntimeAppConfigService.cached;
    return Scaffold(
      backgroundColor: AppColors.lime,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontal = (width * .055).clamp(18.0, 24.0);

            return Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text.rich(
                        const TextSpan(
                          style: TextStyle(
                            fontSize: 31,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.8,
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
                      const Spacer(),
                      _TopButton(
                        icon: Icons.tune_rounded,
                        onTap: _openPreferences,
                      ),
                      const SizedBox(width: 9),
                      _TopButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: _openNotifications,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: RoomRadar(onTap: _enterRoom),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${runtime.minimumUsers} kişi. ${runtime.roomDurationMinutes} dk.\nGerçek sohbet.',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 34,
                      height: .98,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Yakınındaki kişilerle sohbet et.',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _enterRoom,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .42),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.navy.withValues(alpha: .12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.navy,
                            child: Icon(
                              Icons.touch_app_rounded,
                              size: 19,
                              color: AppColors.lime,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Odaya girmek için 6’ya dokun',
                                  style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sana uygun ${runtime.minimumUsers - 1} kişiyle sohbet başlar.',
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 11.5,
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
                  const SizedBox(height: 10),
                  MainBottomNav(
                    selectedIndex: 0,
                    onTap: _handleBottomNavTap,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .42),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.navy, size: 22),
        ),
      ),
    );
  }
}
