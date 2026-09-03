import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import 'onboarding_gate.dart';

class SplashVideoScreen extends StatefulWidget {
  const SplashVideoScreen({super.key});

  @override
  State<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<SplashVideoScreen> {
  late final VideoPlayerController _controller;
  Timer? _fallbackTimer;
  bool _ready = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/images/Splash.mp4');
    _controller.addListener(_watchPlayback);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      await _controller.setVolume(0);
      if (!mounted) return;
      setState(() => _ready = true);
      await _controller.play();

      final duration = _controller.value.duration;
      final safeDuration = duration > Duration.zero
          ? duration + const Duration(milliseconds: 700)
          : const Duration(seconds: 6);
      _fallbackTimer = Timer(safeDuration, _finish);
    } catch (_) {
      _fallbackTimer = Timer(const Duration(milliseconds: 350), _finish);
    }
  }

  void _watchPlayback() {
    if (_finished || !_controller.value.isInitialized) return;
    final duration = _controller.value.duration;
    final position = _controller.value.position;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 120)) {
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
    _controller.removeListener(_watchPlayback);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return const OnboardingGate();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready)
            LayoutBuilder(
              builder: (context, constraints) {
                final videoSize = _controller.value.size;
                return ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: videoSize.width,
                      height: videoSize.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                );
              },
            )
          else
            const ColoredBox(color: Colors.black),
          if (!_ready)
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.lime,
                ),
              ),
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black.withOpacity(.22),
              ),
              child: const Text(
                'Geç',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
