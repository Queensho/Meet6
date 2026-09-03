import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import '../services/runtime_app_config_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'onboarding_screen.dart';
import 'session_gate.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late final Future<Widget> _screen = _resolve();

  Future<Widget> _resolve() async {
    final authSession = await SessionService.loadAuthSessionId();
    if (authSession != null && authSession.trim().isNotEmpty) {
      return const SessionGate();
    }

    final completed = await OnboardingService.isCompleted();
    if (completed) return const SessionGate();

    final config = await RuntimeAppConfigService.load(force: true);
    return OnboardingScreen(config: config);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _screen,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: AppColors.blue,
                ),
              ),
            ),
          );
        }
        return snapshot.data ?? const SessionGate();
      },
    );
  }
}
