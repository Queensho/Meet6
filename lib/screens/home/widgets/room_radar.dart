import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

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
    with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _pulseController;

  static const _avatarAssets = [
    'assets/images/Avatar1.png',
    'assets/images/Avatar2.png',
    'assets/images/Avatar3.png',
    'assets/images/Avatar4.png',
    'assets/images/Avatar5.png',
    'assets/images/Avatar6.png',
  ];

  @override
  void initState() {
    super.initState();

    // Avatar hareketi ve radar dalgası birbirinden bağımsızdır. Böylece avatarlar
    // kesintisiz tam tur atarken dalga hiçbir zaman tersine dönmez.
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          final avatarSize = (size * .145).clamp(44.0, 56.0).toDouble();
          // Avatar merkezlerini radarın sabit .39 halkasının tam üstüne oturt.
          final orbitRadius = size * .39;
          final center = size / 2;

          return AnimatedBuilder(
            animation: Listenable.merge([_orbitController, _pulseController]),
            builder: (context, child) {
              final orbitAngle = _orbitController.value * math.pi * 2;
              final pulseProgress = _pulseController.value;

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RadarPainter(progress: pulseProgress),
                    ),
                  ),
                  for (var index = 0; index < _avatarAssets.length; index++)
                    _buildOrbitAvatar(
                      asset: _avatarAssets[index],
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
                  // Tam tur dönen avatarın alt noktada CTA ile çakışmaması için
                  // etiketi merkez 6'nın hemen altındaki güvenli boşluğa alıyoruz.
                  Positioned(
                    bottom: size * .20,
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

  Widget _buildOrbitAvatar({
    required String asset,
    required int index,
    required double orbitAngle,
    required double center,
    required double radius,
    required double avatarSize,
  }) {
    // İlk karede dengeli altıgen görünüm; ardından bütün grup aynı çember üzerinde
    // sabit aralıkla kesintisiz 360° döner.
    const startAngle = -2 * math.pi / 3;
    final angle = startAngle + orbitAngle +
        (math.pi * 2 / _avatarAssets.length) * index;
    final left = center + math.cos(angle) * radius - avatarSize / 2;
    final top = center + math.sin(angle) * radius - avatarSize / 2;

    return Positioned(
      left: left,
      top: top,
      width: avatarSize,
      height: avatarSize,
      child: Semantics(
        label: 'Meet6 avatar ${index + 1}',
        image: true,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withOpacity(.14),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.softSurface,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
        ),
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
      ..color = AppColors.navy.withOpacity(.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;

    // .39 halkası aynı zamanda avatarların gerçek yörüngesidir.
    for (final factor in [.27, .39, .51]) {
      canvas.drawCircle(center, base * factor, fixedPaint);
    }

    // Dalgalar sadece merkezden dışarı akar; progress hiçbir zaman geri sarmaz.
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
