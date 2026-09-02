import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class Meet6BackButton extends StatelessWidget {
  const Meet6BackButton({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.navy,
        ),
      ),
    );
  }
}
