import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'wave_background.dart';

class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) {
        final desktop = viewport.maxWidth > 520;
        return Container(
          color: desktop ? const Color(0xFFEFF1F7) : AppColors.background,
          alignment: Alignment.center,
          child: Container(
            width: desktop ? 390 : viewport.maxWidth,
            height: desktop ? 844 : viewport.maxHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius:
                  desktop ? BorderRadius.circular(32) : BorderRadius.zero,
              boxShadow: desktop
                  ? const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: WaveBackground()),
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
