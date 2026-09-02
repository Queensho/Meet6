import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'primary_button.dart';

class LoginForm extends StatelessWidget {
  const LoginForm({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onContinue,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onContinue;

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fieldColor = dark
        ? scheme.surfaceContainerHigh.withOpacity(.94)
        : Colors.white.withOpacity(.86);
    final borderColor = scheme.outlineVariant;
    final accent = dark ? AppColors.lime : AppColors.blue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Text('🇹🇷', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    '+90',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 52,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => onChanged(),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: '5XX XXX XX XX',
                    hintStyle: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: fieldColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    border: _border(borderColor),
                    enabledBorder: _border(borderColor),
                    focusedBorder: _border(accent, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: accent, size: 16),
            const SizedBox(width: 6),
            Text(
              'Numaran diğer kullanıcılara gösterilmez.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'Devam et',
          height: 52,
          onPressed: enabled ? onContinue : null,
        ),
        const SizedBox(height: 10),
        const _OrDivider(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ProviderButton(
                label: 'Google',
                background: dark
                    ? scheme.surfaceContainerHigh
                    : AppColors.softSurface,
                foreground: scheme.onSurface,
                border: borderColor,
                icon: const Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProviderButton(
                label: 'Apple',
                background: dark ? AppColors.lime : AppColors.navy,
                foreground: dark ? AppColors.navy : Colors.white,
                border: dark ? AppColors.lime : AppColors.navy,
                icon: Icon(
                  Icons.apple_rounded,
                  color: dark ? AppColors.navy : Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text.rich(
          TextSpan(
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 9.8,
              height: 1.25,
            ),
            children: [
              const TextSpan(text: 'Devam ederek '),
              TextSpan(
                text: 'Kullanım Koşulları',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const TextSpan(text: ' ve '),
              TextSpan(
                text: 'Gizlilik Politikası',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const TextSpan(text: '’nı kabul etmiş olursun.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'veya',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant)),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
