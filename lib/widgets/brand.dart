import 'package:flutter/material.dart';

class Meet6Brand extends StatelessWidget {
  const Meet6Brand({
    super.key,
    required this.width,
    this.visualScale = 1.55,
  });

  final double width;
  final double visualScale;

  @override
  Widget build(BuildContext context) {
    final logoHeight = (width * .094).clamp(31.0, 38.0);
    return SizedBox(
      height: logoHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.scale(
          scale: visualScale,
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/images/Logo2.png',
            height: logoHeight,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class Meet6MiniBrand extends StatelessWidget {
  const Meet6MiniBrand({
    super.key,
    this.light = false,
    this.height = 23,
    this.visualScale = 1.55,
  });

  final bool light;
  final double height;
  final double visualScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.scale(
          scale: visualScale,
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/images/Logo2.png',
            height: height,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
