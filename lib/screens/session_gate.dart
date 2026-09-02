import 'package:flutter/material.dart';

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
  late final Future<SavedSession?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = SessionService.loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SavedSession?>(
      future: _sessionFuture,
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

        final session = snapshot.data;
        if (session == null) return const LoginScreen();

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
      },
    );
  }
}
