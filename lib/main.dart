import 'package:flutter/material.dart';

void main() => runApp(const Meet6App());

class Meet6App extends StatelessWidget {
  const Meet6App({super.key});

  static const background = Color(0xFFF8F9FD);
  static const navy = Color(0xFF111B4C);
  static const blue = Color(0xFF2F5BFF);
  static const lime = Color(0xFFD8FF32);
  static const muted = Color(0xFF9298B0);
  static const border = Color(0xFFD9DDEA);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meet6',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
      ),
      home: const LoginScreen(),
    );
  }
}

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

  void demo(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, viewport) {
          final desktop = viewport.maxWidth > 520;
          final phoneWidth = desktop ? 390.0 : viewport.maxWidth;
          final phoneHeight = desktop ? 844.0 : viewport.maxHeight;

          return Container(
            color: desktop ? const Color(0xFFEFF1F7) : Meet6App.background,
            alignment: Alignment.center,
            child: Container(
              width: phoneWidth,
              height: phoneHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Meet6App.background,
                borderRadius:
                    desktop ? BorderRadius.circular(32) : BorderRadius.zero,
                boxShadow: desktop
                    ? const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: WavePainter()),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: LayoutBuilder(
                      builder: (context, phone) {
                        final w = phone.maxWidth;
                        final h = phone.maxHeight;

                        // Only the phone width controls compact sizing.
                        // The keyboard changes height, so it can no longer
                        // shrink the hero image or the rest of the UI.
                        final veryCompact = w < 340;
                        final compact = w < 375;
                        final horizontal = (w * .045).clamp(14.0, 19.0);
                        final verticalTop = compact ? 7.0 : 10.0;
                        final minContentHeight =
                            (h - verticalTop - 2).clamp(0.0, double.infinity);

                        return SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            verticalTop,
                            horizontal,
                            2,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: minContentHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Brand(width: w),
                                  SizedBox(height: compact ? 7 : 10),
                                  _Headline(width: w),
                                  const SizedBox(height: 3),
                                  Text(
                                    '6 kişilik çevrende yeni insanlarla\nsohbet etmeye başla.',
                                    style: TextStyle(
                                      color: Meet6App.muted,
                                      fontSize:
                                          (w * .033).clamp(11.8, 13.5),
                                      height: 1.28,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 3 : 5),
                                  _HeroPng(
                                    width: w,
                                    compact: compact,
                                    veryCompact: veryCompact,
                                  ),
                                  const Spacer(),
                                  _BottomLoginArea(
                                    compact: compact,
                                    veryCompact: veryCompact,
                                    canContinue: canContinue,
                                    phoneController: phoneController,
                                    onChanged: () => setState(() {}),
                                    onContinue: () => demo(
                                      'Doğrulama kodu gönderilecek',
                                    ),
                                    onGoogle: () =>
                                        demo('Google ile devam et'),
                                    onApple: () =>
                                        demo('Apple ile devam et'),
                                    fieldBorder: _fieldBorder,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BottomLoginArea extends StatelessWidget {
  const _BottomLoginArea({
    required this.compact,
    required this.veryCompact,
    required this.canContinue,
    required this.phoneController,
    required this.onChanged,
    required this.onContinue,
    required this.onGoogle,
    required this.onApple,
    required this.fieldBorder,
  });

  final bool compact;
  final bool veryCompact;
  final bool canContinue;
  final TextEditingController phoneController;
  final VoidCallback onChanged;
  final VoidCallback onContinue;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final OutlineInputBorder Function(Color color, {double width}) fieldBorder;

  @override
  Widget build(BuildContext context) {
    final fieldHeight = veryCompact ? 44.0 : (compact ? 47.0 : 51.0);
    final providerHeight = veryCompact ? 42.0 : (compact ? 45.0 : 48.0);
    final gap = veryCompact ? 5.0 : (compact ? 7.0 : 9.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox(height: fieldHeight, child: const _CountryCode()),
            const SizedBox(width: 7),
            Expanded(
              child: SizedBox(
                height: fieldHeight,
                child: TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => onChanged(),
                  style: const TextStyle(
                    color: Meet6App.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '5XX XXX XX XX',
                    hintStyle: const TextStyle(
                      color: Color(0xFFADB1C3),
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(.84),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 13),
                    border: fieldBorder(Meet6App.border),
                    enabledBorder: fieldBorder(Meet6App.border),
                    focusedBorder:
                        fieldBorder(Meet6App.blue, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap - 1),
        const Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: Meet6App.blue,
              size: 15,
            ),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Numaran diğer kullanıcılara gösterilmez.',
                style: TextStyle(
                  color: Meet6App.muted,
                  fontSize: 10.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        SizedBox(
          width: double.infinity,
          height: fieldHeight,
          child: FilledButton(
            onPressed: canContinue ? onContinue : null,
            style: FilledButton.styleFrom(
              backgroundColor: Meet6App.lime,
              disabledBackgroundColor: const Color(0xFFE8F3AE),
              disabledForegroundColor: Meet6App.navy.withOpacity(.48),
              foregroundColor: Meet6App.navy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Devam et',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 21),
              ],
            ),
          ),
        ),
        SizedBox(height: gap),
        const _OrDivider(),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _ProviderButton(
                height: providerHeight,
                background: const Color(0xFFF1F3FA),
                foreground: Meet6App.navy,
                border: Meet6App.border,
                icon: const _GoogleMark(),
                label: 'Google',
                onTap: onGoogle,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _ProviderButton(
                height: providerHeight,
                background: Meet6App.navy,
                foreground: Colors.white,
                border: Meet6App.navy,
                icon: const Icon(
                  Icons.apple_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                label: 'Apple',
                onTap: onApple,
              ),
            ),
          ],
        ),
        SizedBox(height: veryCompact ? 4 : 6),
        const _LegalText(),
        SizedBox(height: veryCompact ? 1 : 2),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: (width * .094).clamp(31.0, 38.0),
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -2,
        ),
        children: const [
          TextSpan(text: 'meet', style: TextStyle(color: Meet6App.navy)),
          TextSpan(text: '6', style: TextStyle(color: Meet6App.blue)),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: (width * .057).clamp(19.5, 23.5),
          height: 1.07,
          fontWeight: FontWeight.w900,
          letterSpacing: -.5,
        ),
        children: const [
          TextSpan(
            text: 'Yeni insanlarla\n',
            style: TextStyle(color: Meet6App.navy),
          ),
          TextSpan(
            text: 'gerçek bağlantılar kur',
            style: TextStyle(color: Meet6App.blue),
          ),
        ],
      ),
    );
  }
}

class _HeroPng extends StatelessWidget {
  const _HeroPng({
    required this.width,
    required this.compact,
    required this.veryCompact,
  });

  final double width;
  final bool compact;
  final bool veryCompact;

  @override
  Widget build(BuildContext context) {
    // Fixed by width, never by the keyboard-reduced viewport height.
    final heroHeight = (width * .67).clamp(220.0, 276.0);
    final scale = veryCompact ? 1.08 : (compact ? 1.14 : 1.20);

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: ClipRect(
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: Image.asset(
              'assets/images/file_000000009c248210b0e425b8f2d3e68d.png',
              width: width,
              height: heroHeight,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryCode extends StatelessWidget {
  const _CountryCode();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.84),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Meet6App.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇹🇷', style: TextStyle(fontSize: 15)),
          SizedBox(width: 5),
          Text(
            '+90',
            style: TextStyle(
              color: Meet6App.navy,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: 1),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: Meet6App.muted,
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Meet6App.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'veya',
            style: TextStyle(
              color: Meet6App.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: Meet6App.border)),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.height,
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double height;
  final Color background;
  final Color foreground;
  final Color border;
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 19,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            color: Meet6App.muted,
            fontSize: 9.7,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
          children: [
            TextSpan(text: 'Devam ederek '),
            TextSpan(
              text: 'Kullanım Koşulları',
              style: TextStyle(
                color: Meet6App.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: ' ve '),
            TextSpan(
              text: 'Gizlilik Politikası',
              style: TextStyle(
                color: Meet6App.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: '’nı kabul etmiş olursun.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  const WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.width * .06).clamp(18.0, 26.0);
    final lime = Paint()
      ..color = Meet6App.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final blue = Paint()
      ..color = Meet6App.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final blob = Paint()..color = const Color(0xFFF0F1F8);

    canvas.drawCircle(
      Offset(size.width * .98, size.height * .28),
      size.width * .20,
      blob,
    );
    canvas.drawCircle(
      Offset(size.width * .02, size.height * .53),
      size.width * .16,
      blob,
    );

    final top = Path()
      ..moveTo(size.width * .64, -10)
      ..cubicTo(
        size.width * .72,
        size.height * .02,
        size.width * .68,
        size.height * .06,
        size.width * .79,
        size.height * .09,
      )
      ..cubicTo(
        size.width * .88,
        size.height * .12,
        size.width * .82,
        size.height * .15,
        size.width * 1.04,
        size.height * .18,
      );
    canvas.drawPath(top, lime);

    final bottom = Path()
      ..moveTo(-18, size.height - size.height * .055)
      ..cubicTo(
        size.width * .06,
        size.height - size.height * .09,
        size.width * .13,
        size.height - size.height * .02,
        size.width * .23,
        size.height - size.height * .03,
      )
      ..cubicTo(
        size.width * .33,
        size.height - size.height * .04,
        size.width * .38,
        size.height + 12,
        size.width * .49,
        size.height + 2,
      );
    canvas.drawPath(bottom, blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
