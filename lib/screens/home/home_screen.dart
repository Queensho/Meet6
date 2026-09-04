import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/push_notification_service.dart';
import '../../services/realtime_service.dart';
import '../../services/runtime_app_config_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/notification_permission_onboarding.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late MatchingPreferences preferences;
  Timer? notificationPermissionTimer;

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
    WidgetsBinding.instance.addObserver(this);
    RuntimeAppConfigService.listenable.addListener(_runtimeChanged);
    unawaited(RuntimeAppConfigService.load(force: true));
    _startAuthenticatedServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notificationPermissionTimer?.cancel();
      notificationPermissionTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        unawaited(NotificationPermissionOnboarding.maybeShow(context));
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPushPermission());
    }
  }

  Future<void> _refreshPushPermission() async {
    try {
      await PushNotificationService.refreshPermissionAndRegistration();
    } catch (_) {
      // Returning from system settings must never interrupt the home screen.
    }
  }

  @override
  void dispose() {
    notificationPermissionTimer?.cancel();
    notificationPermissionTimer = null;
    WidgetsBinding.instance.removeObserver(this);
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

  void _startRoomSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RoomRulesScreen()),
    );
  }

  void _selectTab(int index) {
    if (index == 0) return;
    final Widget page = switch (index) {
      1 => const MatchesScreen(),
      2 => const MessagesScreen(),
      _ => const ProfileScreen(),
    };
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final config = RuntimeAppConfigService.listenable.value;

    return Scaffold(
      body: PhoneFrame(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 0),
                child: Row(
                  children: [
                    const Meet6MiniBrand(height: 32),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Bildirimler',
                      onPressed: _openNotifications,
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                  ],
                ),
              ),
              if (config.announcementEnabled &&
                  config.announcementMessage.trim().isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.lime.withValues(alpha: dark ? .16 : .32),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.lime.withValues(alpha: .45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (config.announcementTitle.trim().isNotEmpty)
                        Text(
                          config.announcementTitle,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      if (config.announcementTitle.trim().isNotEmpty)
                        const SizedBox(height: 3),
                      Text(
                        config.announcementMessage,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.profileName.trim().isEmpty
                            ? 'Yeni bir oda seni bekliyor.'
                            : 'Merhaba ${widget.profileName.trim()},',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '6 kişi, tek oda, gerçek zamanlı sohbet.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 310,
                        child: RoomRadar(
                          onTap: _startRoomSearch,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: FilledButton.icon(
                          onPressed: _startRoomSearch,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: AppColors.lime,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(Icons.groups_2_rounded),
                          label: const Text(
                            'Oda Ara',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _openPreferences,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: scheme.onSurfaceVariant,
                                size: 19,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  '${preferences.lookingFor} • ${preferences.minAge.round()}–${preferences.maxAge.round()} yaş • ${preferences.distanceKm} km',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              MainBottomNav(
                selectedIndex: 0,
                onSelected: _selectTab,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
