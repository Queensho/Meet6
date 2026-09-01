import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class RoomRadar extends StatefulWidget {
  const RoomRadar({super.key});

  @override
  State<RoomRadar> createState() => _RoomRadarState();
}

class _RoomRadarState extends State<RoomRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RadarPainter(progress: _controller.value),
                ),
              ),
              Container(
                width: 154,
                height: 154,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.navy.withOpacity(.82),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withOpacity(.10),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  '6',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 88,
                    height: .9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -6,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = math.min(size.width, size.height);

    final fixedPaint = Paint()
      ..color = AppColors.navy.withOpacity(.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    for (final factor in [.30, .44, .58]) {
      canvas.drawCircle(center, base * factor, fixedPaint);
    }

    for (var i = 0; i < 3; i++) {
      final local = (progress + i / 3) % 1.0;
      final radius = base * (.22 + local * .42);
      final opacity = (1 - local) * .20;
      final pulse = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 - (local * 1.2);
      canvas.drawCircle(center, radius, pulse);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
