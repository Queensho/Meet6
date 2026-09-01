import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime : Colors.white.withOpacity(.82),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.navy,
                size: 17,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration meet6InputDecoration({
  required String hint,
  required IconData icon,
  IconData? suffix,
}) {
  OutlineInputBorder border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: Color(0xFFA8ADC1),
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
    prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
    suffixIcon: suffix == null
        ? null
        : Icon(suffix, color: AppColors.muted, size: 21),
    filled: true,
    fillColor: Colors.white.withOpacity(.86),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.blue, width: 1.5),
    border: border(AppColors.border),
  );
}
