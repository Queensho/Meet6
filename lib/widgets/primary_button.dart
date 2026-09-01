import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.height = 56,
    this.dark = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final double height;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: dark ? AppColors.navy : AppColors.lime,
          foregroundColor: dark ? Colors.white : AppColors.navy,
          disabledBackgroundColor: AppColors.disabledLime,
          disabledForegroundColor: AppColors.navy.withOpacity(.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 23),
          ],
        ),
      ),
    );
  }
}
