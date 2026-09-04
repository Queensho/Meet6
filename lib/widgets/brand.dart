import 'package:flutter/material.dart';

class Meet6Brand extends StatelessWidget {
  const Meet6Brand({
    super.key,
    required this.width,
    this.visualScale = 1.75,
    this.forceLogo2 = false,
  });

  final double width;
  final double visualScale;
  final bool forceLogo2;

  String _assetFor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return forceLogo2 || !dark
        ? 'assets/images/Logo2.png'
        : 'assets/images/Logo3.png';
  }

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
            _assetFor(context),
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
    this.visualScale = 1.75,
    this.forceLogo2 = false,
  });

  // Geriye dönük uyumluluk için tutuluyor. Lime/açık zemin zorlaması için
  // artık forceLogo2 kullanılmalı.
  final bool light;
  final double height;
  final double visualScale;
  final bool forceLogo2;

  String _assetFor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return forceLogo2 || !dark
        ? 'assets/images/Logo2.png'
        : 'assets/images/Logo3.png';
  }

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
            _assetFor(context),
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
