import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/onboarding_service.dart';
import 'services/session_service.dart';

const _introVideoSeenKey = 'meet6_intro_video_seen_v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  } catch (_) {
    // Açılış kararı okunamazsa kullanıcı videoda takılmaz; statik splash kullanılır.
    showIntroVideo = false;
  }

  runApp(Meet6App(showIntroVideo: showIntroVideo));
}
