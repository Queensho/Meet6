import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import 'onboarding_gate.dart';

/// Meet6 açılış akışı:
/// - İlk gerçek açılışta Splash.mp4 yalnızca bir kez oynar.
/// - Sonraki açılışlarda lime zemin üzerinde Logo3 gösterilir.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.showIntroVideo,
  });

  final bool showIntroVideo;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _staticSplashDuration = Duration(milliseconds: 1200);

  VideoPlayerController? _controller;
  Timer? _fallbackTimer;
  bool _videoReady = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (widget.showIntroVideo) {
      unawaited(_startVideo());
    } else {
      _fallbackTimer = Timer(_staticSplashDuration, _finish);
    }
  }

  Future<void> _startVideo() async {
    try {
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
      if (!mounted || _finished) return;
      _fallbackTimer?.cancel();
      _fallbackTimer = Timer(const Duration(milliseconds: 250), _finish);
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

    if (widget.showIntroVideo) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: _videoReady && _controller != null
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

    return const Scaffold(
      backgroundColor: AppColors.lime,
      body: Center(
        child: FractionallySizedBox(
          widthFactor: .72,
          child: Image(
            image: AssetImage('assets/images/Logo3.png'),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
