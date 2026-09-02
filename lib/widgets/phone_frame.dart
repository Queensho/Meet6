import 'package:flutter/material.dart';

import 'wave_background.dart';

class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final phoneBackground = dark ? const Color(0xFF0D1220) : const Color(0xFFF8F9FD);
    final desktopBackground = dark ? const Color(0xFF080B12) : const Color(0xFFEFF1F7);

    return LayoutBuilder(
      builder: (context, viewport) {
        final desktop = viewport.maxWidth > 520;
        return Container(
          color: desktop ? desktopBackground : phoneBackground,
          alignment: Alignment.center,
          child: Container(
            width: desktop ? 390 : viewport.maxWidth,
            height: desktop ? 844 : viewport.maxHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: phoneBackground,
              borderRadius:
                  desktop ? BorderRadius.circular(32) : BorderRadius.zero,
              boxShadow: desktop
                  ? const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: WaveBackground(dark: dark),
                    ),
                  ),
                ),
                SafeArea(bottom: false, child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}
