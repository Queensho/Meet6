import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/observability_service.dart';
import 'services/onboarding_service.dart';
import 'services/session_service.dart';

const _introVideoSeenKey = 'meet6_intro_video_seen_v1';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await ObservabilityService.initialize();

    final existingUserId = await SessionService.loadAuthUserId();
    await ObservabilityService.setUserId(existingUserId);

    var showIntroVideo = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      final videoSeen = preferences.getBool(_introVideoSeenKey) ?? false;

      if (!videoSeen) {
        final authSession = await SessionService.loadAuthSessionId();
        final onboardingCompleted = await OnboardingService.isCompleted();
        final existingUser =
            (authSession != null && authSession.trim().isNotEmpty) ||
            onboardingCompleted;

        showIntroVideo = !existingUser;
        await preferences.setBool(_introVideoSeenKey, true);
      }
    } catch (error, stack) {
      showIntroVideo = false;
      await ObservabilityService.recordError(
        error,
        stack,
        reason: 'intro_state_read_failed',
      );
    }

    runApp(Meet6App(showIntroVideo: showIntroVideo));
  }, (error, stack) {
    unawaited(
      ObservabilityService.recordError(
        error,
        stack,
        fatal: true,
        reason: 'unhandled_zone_error',
      ),
    );
  });
}
