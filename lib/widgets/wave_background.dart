import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class WaveBackground extends CustomPainter {
  const WaveBackground({this.dark = false});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.width * .068).clamp(22.0, 30.0).toDouble();

    final lime = Paint()
      ..color = dark ? AppColors.lime.withOpacity(.92) : AppColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final blue = Paint()
      ..color = dark
          ? const Color(0xFF5478FF).withOpacity(.96)
          : AppColors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final blob = Paint()
      ..color = dark
          ? Colors.white.withOpacity(.035)
          : const Color(0xFFF0F1F8);

    canvas.drawCircle(
      Offset(size.width * .98, size.height * .29),
      size.width * .22,
      blob,
    );
    canvas.drawCircle(
      Offset(size.width * .02, size.height * .54),
      size.width * .18,
      blob,
    );

    final top = Path()
      ..moveTo(size.width * .61, -12)
      ..cubicTo(
        size.width * .73,
        size.height * .018,
        size.width * .66,
        size.height * .064,
        size.width * .79,
        size.height * .092,
      )
      ..cubicTo(
        size.width * .92,
        size.height * .12,
        size.width * .81,
        size.height * .158,
        size.width * 1.07,
        size.height * .185,
      );
    canvas.drawPath(top, lime);

    final bottom = Path()
      ..moveTo(-20, size.height - size.height * .05)
      ..cubicTo(
        size.width * .065,
        size.height - size.height * .095,
        size.width * .14,
        size.height - size.height * .014,
        size.width * .245,
        size.height - size.height * .032,
      )
      ..cubicTo(
        size.width * .35,
        size.height - size.height * .052,
        size.width * .405,
        size.height + 18,
        size.width * .535,
        size.height + 2,
      );
    canvas.drawPath(bottom, blue);

    if (dark) {
      final glowLime = Paint()
        ..color = AppColors.lime.withOpacity(.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 12
        ..strokeCap = StrokeCap.round;
      final glowBlue = Paint()
        ..color = const Color(0xFF5478FF).withOpacity(.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 12
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(top, glowLime);
      canvas.drawPath(bottom, glowBlue);
    }
  }

  @override
  bool shouldRepaint(covariant WaveBackground oldDelegate) =>
      oldDelegate.dark != dark;
}
