import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/password_auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/back_button.dart';
import '../widgets/brand.dart';
import '../widgets/phone_frame.dart';
import '../widgets/primary_button.dart';
import 'profile/profile_setup_screen.dart';

class RegisterPasswordScreen extends StatefulWidget {
  const RegisterPasswordScreen({
    super.key,
    required this.phoneNumber,
  });

  final String phoneNumber;

  @override
  State<RegisterPasswordScreen> createState() => _RegisterPasswordScreenState();
}

class _RegisterPasswordScreenState extends State<RegisterPasswordScreen> {
  final passwordController = TextEditingController();
  final repeatController = TextEditingController();
  bool hidePassword = true;
  bool hideRepeat = true;
  bool submitting = false;

  bool get valid =>
      !submitting &&
      passwordController.text.length >= 8 &&
      passwordController.text == repeatController.text;

  @override
  void dispose() {
    passwordController.dispose();
    repeatController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!valid) return;
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    try {
      final result = await PasswordAuthService.register(
        phone: widget.phoneNumber,
        password: passwordController.text,
      );
      await SessionService.saveAuth(
        sessionId: result.sessionId,
        userId: result.userId,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt oluşturulamadı. Tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  InputDecoration _decoration(String label, bool hidden, VoidCallback toggle) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        onPressed: toggle,
        icon: Icon(hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded),
      ),
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? AppColors.lime : AppColors.blue, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: PhoneFrame(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Meet6BackButton(
                      onTap: submitting ? null : () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    const Meet6MiniBrand(),
                  ],
                ),
                const SizedBox(height: 38),
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.password_rounded, color: AppColors.navy, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'Şifreni oluştur',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.phoneNumber} numarası için en az 8 karakterli bir şifre belirle.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: _decoration(
                    'Şifre',
                    hidePassword,
                    () => setState(() => hidePassword = !hidePassword),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: repeatController,
                  obscureText: hideRepeat,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (valid) _register();
                  },
                  decoration: _decoration(
                    'Şifre tekrar',
                    hideRepeat,
                    () => setState(() => hideRepeat = !hideRepeat),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      passwordController.text.length >= 8
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: passwordController.text.length >= 8
                          ? Colors.green
                          : scheme.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        passwordController.text.isNotEmpty && repeatController.text.isNotEmpty && passwordController.text != repeatController.text
                            ? 'Şifreler aynı olmalı.'
                            : 'Şifre en az 8 karakter olmalı.',
                        style: TextStyle(
                          color: passwordController.text.isNotEmpty && repeatController.text.isNotEmpty && passwordController.text != repeatController.text
                              ? Colors.redAccent
                              : scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: submitting ? 'Kayıt oluşturuluyor...' : 'Kayıt ol',
                  onPressed: valid ? _register : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
