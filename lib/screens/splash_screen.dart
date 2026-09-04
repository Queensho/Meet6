import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../services/onboarding_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'onboarding_gate.dart';

/// Meet6 açılış akışı:
/// - Gerçekten yeni kullanıcıda Splash.mp4 yalnızca bir kez oynar.
/// - Mevcut kullanıcılar ve sonraki açılışlar lime zemin + Logo3 görür.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _videoSeenKey = 'meet6_intro_video_seen_v1';
  static const _staticSplashDuration = Duration(milliseconds: 1100);

  VideoPlayerController? _controller;
  Timer? _fallbackTimer;
  bool _decisionReady = false;
  bool _showVideo = false;
  bool _videoReady = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveSplash());
  }

  Future<void> _showStaticSplash() async {
    if (!mounted || _finished) return;
    setState(() {
      _decisionReady = true;
      _showVideo = false;
    });
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(_staticSplashDuration, _finish);
  }

  Future<void> _resolveSplash() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final videoSeen = preferences.getBool(_videoSeenKey) ?? false;

      if (videoSeen) {
        await _showStaticSplash();
        return;
      }

      // Bu anahtar yeni eklendiği için eski Meet6 kullanıcılarını yanlışlıkla
      // "ilk açılış" saymayız. Oturumu veya tamamlanmış onboarding'i olan kişi
      // doğrudan Logo3 splash görür.
      final authSession = await SessionService.loadAuthSessionId();
      final onboardingCompleted = await OnboardingService.isCompleted();
      final existingUser =
          (authSession != null && authSession.trim().isNotEmpty) || onboardingCompleted;

      await preferences.setBool(_videoSeenKey, true);

      if (existingUser) {
        await _showStaticSplash();
        return;
      }

      if (!mounted || _finished) return;
      setState(() {
        _decisionReady = true;
        _showVideo = true;
      });

      final controller = VideoPlayerController.asset('assets/images/Splash.mp4');
      _controller = controller;
      controller.addListener(_watchPlayback);

      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      if (!mounted || _finished) return;

      setState(() => _videoReady = true);
      await controller.play();

      final duration = controller.value.duration;
      final fallback = duration > Duration.zero
          ? duration + const Duration(milliseconds: 700)
          : const Duration(seconds: 6);
      _fallbackTimer = Timer(fallback, _finish);
    } catch (_) {
      // Tercih veya video başlatılamazsa kullanıcı açılış ekranında takılmaz.
      await _showStaticSplash();
    }
  }

  void _watchPlayback() {
    final controller = _controller;
    if (_finished || controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 100)) {
      _finish();
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _fallbackTimer?.cancel();
    setState(() {});
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_watchPlayback);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return const OnboardingGate();

    if (!_decisionReady || _showVideo) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: _showVideo && _videoReady && _controller != null
              ? ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              : const ColoredBox(color: Colors.black),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lime,
      body: Center(
        child: FractionallySizedBox(
          widthFactor: .56,
          child: Image.asset(
            'assets/images/Logo3.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
