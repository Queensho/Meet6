import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_runtime_config_service.dart';
import '../services/push_notification_service.dart';
import '../services/realtime_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'chat/room_chat_screen.dart';
import 'chat/room_selection_screen.dart';
import 'home/home_screen.dart';
import 'login_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<Widget> _screenFuture;

  @override
  void initState() {
    super.initState();
    _screenFuture = _resolveScreen();
  }

  void _startAuthenticatedServices() {
    unawaited(RealtimeService.connect().catchError((_) {}));
    unawaited(
      PushNotificationService.initializeForAuthenticatedUser()
          .catchError((_) {}),
    );
  }

  Future<void> _stopAuthenticatedServices() async {
    RealtimeService.disconnect();
    await PushNotificationService.resetRuntimeState();
  }

  Future<Widget> _resolveAuthenticatedLanding(SavedSession session) async {
    unawaited(
      PushNotificationService.initializeForAuthenticatedUser()
          .catchError((_) {}),
    );

    try {
      await RealtimeService.connect();
      final state = await RealtimeService.queueStatus();
      final rawRoom = state['room'];
      if (state['state'] == 'room' && rawRoom is Map) {
        final room = Map<String, dynamic>.from(rawRoom);
        final roomId = room['id']?.toString() ?? '';
        final status = room['status']?.toString();
        if (roomId.isNotEmpty && status == 'selection') {
          return RoomSelectionScreen(
            roomId: roomId,
            profileName: session.profileName,
          );
        }
        if (roomId.isNotEmpty && status == 'active') {
          return RoomChatScreen(
            roomId: roomId,
            profileName: session.profileName,
          );
        }
      }
    } catch (_) {
      unawaited(RealtimeService.connect().catchError((_) {}));
    }

    return _home(session);
  }

  Future<Widget> _resolveScreen() async {
    final runtime = await AppRuntimeConfigService.refresh();
    if (runtime.maintenanceEnabled) {
      await _stopAuthenticatedServices();
      return _MaintenanceScreen(message: runtime.maintenanceMessage);
    }

    final authSession = await SessionService.loadAuthSessionId();
    final local = await SessionService.loadProfile();

    if (authSession == null) {
      await _stopAuthenticatedServices();
      if (local != null) await SessionService.clearProfile();
      return const LoginScreen();
    }

    try {
      final response = await ApiService.getMe(sessionId: authSession);
      final raw = response['user'];
      if (raw is! Map) {
        await _stopAuthenticatedServices();
        await SessionService.clear();
        return const LoginScreen();
      }

      final user = Map<String, dynamic>.from(raw);
      final completed = user['profile_completed'] == true;
      final name = user['display_name']?.toString().trim() ?? '';

      if (!completed || name.isEmpty) {
        await _stopAuthenticatedServices();
        await SessionService.clear();
        return const LoginScreen();
      }

      final saved = _savedSessionFromUser(user);
      await _cache(saved);
      return _resolveAuthenticatedLanding(saved);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _stopAuthenticatedServices();
        await SessionService.clear();
        return const LoginScreen();
      }
      if (local != null) {
        _startAuthenticatedServices();
        return _home(local);
      }
      return const LoginScreen();
    } catch (_) {
      if (local != null) {
        _startAuthenticatedServices();
        return _home(local);
      }
      return const LoginScreen();
    }
  }

  SavedSession _savedSessionFromUser(Map<String, dynamic> user) {
    double toDouble(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return SavedSession(
      profileName: user['display_name']?.toString().trim() ?? '',
      city: user['city']?.toString() ?? '',
      country: user['country']?.toString() ?? '',
      latitude: user['latitude'] == null ? null : toDouble(user['latitude'], 0),
      longitude: user['longitude'] == null ? null : toDouble(user['longitude'], 0),
      distanceKm: toDouble(user['distance_km'], 25).round(),
      lookingFor: user['looking_for']?.toString() ?? 'Herkes',
      minAge: toDouble(user['min_age'], 20),
      maxAge: toDouble(user['max_age'], 35),
      purpose: user['purpose']?.toString() ?? 'Yeni insanlarla tanışma',
    );
  }

  Future<void> _cache(SavedSession saved) {
    return SessionService.saveProfile(
      profileName: saved.profileName,
      city: saved.city,
      country: saved.country,
      latitude: saved.latitude,
      longitude: saved.longitude,
      distanceKm: saved.distanceKm,
      lookingFor: saved.lookingFor,
      minAge: saved.minAge,
      maxAge: saved.maxAge,
      purpose: saved.purpose,
    );
  }

  Widget _home(SavedSession session) {
    return HomeScreen(
      profileName: session.profileName,
      city: session.city,
      country: session.country,
      latitude: session.latitude,
      longitude: session.longitude,
      distanceKm: session.distanceKm,
      lookingFor: session.lookingFor,
      minAge: session.minAge,
      maxAge: session.maxAge,
      purpose: session.purpose,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _screenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.lime,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 42,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.4,
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
                  SizedBox(height: 20),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}

class _MaintenanceScreen extends StatefulWidget {
  const _MaintenanceScreen({required this.message});
  final String message;

  @override
  State<_MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<_MaintenanceScreen> {
  bool checking = false;

  Future<void> _checkAgain() async {
    if (checking) return;
    setState(() => checking = true);
    final config = await AppRuntimeConfigService.refresh();
    if (!mounted) return;
    if (!config.maintenanceEnabled) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SessionGate()),
      );
      return;
    }
    setState(() => checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message.trim().isEmpty
        ? 'Meet6 kısa süreli bakımda. Lütfen biraz sonra tekrar dene.'
        : widget.message;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.handyman_rounded,
                    color: AppColors.navy,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Meet6 bakımda',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: checking ? null : _checkAgain,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  icon: checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.navy,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Tekrar kontrol et',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
