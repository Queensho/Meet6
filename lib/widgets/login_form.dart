import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'primary_button.dart';

class LoginForm extends StatelessWidget {
  const LoginForm({
    super.key,
    required this.controller,
    required this.enabled,
    required this.legalAccepted,
    required this.onChanged,
    required this.onLegalAcceptedChanged,
    required this.onOpenLegal,
    required this.onContinue,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool legalAccepted;
  final VoidCallback onChanged;
  final ValueChanged<bool> onLegalAcceptedChanged;
  final VoidCallback onOpenLegal;
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
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              checked: legalAccepted,
              button: true,
              label: 'KVKK ve kullanım şartları onayı',
              child: InkWell(
                onTap: () => onLegalAcceptedChanged(!legalAccepted),
                borderRadius: BorderRadius.circular(7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    color: legalAccepted ? AppColors.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: legalAccepted ? AppColors.blue : scheme.outline,
                      width: 1.6,
                    ),
                  ),
                  child: legalAccepted
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 17,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => onLegalAcceptedChanged(!legalAccepted),
                    child: Text(
                      'KVKK Aydınlatma Metni’ni okudum; Kullanım Şartları ve 18+ kuralını kabul ediyorum.',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 10.7,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: onOpenLegal,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        'KVKK ve yasal metinleri görüntüle',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
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
      ],
    );
  }
}
