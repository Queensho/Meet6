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
                  onSubmitted: (_) {
                    if (enabled) onContinue();
                  },
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
            Expanded(
              child: Text(
                'Numaran diğer kullanıcılara gösterilmez.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
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
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
              const TextSpan(text: ' ve '),
              TextSpan(
                text: 'Gizlilik Politikası',
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
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
