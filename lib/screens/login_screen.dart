import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand.dart';
import '../widgets/login_form.dart';
import '../widgets/login_hero.dart';
import '../widgets/phone_frame.dart';
import 'otp_screen.dart';

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

  @override
  Widget build(BuildContext context) {
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
                    Meet6Brand(width: w),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: (w * .057).clamp(19.5, 23.5),
                          height: 1.07,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.5,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Yeni insanlarla\n',
                            style: TextStyle(color: AppColors.navy),
                          ),
                          TextSpan(
                            text: 'gerçek bağlantılar kur',
                            style: TextStyle(color: AppColors.blue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '6 kişilik çevrende yeni insanlarla\nsohbet etmeye başla.',
                      style: TextStyle(
                        color: AppColors.muted,
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
                    if (submitting) ...[
                      const SizedBox(height: 10),
                      const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.navy,
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
