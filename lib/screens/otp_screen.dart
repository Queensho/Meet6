import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/back_button.dart';
import '../widgets/brand.dart';
import '../widgets/phone_frame.dart';
import '../widgets/primary_button.dart';
import 'profile/profile_setup_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final controllers = List.generate(6, (_) => TextEditingController());
  final focusNodes = List.generate(6, (_) => FocusNode());
  Timer? timer;
  int secondsLeft = 45;

  bool get complete => controllers.every((c) => c.text.length == 1);

  String get formattedPhone {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) return '+90 ${widget.phoneNumber}';
    final d = digits.substring(digits.length - 10);
    return '+90 ${d.substring(0, 3)} ${d.substring(3, 6)} '
        '${d.substring(6, 8)} ${d.substring(8, 10)}';
  }

  @override
  void initState() {
    super.initState();
    _restartTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final controller in controllers) {
      controller.dispose();
    }
    for (final node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _restartTimer() {
    timer?.cancel();
    secondsLeft = 45;
    timer = Timer.periodic(const Duration(seconds: 1), (value) {
      if (!mounted) return;
      if (secondsLeft <= 1) {
        value.cancel();
        setState(() => secondsLeft = 0);
      } else {
        setState(() => secondsLeft--);
      }
    });
    if (mounted) setState(() {});
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }
    setState(() {});
    if (complete) FocusScope.of(context).unfocus();
  }

  void _verify() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
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
            final horizontal = (w * .055).clamp(18.0, 24.0);
            final compact = w < 375;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (h - 22).clamp(0.0, double.infinity),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Meet6BackButton(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        const Meet6MiniBrand(),
                      ],
                    ),
                    SizedBox(height: compact ? 38 : 52),
                    Center(
                      child: Container(
                        width: compact ? 102 : 116,
                        height: compact ? 102 : 116,
                        decoration: const BoxDecoration(
                          color: AppColors.lime,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: AppColors.navy,
                          size: 50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Telefonunu doğrula',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: (w * .075).clamp(25.0, 31.0),
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '$formattedPhone numarasına gönderdiğimiz\n6 haneli kodu gir.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: (w * .036).clamp(13.0, 15.0),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 38),
                      ),
                      child: const Text(
                        'Numarayı değiştir',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        final width =
                            ((w - horizontal * 2 - 35) / 6).clamp(43.0, 52.0);
                        return SizedBox(
                          width: width,
                          height: 60,
                          child: TextField(
                            controller: controllers[index],
                            focusNode: focusNodes[index],
                            maxLength: 1,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) => _onDigitChanged(index, value),
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white.withOpacity(.9),
                              contentPadding: EdgeInsets.zero,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: AppColors.blue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: secondsLeft > 0
                          ? Text(
                              'Kodu tekrar gönderebilirsin  00:${secondsLeft.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : TextButton(
                              onPressed: _restartTimer,
                              child: const Text(
                                'Kodu tekrar gönder',
                                style: TextStyle(
                                  color: AppColors.blue,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 34),
                    PrimaryButton(
                      label: 'Doğrula',
                      onPressed: complete ? _verify : null,
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
