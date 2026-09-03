import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/push_api_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/realtime_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_bottom_nav.dart';
import '../matches/matches_screen.dart';
import '../messages/messages_screen.dart';
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
  bool _pushDiagnosing = false;

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
    _startAuthenticatedServices();
  }

  void _startAuthenticatedServices() {
    unawaited(RealtimeService.connect().catchError((_) {}));
    unawaited(
      PushNotificationService.initializeForAuthenticatedUser()
          .catchError((_) {}),
    );
  }

  Future<void> _queueDeepLinkTest(String kind, String label) async {
    try {
      final response = await PushApiService.sendTestNotification(kind: kind);
      if (!mounted) return;
      final delay = response['delaySeconds'];
      final seconds = delay is num ? delay.toInt() : 5;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$label bildirimi $seconds sn içinde gelecek. Uygulamayı arka plana al.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label testi başlatılamadı: $error')),
      );
    }
  }

  Future<void> _diagnosePush() async {
    if (_pushDiagnosing) return;
    setState(() => _pushDiagnosing = true);

    String result;
    try {
      result = await PushNotificationService.diagnoseAndRegister();
    } catch (error) {
      result = '❌ Push teşhisi çalıştırılamadı\n$error';
    }

    if (!mounted) return;
    setState(() => _pushDiagnosing = false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Push bildirimi teşhisi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(result),
              const SizedBox(height: 18),
              const Text(
                'Deep-link cihaz testi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bir testi başlat, uygulamayı arka plana al ve gelen bildirime dokun.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      unawaited(_queueDeepLinkTest('room', 'Oda'));
                    },
                    icon: const Icon(Icons.groups_2_outlined),
                    label: const Text('Oda'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      unawaited(_queueDeepLinkTest('match', 'Eşleşme'));
                    },
                    icon: const Icon(Icons.favorite_border_rounded),
                    label: const Text('Eşleşme'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      unawaited(_queueDeepLinkTest('message', 'Mesaj'));
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Mesaj'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
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
                        icon: _pushDiagnosing
                            ? Icons.sync_rounded
                            : Icons.notifications_none_rounded,
                        onTap: _diagnosePush,
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
                  const Text(
                    '6 kişi. 15 dk.\nGerçek sohbet.',
                    style: TextStyle(
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
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _openPreferences,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .42),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.navy.withValues(alpha: .12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.radar_rounded,
                            size: 17,
                            color: AppColors.navy,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            preferences.distanceLabel,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.tune_rounded,
                            size: 15,
                            color: AppColors.navy,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      child: const Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.navy,
                            child: Icon(
                              Icons.touch_app_rounded,
                              size: 19,
                              color: AppColors.lime,
                            ),
                          ),
                          SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Odaya girmek için 6’ya dokun',
                                  style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Sana uygun 5 kişiyle sohbet başlar.',
                                  style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
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
