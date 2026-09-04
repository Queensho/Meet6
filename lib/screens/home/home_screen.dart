import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/active_room_service.dart';
import '../../services/api_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/realtime_service.dart';
import '../../services/runtime_app_config_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/notification_permission_onboarding.dart';
import '../chat/room_chat_screen.dart';
import '../chat/room_selection_screen.dart';
import '../chat/voice_room_screen.dart';
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
  Timer? activeRoomCountdownTimer;
  StreamSubscription<RealtimeEvent>? realtimeSub;
  Map<String, dynamic>? activeRoom;
  bool activeRoomLoading = false;
  bool activeRoomLeaving = false;
  bool activeRoomBoundaryRefreshing = false;

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
    realtimeSub = RealtimeService.events.listen(_onRealtimeEvent);
    unawaited(RuntimeAppConfigService.load(force: true));
    _startAuthenticatedServices();
    unawaited(_refreshActiveRoom());
    _startActiveRoomCountdown();
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
      unawaited(_refreshActiveRoom());
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
    activeRoomCountdownTimer?.cancel();
    realtimeSub?.cancel();
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

  void _onRealtimeEvent(RealtimeEvent event) {
    if (!mounted) return;
    if (event.type == 'connection:connected') {
      unawaited(_refreshActiveRoom());
      return;
    }

    if (event.type == 'queue:matched') {
      final raw = event.data['room'];
      if (raw is Map) {
        final next = Map<String, dynamic>.from(raw);
        next['roomMode'] ??= 'text';
        setState(() => activeRoom = next);
      }
      return;
    }

    if (event.type == 'room:update') {
      final raw = event.data['room'];
      if (raw is! Map) return;
      final latest = Map<String, dynamic>.from(raw);
      final roomId = latest['id']?.toString() ?? event.data['roomId']?.toString() ?? '';
      final currentId = activeRoom?['id']?.toString() ?? '';
      if (currentId.isNotEmpty && roomId != currentId) return;
      latest['roomMode'] ??= activeRoom?['roomMode'] ?? 'text';
      if (latest['status']?.toString() == 'closed') {
        setState(() => activeRoom = null);
      } else {
        setState(() => activeRoom = latest);
      }
      return;
    }

    if (event.type == 'room:removed' || event.type == 'room:closed-by-admin') {
      final roomId = event.data['roomId']?.toString() ?? '';
      if (roomId.isEmpty || roomId == activeRoom?['id']?.toString()) {
        setState(() => activeRoom = null);
      }
    }
  }

  Future<void> _refreshActiveRoom() async {
    if (activeRoomLoading || !mounted) return;
    // Existing widget tests use the realtime fake without a network backend.
    if (RealtimeService.debugAckOverride != null &&
        ActiveRoomService.debugCurrentOverride == null) {
      return;
    }
    activeRoomLoading = true;
    try {
      final result = await ActiveRoomService.current();
      final raw = result['room'];
      if (!mounted) return;
      setState(() {
        activeRoom = raw is Map ? Map<String, dynamic>.from(raw) : null;
      });
    } catch (_) {
      // Home remains usable when the recovery endpoint is temporarily unavailable.
    } finally {
      activeRoomLoading = false;
    }
  }

  void _startActiveRoomCountdown() {
    activeRoomCountdownTimer?.cancel();
    activeRoomCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || activeRoom == null) return;
      final room = activeRoom!;
      final status = room['status']?.toString();
      final key = status == 'selection' ? 'selectionSecondsLeft' : 'secondsLeft';
      final current = (room[key] as num?)?.toInt() ?? 0;
      if (current > 0) {
        setState(() => activeRoom = {...room, key: current - 1});
        if (current == 1 && !activeRoomBoundaryRefreshing) {
          activeRoomBoundaryRefreshing = true;
          Future<void>.delayed(const Duration(milliseconds: 350), () async {
            await _refreshActiveRoom();
            activeRoomBoundaryRefreshing = false;
          });
        }
      }
    });
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

  Future<void> _enterRoom() async {
    if (activeRoom != null) {
      await _showActiveRoomChoice();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomRulesScreen(profileName: widget.profileName),
      ),
    );
    if (mounted) unawaited(_refreshActiveRoom());
  }

  Future<void> _openActiveRoom() async {
    final room = activeRoom;
    if (room == null) return;
    final roomId = room['id']?.toString() ?? '';
    if (roomId.isEmpty) return;
    final status = room['status']?.toString() ?? 'active';
    final mode = room['roomMode']?.toString() ?? 'text';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          if (status == 'selection') {
            return RoomSelectionScreen(
              roomId: roomId,
              profileName: widget.profileName,
            );
          }
          if (mode == 'voice') {
            return VoiceRoomScreen(
              roomId: roomId,
              profileName: widget.profileName,
            );
          }
          return RoomChatScreen(
            roomId: roomId,
            profileName: widget.profileName,
          );
        },
      ),
    );
    if (mounted) unawaited(_refreshActiveRoom());
  }

  Future<void> _showActiveRoomChoice() async {
    final room = activeRoom;
    if (room == null) return;
    final mode = room['roomMode']?.toString() == 'voice' ? 'Premium birebir sesli görüşme' : 'Yazılı oda';
    final action = await showModalBottomSheet<_ActiveRoomAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.meeting_room_rounded, color: AppColors.lime, size: 40),
              const SizedBox(height: 10),
              const Text(
                'Zaten aktif bir odadasın',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '$mode devam ediyor. İstersen geri dön, istersen bu odadan ayrılıp yeni oda ara.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, _ActiveRoomAction.returnToRoom),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: AppColors.navy,
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Odaya dön', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, _ActiveRoomAction.newRoom),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Yeni oda ara'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == _ActiveRoomAction.returnToRoom) {
      await _openActiveRoom();
    } else if (action == _ActiveRoomAction.newRoom) {
      await _leaveActiveRoom(startNewRoom: true);
    }
  }

  Future<void> _leaveActiveRoom({bool startNewRoom = false}) async {
    final room = activeRoom;
    if (room == null || activeRoomLeaving) return;
    final roomId = room['id']?.toString() ?? '';
    if (roomId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(startNewRoom ? 'Yeni oda aransın mı?' : 'Odadan ayrıl?'),
        content: Text(
          startNewRoom
              ? 'Mevcut odadan tamamen ayrılacaksın. Sonra yeni oda arama ekranına geçeceksin.'
              : 'Bu odadan tamamen ayrılacaksın ve tekrar bu odaya dönemeyeceksin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.lime,
            ),
            child: Text(startNewRoom ? 'Ayrıl ve yeni oda ara' : 'Odadan ayrıl'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => activeRoomLeaving = true);
    try {
      await ActiveRoomService.leave(roomId);
      await RealtimeService.leaveRoom(roomId);
      if (!mounted) return;
      setState(() => activeRoom = null);
      if (startNewRoom) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RoomRulesScreen(profileName: widget.profileName),
          ),
        );
        if (mounted) unawaited(_refreshActiveRoom());
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => activeRoomLeaving = false);
    }
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
    final room = activeRoom;
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
                      const Meet6MiniBrand(height: 31, forceLogo2: true),
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
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 6,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: RoomRadar(onTap: _enterRoom),
                          ),
                        ),
                        if (room != null)
                          Positioned(
                            top: 2,
                            left: 0,
                            right: 0,
                            child: _ActiveRoomCard(
                              room: room,
                              leaving: activeRoomLeaving,
                              onReturn: _openActiveRoom,
                              onLeave: () => _leaveActiveRoom(),
                            ),
                          ),
                      ],
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
                                Text(
                                  room == null
                                      ? 'Odaya girmek için 6’ya dokun'
                                      : 'Oda seçenekleri',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  room == null
                                      ? 'Sana uygun ${runtime.minimumUsers - 1} kişiyle sohbet başlar.'
                                      : 'Odaya dön veya yeni oda ara.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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

enum _ActiveRoomAction { returnToRoom, newRoom }

class _ActiveRoomCard extends StatelessWidget {
  const _ActiveRoomCard({
    required this.room,
    required this.leaving,
    required this.onReturn,
    required this.onLeave,
  });

  final Map<String, dynamic> room;
  final bool leaving;
  final VoidCallback onReturn;
  final VoidCallback onLeave;

  String get _timeText {
    final status = room['status']?.toString();
    final raw = status == 'selection'
        ? room['selectionSecondsLeft']
        : room['secondsLeft'];
    final seconds = ((raw as num?)?.toInt() ?? 0).clamp(0, 60 * 60);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final voice = room['roomMode']?.toString() == 'voice';
    final selection = room['status']?.toString() == 'selection';
    final members = room['members'] is List ? (room['members'] as List).length : 0;
    final title = selection
        ? 'Seçimini yap'
        : voice
            ? 'Birebir sesli görüşmen devam ediyor'
            : 'Sohbetin devam ediyor';
    final subtitle = selection
        ? 'Gizli seçim için $_timeText kaldı'
        : '${voice ? 'Birebir sesli' : 'Yazılı oda'} · $members kişi · $_timeText kaldı';

    return Semantics(
      container: true,
      label: '$title. $subtitle',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: .16),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
              ),
              child: Icon(
                selection
                    ? Icons.favorite_rounded
                    : voice
                        ? Icons.mic_rounded
                        : Icons.forum_rounded,
                color: AppColors.navy,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AKTİF ODAN',
                    style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: leaving ? null : onReturn,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    selection ? 'Seç' : 'Dön',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 3),
                TextButton(
                  onPressed: leaving ? null : onLeave,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    leaving ? 'Ayrılıyor...' : 'Ayrıl',
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
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
