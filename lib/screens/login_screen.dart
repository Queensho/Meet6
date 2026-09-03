import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand.dart';
import '../widgets/login_form.dart';
import '../widgets/login_hero.dart';
import '../widgets/phone_frame.dart';
import '../widgets/theme_mode_switch.dart';
import 'otp_screen.dart';
import 'profile/settings/legal_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  bool submitting = false;

  bool get canContinue =>
      !submitting &&
      phoneController.text.replaceAll(RegExp(r'[^0-9]'), '').length >= 10;

  @override
  void initState() {
    super.initState();
    RealtimeService.disconnect();
    SessionService.clear();
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!canContinue) return;
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
        const SnackBar(content: Text('Sunucuya bağlanılamadı. Tekrar dene.')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PhoneFrame(
        child: LayoutBuilder(
          builder: (context, phone) {
            final w = phone.maxWidth;
            final h = phone.maxHeight;
            final horizontal = (w * .045).clamp(14.0, 19.0);

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 2),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (h - 10).clamp(0.0, double.infinity),
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
                    const SizedBox(height: 10),
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
                            text: 'Yeni insanlarla\n',
                            style: TextStyle(color: scheme.onSurface),
                          ),
                          TextSpan(
                            text: 'gerçek bağlantılar kur',
                            style: TextStyle(
                              color: dark ? AppColors.lime : AppColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '6 kişilik çevrende yeni insanlarla\nsohbet etmeye başla.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: (w * .033).clamp(11.8, 13.5),
                        height: 1.28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LoginHero(width: w),
                    const SizedBox(height: 6),
                    LoginForm(
                      controller: phoneController,
                      enabled: canContinue,
                      onChanged: () => setState(() {}),
                      onContinue: _continue,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: submitting ? null : _openLegal,
                        icon: const Icon(Icons.verified_user_outlined, size: 16),
                        label: const Text(
                          '18+ · Yasal & KVKK',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'Meet6 yalnızca 18 yaş ve üzeri kullanıcılar içindir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 9.8,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (submitting) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: dark ? AppColors.lime : AppColors.navy,
                          ),
                        ),
                      ),
                    ],
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
