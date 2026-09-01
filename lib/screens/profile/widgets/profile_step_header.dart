import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/back_button.dart';
import '../../../widgets/brand.dart';

class ProfileStepHeader extends StatelessWidget {
  const ProfileStepHeader({
    super.key,
    required this.step,
    required this.onBack,
  });

  final int step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Meet6BackButton(onTap: onBack),
            const Spacer(),
            const Meet6MiniBrand(),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: List.generate(3, (index) {
            final active = index < step;
            return Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(right: index < 2 ? 7 : 0),
                decoration: BoxDecoration(
                  color: active ? AppColors.blue : AppColors.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Profil oluştur · $step/3',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
