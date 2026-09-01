import 'package:flutter/material.dart';

class LoginHero extends StatelessWidget {
  const LoginHero({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final heroHeight = (width * .62).clamp(205.0, 255.0);
    final imageWidth = (width * .86).clamp(265.0, 345.0);

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: Center(
        child: Image.asset(
          'assets/images/file_000000009c248210b0e425b8f2d3e68d.png',
          width: imageWidth,
          height: heroHeight,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
