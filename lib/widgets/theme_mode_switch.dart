import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';

class ThemeModeSwitch extends StatelessWidget {
  const ThemeModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Semantics(
      label: 'Tema seçimi',
      value: dark ? 'Karanlık' : 'Aydınlık',
      child: Container(
        width: 168,
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: dark
              ? scheme.surfaceContainerHigh.withOpacity(.96)
              : Colors.white.withOpacity(.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? .18 : .06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: dark ? Alignment.centerRight : Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: 79,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lime.withOpacity(.28),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _ThemeChoice(
                    icon: Icons.light_mode_rounded,
                    label: 'Aydınlık',
                    selected: !dark,
                    onTap: () => ThemeController.instance.setMode(ThemeMode.light),
                  ),
                ),
                Expanded(
                  child: _ThemeChoice(
                    icon: Icons.dark_mode_rounded,
                    label: 'Karanlık',
                    selected: dark,
                    onTap: () => ThemeController.instance.setMode(ThemeMode.dark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? AppColors.navy : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.navy : scheme.onSurfaceVariant,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
