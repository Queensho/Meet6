import 'package:flutter/material.dart';

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

  bool get canContinue =>
      phoneController.text.replaceAll(RegExp(r'[^0-9]'), '').length >= 10;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpScreen(phoneNumber: phoneController.text),
      ),
    );
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
