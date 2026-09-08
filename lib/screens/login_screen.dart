import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/password_auth_service.dart';
import '../services/realtime_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand.dart';
import '../widgets/login_hero.dart';
import '../widgets/phone_frame.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_mode_switch.dart';
import 'otp_screen.dart';
import 'profile/settings/legal_screen.dart';
import 'register_password_screen.dart';
import 'session_gate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool registerMode = false;
  bool submitting = false;
  bool legalAccepted = false;
  bool hidePassword = true;

  bool get validPhone =>
      phoneController.text.replaceAll(RegExp(r'[^0-9]'), '').length >= 10;

  bool get canSubmit =>
      !submitting &&
      validPhone &&
      (registerMode ? legalAccepted : passwordController.text.length >= 8);

  @override
  void initState() {
    super.initState();
    RealtimeService.disconnect();
    SessionService.clear();
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!canSubmit) return;
    FocusScope.of(context).unfocus();

    if (registerMode) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RegisterPasswordScreen(
            phoneNumber: phoneController.text,
          ),
        ),
      );
      return;
    }

    setState(() => submitting = true);
    try {
      final result = await PasswordAuthService.login(
        phone: phoneController.text,
        password: passwordController.text,
      );
      await SessionService.saveAuth(
        sessionId: result.sessionId,
        userId: result.userId,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SessionGate()),
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
        const SnackBar(content: Text('Giriş yapılamadı. Tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> _loginWithOtp() async {
    if (!validPhone || submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    try {
      await ApiService.requestOtp(phoneController.text);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(phoneNumber: phoneController.text),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP gönderilemedi. Tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _openLegal() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LegalScreen()),
    );
  }

  InputDecoration _fieldDecoration({
    required BuildContext context,
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? AppColors.lime : AppColors.blue;
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    );
  }

  Widget _phoneField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          alignment: Alignment.center,
          child: const Row(
            children: [
              Text('🇹🇷', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text('+90', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 54,
            child: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              textInputAction:
                  registerMode ? TextInputAction.done : TextInputAction.next,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (registerMode && canSubmit) _submit();
              },
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
              decoration: _fieldDecoration(
                context: context,
                hint: '5XX XXX XX XX',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeTabs(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final selectedBg = dark ? AppColors.lime : AppColors.navy;
    final selectedFg = dark ? AppColors.navy : Colors.white;

    Widget tab(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: submitting ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? selectedFg : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          tab('Giriş Yap', !registerMode, () {
            setState(() => registerMode = false);
          }),
          tab('Kayıt Ol', registerMode, () {
            setState(() => registerMode = true);
          }),
        ],
      ),
    );
  }

  Widget _legal(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => legalAccepted = !legalAccepted),
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
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
                : null,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => legalAccepted = !legalAccepted),
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
                onTap: _openLegal,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: PhoneFrame(
        child: LayoutBuilder(
          builder: (context, phone) {
            final w = phone.maxWidth;
            final h = phone.maxHeight;
            final horizontal = (w * .045).clamp(14.0, 19.0);

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (h - 18).clamp(0.0, double.infinity),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Meet6Brand(width: w)),
                        const ThemeModeSwitch(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: (w * .057).clamp(19.5, 23.5),
                          height: 1.07,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.5,
                        ),
                        children: [
                          TextSpan(
                            text: registerMode ? 'Meet6’ya katıl\n' : 'Tekrar hoş geldin\n',
                            style: TextStyle(color: scheme.onSurface),
                          ),
                          TextSpan(
                            text: registerMode
                                ? 'gerçek bağlantılar kur'
                                : 'sohbete kaldığın yerden devam et',
                            style: TextStyle(
                              color: dark ? AppColors.lime : AppColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      registerMode
                          ? 'Telefon numaranı gir, sonraki adımda şifreni oluştur.'
                          : 'Kayıtlı telefon numaran ve şifrenle giriş yap.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: (w * .033).clamp(11.8, 13.5),
                        height: 1.28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    LoginHero(width: w),
                    const SizedBox(height: 8),
                    _modeTabs(context),
                    const SizedBox(height: 12),
                    _phoneField(context),
                    if (!registerMode) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: passwordController,
                        obscureText: hidePassword,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (canSubmit) _submit();
                        },
                        decoration: _fieldDecoration(
                          context: context,
                          hint: 'Şifre',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => hidePassword = !hidePassword),
                            icon: Icon(
                              hidePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      _legal(context),
                    ],
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: submitting
                          ? (registerMode ? 'Hazırlanıyor...' : 'Giriş yapılıyor...')
                          : (registerMode ? 'Devam et' : 'Giriş yap'),
                      height: 52,
                      onPressed: canSubmit ? _submit : null,
                    ),
                    if (!registerMode) ...[
                      const SizedBox(height: 7),
                      Center(
                        child: TextButton.icon(
                          onPressed: validPhone && !submitting ? _loginWithOtp : null,
                          icon: const Icon(Icons.sms_outlined, size: 18),
                          label: const Text(
                            'OTP ile giriş yap',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'Eski hesabında şifre yoksa OTP ile giriş yapabilirsin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: dark ? AppColors.lime : AppColors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Telefon numaran diğer kullanıcılara gösterilmez.',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
