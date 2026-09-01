import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class WaveBackground extends CustomPainter {
  const WaveBackground();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.width * .06).clamp(18.0, 26.0);
    final lime = Paint()
      ..color = AppColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final blue = Paint()
      ..color = AppColors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final blob = Paint()..color = const Color(0xFFF0F1F8);

    canvas.drawCircle(
      Offset(size.width * .98, size.height * .28),
      size.width * .20,
      blob,
    );
    canvas.drawCircle(
      Offset(size.width * .02, size.height * .53),
      size.width * .16,
      blob,
    );

    final top = Path()
      ..moveTo(size.width * .64, -10)
      ..cubicTo(
        size.width * .72,
        size.height * .02,
        size.width * .68,
        size.height * .06,
        size.width * .79,
        size.height * .09,
      )
      ..cubicTo(
        size.width * .88,
        size.height * .12,
        size.width * .82,
        size.height * .15,
        size.width * 1.04,
        size.height * .18,
      );
    canvas.drawPath(top, lime);

    final bottom = Path()
      ..moveTo(-18, size.height - size.height * .055)
      ..cubicTo(
        size.width * .06,
        size.height - size.height * .09,
        size.width * .13,
        size.height - size.height * .02,
        size.width * .23,
        size.height - size.height * .03,
      )
      ..cubicTo(
        size.width * .33,
        size.height - size.height * .04,
        size.width * .38,
        size.height + 12,
        size.width * .49,
        size.height + 2,
      );
    canvas.drawPath(bottom, blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
