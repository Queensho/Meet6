import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.lime : scheme.outlineVariant,
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
                color: selected ? AppColors.navy : scheme.onSurface,
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
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20),
    suffixIcon: suffix == null ? null : Icon(suffix, size: 21),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
  );
}
