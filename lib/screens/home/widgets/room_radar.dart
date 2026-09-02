import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/meet6_3d_avatar.dart';

class RoomRadar extends StatefulWidget {
  const RoomRadar({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<RoomRadar> createState() => _RoomRadarState();
}

class _RoomRadarState extends State<RoomRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _profiles = [
    _OrbitProfile('Deniz', Alignment(0, -1)),
    _OrbitProfile('Selin', Alignment(-1, -.30)),
    _OrbitProfile('Bora', Alignment(1, -.30)),
    _OrbitProfile('Ece', Alignment(-1, .60)),
    _OrbitProfile('Mert', Alignment(1, .60)),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          final avatarSize = (size * .17).clamp(48.0, 64.0).toDouble();
          final orbitRadius = size * .355;
          final center = size / 2;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final orbitAngle = _controller.value * math.pi * 2;
              final pulseProgress = (_controller.value * 4) % 1.0;

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RadarPainter(progress: pulseProgress),
                    ),
                  ),
                  for (var index = 0; index < _profiles.length; index++)
                    _buildOrbitProfile(
                      profile: _profiles[index],
                      index: index,
                      orbitAngle: orbitAngle,
                      center: center,
                      radius: orbitRadius,
                      avatarSize: avatarSize,
                    ),
                  Semantics(
                    button: true,
                    label: 'Odaya gir',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onTap,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: size * .39,
                          height: size * .39,
                          decoration: BoxDecoration(
                            color: AppColors.lime,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.navy,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(.74),
                                blurRadius: 24,
                                spreadRadius: 6,
                              ),
                              BoxShadow(
                                color: AppColors.blue.withOpacity(.17),
                                blurRadius: 34,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '6',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: size * .22,
                              height: .9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: size * .075,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withOpacity(.88),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              color: AppColors.lime,
                              size: 14,
                            ),
                            SizedBox(width: 5),
                            Text(
                              '6’ya dokun',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOrbitProfile({
    required _OrbitProfile profile,
    required int index,
    required double orbitAngle,
    required double center,
    required double radius,
    required double avatarSize,
  }) {
    final angle = orbitAngle + (math.pi * 2 / _profiles.length) * index;
    final left = center + math.cos(angle) * radius - avatarSize / 2;
    final top = center + math.sin(angle) * radius - avatarSize / 2;

    return Positioned(
      left: left,
      top: top,
      width: avatarSize,
      height: avatarSize,
      child: Tooltip(
        message: profile.name,
        child: Meet63DAvatar(
          alignment: profile.alignment,
          size: avatarSize,
        ),
      ),
    );
  }
}

class _OrbitProfile {
  const _OrbitProfile(this.name, this.alignment);

  final String name;
  final Alignment alignment;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = math.min(size.width, size.height);

    final fixedPaint = Paint()
      ..color = AppColors.navy.withOpacity(.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;

    for (final factor in [.27, .39, .51]) {
      canvas.drawCircle(center, base * factor, fixedPaint);
    }

    for (var i = 0; i < 5; i++) {
      final local = (progress + i / 5) % 1.0;
      final eased = Curves.easeOutCubic.transform(local);
      final radius = base * (.18 + eased * .46);
      final opacity = (1 - local) * .70;
      final pulse = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.8 - (local * 2.3);
      canvas.drawCircle(center, radius, pulse);
    }

    final bluePulse = Paint()
      ..color = AppColors.blue.withOpacity((1 - progress) * .22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(
      center,
      base * (.24 + progress * .30),
      bluePulse,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
