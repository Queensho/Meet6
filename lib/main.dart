import 'package:flutter/material.dart';

void main() => runApp(const Meet6App());

class Meet6App extends StatelessWidget {
  const Meet6App({super.key});

  static const background = Color(0xFFF7F8FC);
  static const navy = Color(0xFF111B4C);
  static const blue = Color(0xFF2F5BFF);
  static const lime = Color(0xFFD8FF32);
  static const softText = Color(0xFF9197B0);
  static const border = Color(0xFFD9DDEA);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meet6',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.light,
        ),
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

  bool get canContinue {
    final digits = phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10;
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  void _demo(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _WaveBackgroundPainter()),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 12, 26, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FakeStatusBar(),
                      const SizedBox(height: 28),
                      const _Brand(),
                      const SizedBox(height: 24),
                      const _Headline(),
                      const SizedBox(height: 8),
                      const Text(
                        '6 kişilik çevrende yeni insanlarla\nsohbet etmeye başla.',
                        style: TextStyle(
                          color: Meet6App.softText,
                          fontSize: 16,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _PeopleOrbit(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const _CountryCode(),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 62,
                              child: TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(
                                  color: Meet6App.navy,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                                decoration: InputDecoration(
                                  hintText: '5XX XXX XX XX',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFFADB1C3),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(.72),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(19),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(19),
                                    borderSide: const BorderSide(
                                      color: Meet6App.border,
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(19),
                                    borderSide: const BorderSide(
                                      color: Meet6App.blue,
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: Meet6App.blue,
                            size: 19,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Numaranı diğer kullanıcılara gösterilmez.',
                              style: TextStyle(
                                color: Meet6App.softText,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 62,
                        child: FilledButton(
                          onPressed: canContinue
                              ? () => _demo('Doğrulama kodu gönderilecek')
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Meet6App.lime,
                            disabledBackgroundColor: const Color(0xFFE6F3A7),
                            disabledForegroundColor: Meet6App.navy.withOpacity(.45),
                            foregroundColor: Meet6App.navy,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Devam et',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward_rounded, size: 26),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _OrDivider(),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _ProviderButton(
                              label: 'Google ile devam et',
                              background: const Color(0xFFF2F3FA),
                              foreground: Meet6App.navy,
                              borderColor: Meet6App.border,
                              leading: const _GoogleMark(),
                              onTap: () => _demo('Google ile devam et'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ProviderButton(
                              label: 'Apple ile devam et',
                              background: Meet6App.navy,
                              foreground: Colors.white,
                              borderColor: Meet6App.navy,
                              leading: const Icon(
                                Icons.apple_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              onTap: () => _demo('Apple ile devam et'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const _LegalText(),
                      const SizedBox(height: 22),
                      Center(
                        child: Container(
                          width: 126,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Meet6App.navy,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeStatusBar extends StatelessWidget {
  const _FakeStatusBar();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Text(
          '22:29',
          style: TextStyle(
            color: Meet6App.navy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Spacer(),
        Icon(Icons.signal_cellular_alt_rounded, size: 18, color: Meet6App.navy),
        SizedBox(width: 7),
        Icon(Icons.wifi_rounded, size: 18, color: Meet6App.navy),
        SizedBox(width: 7),
        _Battery(),
      ],
    );
  }
}

class _Battery extends StatelessWidget {
  const _Battery();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF3),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Text(
        '50',
        style: TextStyle(
          color: Meet6App.navy,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 46,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -2.4,
        ),
        children: [
          TextSpan(text: 'meet', style: TextStyle(color: Meet6App.navy)),
          TextSpan(text: '6', style: TextStyle(color: Meet6App.blue)),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 28,
          height: 1.12,
          fontWeight: FontWeight.w900,
          letterSpacing: -.8,
        ),
        children: [
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

class _PeopleOrbit extends StatelessWidget {
  const _PeopleOrbit();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 390,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _ConnectionPainter()),
              ),
              const _CenterSix(),
              Positioned(top: 12, left: w * .38, child: const _AvatarTile(index: 0)),
              Positioned(top: 88, left: 4, child: const _AvatarTile(index: 1)),
              Positioned(top: 78, right: 4, child: const _AvatarTile(index: 2)),
              Positioned(bottom: 58, left: 14, child: const _AvatarTile(index: 3)),
              Positioned(bottom: 62, right: 14, child: const _AvatarTile(index: 4)),
              Positioned(bottom: 4, left: w * .38, child: const _AvatarTile(index: 5)),
            ],
          );
        },
      ),
    );
  }
}

class _CenterSix extends StatelessWidget {
  const _CenterSix();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      decoration: const BoxDecoration(
        color: Meet6App.lime,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        '6',
        style: TextStyle(
          color: Meet6App.navy,
          fontSize: 68,
          fontWeight: FontWeight.w900,
          letterSpacing: -3,
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({required this.index});

  final int index;

  static const colors = [
    Meet6App.blue,
    Meet6App.lime,
    Color(0xFFF1F2F7),
    Meet6App.blue,
    Meet6App.lime,
    Color(0xFFF1F2F7),
  ];

  static const icons = [
    Icons.sentiment_very_satisfied_rounded,
    Icons.waving_hand_rounded,
    Icons.headphones_rounded,
    Icons.thumb_up_alt_rounded,
    Icons.auto_awesome_rounded,
    Icons.favorite_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final color = colors[index];
    final dark = color != Meet6App.blue;
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Icon(
        icons[index],
        size: 48,
        color: dark ? Meet6App.navy : Colors.white,
      ),
    );
  }
}

class _CountryCode extends StatelessWidget {
  const _CountryCode();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.72),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Meet6App.border, width: 1.2),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇹🇷', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text(
            '+90',
            style: TextStyle(
              color: Meet6App.navy,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          SizedBox(width: 5),
          Icon(Icons.keyboard_arrow_down_rounded, color: Meet6App.softText),
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
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'veya',
            style: TextStyle(
              color: Meet6App.softText,
              fontSize: 14,
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
    required this.label,
    required this.background,
    required this.foreground,
    required this.borderColor,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color borderColor;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13.5,
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

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
            Color(0xFF4285F4),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 15,
        height: 15,
        decoration: const BoxDecoration(
          color: Color(0xFFF2F3FA),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          'G',
          style: TextStyle(
            color: Meet6App.navy,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            color: Meet6App.softText,
            fontSize: 12,
            height: 1.5,
          ),
          children: const [
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
            TextSpan(text: '’nı\nkabul etmiş olursun.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ConnectionPainter extends CustomPainter {
  const _ConnectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 2);
    final line = Paint()
      ..color = Meet6App.blue.withOpacity(.9)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final dot = Paint()
      ..color = Meet6App.blue
      ..style = PaintingStyle.fill;

    final points = [
      Offset(size.width * .50, 66),
      Offset(69, 139),
      Offset(size.width - 69, 132),
      Offset(74, size.height - 105),
      Offset(size.width - 74, size.height - 104),
      Offset(size.width * .50, size.height - 56),
    ];

    for (final point in points) {
      canvas.drawLine(center, point, line);
      final mid = Offset(
        center.dx + (point.dx - center.dx) * .57,
        center.dy + (point.dy - center.dy) * .57,
      );
      canvas.drawCircle(mid, 5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WaveBackgroundPainter extends CustomPainter {
  const _WaveBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final soft = Paint()
      ..color = const Color(0xFFEFF1F8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * .98, size.height * .22), 125, soft);
    canvas.drawCircle(Offset(size.width * .02, size.height * .53), 95, soft);
    canvas.drawCircle(
      Offset(size.width * .93, size.height * .72),
      72,
      Paint()..color = const Color(0xFFF3F5DE),
    );

    final limePaint = Paint()
      ..color = Meet6App.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final topWave = Path()
      ..moveTo(size.width * .63, -24)
      ..cubicTo(
        size.width * .65,
        28,
        size.width * .64,
        55,
        size.width * .72,
        77,
      )
      ..cubicTo(
        size.width * .82,
        103,
        size.width * .78,
        146,
        size.width * .91,
        163,
      )
      ..cubicTo(
        size.width * 1.02,
        178,
        size.width * .95,
        217,
        size.width * 1.09,
        230,
      );

    canvas.drawPath(topWave, limePaint);

    final bluePaint = Paint()
      ..color = Meet6App.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bottomWave = Path()
      ..moveTo(-34, size.height - 88)
      ..cubicTo(
        20,
        size.height - 116,
        45,
        size.height - 46,
        89,
        size.height - 54,
      )
      ..cubicTo(
        137,
        size.height - 62,
        146,
        size.height - 9,
        196,
        size.height - 24,
      )
      ..cubicTo(
        235,
        size.height - 35,
        248,
        size.height + 3,
        285,
        size.height + 7,
      );

    canvas.drawPath(bottomWave, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
