import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class Meet6Brand extends StatelessWidget {
  const Meet6Brand({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: (width * .094).clamp(31.0, 38.0),
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -2,
        ),
        children: const [
          TextSpan(text: 'meet', style: TextStyle(color: AppColors.navy)),
          TextSpan(text: '6', style: TextStyle(color: AppColors.blue)),
        ],
      ),
    );
  }
}

class Meet6MiniBrand extends StatelessWidget {
  const Meet6MiniBrand({super.key, this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
        ),
        children: [
          TextSpan(
            text: 'meet',
            style: TextStyle(color: light ? Colors.white : AppColors.navy),
          ),
          TextSpan(
            text: '6',
            style: TextStyle(color: light ? Colors.white : AppColors.blue),
          ),
        ],
      ),
    );
  }
}
