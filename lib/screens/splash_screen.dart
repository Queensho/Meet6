import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'onboarding_gate.dart';

/// Meet6 açılış splash'i.
///
/// Android/iOS native launch ekranları MP4 oynatamadığı için native ekran yalnızca
/// ilk kareyi beklerken siyah zemini gösterir. Flutter hazır olur olmaz Splash.mp4
/// hiçbir kontrol, buton veya video arayüzü göstermeden splash animasyonu olarak
/// tam ekran oynar ve bitince uygulama akışına geçer.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _controller;
  Timer? _fallbackTimer;
  bool _ready = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/images/Splash.mp4');
    _controller.addListener(_watchPlayback);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      await _controller.setVolume(0);
      if (!mounted || _finished) return;
      setState(() => _ready = true);
      await _controller.play();

      final duration = _controller.value.duration;
      final fallback = duration > Duration.zero
          ? duration + const Duration(milliseconds: 700)
          : const Duration(seconds: 6);
      _fallbackTimer = Timer(fallback, _finish);
    } catch (_) {
      _fallbackTimer = Timer(const Duration(milliseconds: 250), _finish);
    }
  }

  void _watchPlayback() {
    if (_finished || !_controller.value.isInitialized) return;
    final duration = _controller.value.duration;
    final position = _controller.value.position;
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
    _controller.removeListener(_watchPlayback);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return const OnboardingGate();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: _ready
            ? ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
