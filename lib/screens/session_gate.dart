import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
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

  Future<Widget> _resolveScreen() async {
    final authSession = await SessionService.loadAuthSessionId();
    final local = await SessionService.loadProfile();

    if (authSession == null) {
      RealtimeService.disconnect();
      if (local != null) await SessionService.clearProfile();
      return const LoginScreen();
    }

    try {
      final response = await ApiService.getMe(sessionId: authSession);
      final raw = response['user'];
      if (raw is! Map) {
        RealtimeService.disconnect();
        await SessionService.clear();
        return const LoginScreen();
      }

      final user = Map<String, dynamic>.from(raw);
      final completed = user['profile_completed'] == true;
      final name = user['display_name']?.toString().trim() ?? '';

      if (!completed || name.isEmpty) {
        RealtimeService.disconnect();
        await SessionService.clear();
        return const LoginScreen();
      }

      final saved = _savedSessionFromUser(user);
      await _cache(saved);
      unawaited(RealtimeService.connect().catchError((_) {}));
      return _home(saved);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        RealtimeService.disconnect();
        await SessionService.clear();
        return const LoginScreen();
      }
      if (local != null) {
        unawaited(RealtimeService.connect().catchError((_) {}));
        return _home(local);
      }
      return const LoginScreen();
    } catch (_) {
      if (local != null) {
        unawaited(RealtimeService.connect().catchError((_) {}));
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
