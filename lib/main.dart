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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, page) {
          final desktop = page.maxWidth > 500;
          return Container(
            color: desktop ? const Color(0xFFEFF1F7) : Meet6App.background,
            alignment: Alignment.center,
            child: Container(
              width: desktop ? 390 : double.infinity,
              height: desktop ? 844 : double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Meet6App.background,
                borderRadius: desktop ? BorderRadius.circular(32) : BorderRadius.zero,
                boxShadow: desktop
                    ? const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        )
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Brand(),
                          const SizedBox(height: 14),
                          const _Headline(),
                          const SizedBox(height: 5),
                          const Text(
                            '6 kişilik çevrende yeni insanlarla\nsohbet etmeye başla.',
                            style: TextStyle(
                              color: Meet6App.muted,
                              fontSize: 13.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const _PeopleOrbit(),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const _CountryCode(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: TextField(
                                    controller: phoneController,
                                    keyboardType: TextInputType.phone,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(
                                      color: Meet6App.navy,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15.5,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '5XX XXX XX XX',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFFADB1C3),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(.78),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                                      border: _fieldBorder(Meet6App.border),
                                      enabledBorder: _fieldBorder(Meet6App.border),
                                      focusedBorder: _fieldBorder(Meet6App.blue, width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  color: Meet6App.blue, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Numaran diğer kullanıcılara gösterilmez.',
                                style: TextStyle(
                                  color: Meet6App.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: canContinue
                                  ? () => demo('Doğrulama kodu gönderilecek')
                                  : null,
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
                                  Text('Devam et',
                                      style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900)),
                                  SizedBox(width: 9),
                                  Icon(Icons.arrow_forward_rounded, size: 22),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _OrDivider(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _ProviderButton(
                                  background: const Color(0xFFF1F3FA),
                                  foreground: Meet6App.navy,
                                  border: Meet6App.border,
                                  icon: const _GoogleMark(),
                                  label: 'Google',
                                  onTap: () => demo('Google ile devam et'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ProviderButton(
                                  background: Meet6App.navy,
                                  foreground: Colors.white,
                                  border: Meet6App.navy,
                                  icon: const Icon(Icons.apple_rounded,
                                      color: Colors.white, size: 23),
                                  label: 'Apple',
                                  onTap: () => demo('Apple ile devam et'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const _LegalText(),
                        ],
                      ),
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

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
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
          fontSize: 38,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -2,
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
          fontSize: 23,
          height: 1.08,
          fontWeight: FontWeight.w900,
          letterSpacing: -.5,
        ),
        children: [
          TextSpan(text: 'Yeni insanlarla\n', style: TextStyle(color: Meet6App.navy)),
          TextSpan(text: 'gerçek bağlantılar kur', style: TextStyle(color: Meet6App.blue)),
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
      height: 250,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: CustomPaint(painter: ConnectionPainter())),
              const _CenterSix(),
              Positioned(top: 3, left: w * .39, child: const _AvatarTile(index: 0)),
              const Positioned(top: 50, left: 2, child: _AvatarTile(index: 1)),
              const Positioned(top: 46, right: 2, child: _AvatarTile(index: 2)),
              const Positioned(bottom: 35, left: 8, child: _AvatarTile(index: 3)),
              const Positioned(bottom: 35, right: 8, child: _AvatarTile(index: 4)),
              Positioned(bottom: 0, left: w * .39, child: const _AvatarTile(index: 5)),
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
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        color: Meet6App.lime,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text('6',
          style: TextStyle(
              color: Meet6App.navy,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: -2)),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({required this.index});

  final int index;

  static const colors = [
    Meet6App.blue,
    Meet6App.lime,
    Color(0xFFF0F1F7),
    Meet6App.blue,
    Meet6App.lime,
    Color(0xFFF0F1F7),
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
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Icon(
        icons[index],
        size: 33,
        color: color == Meet6App.blue ? Colors.white : Meet6App.navy,
      ),
    );
  }
}

class _CountryCode extends StatelessWidget {
  const _CountryCode();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Meet6App.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇹🇷', style: TextStyle(fontSize: 17)),
          SizedBox(width: 6),
          Text('+90',
              style: TextStyle(
                  color: Meet6App.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w900)),
          SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Meet6App.muted),
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
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('veya',
              style: TextStyle(
                  color: Meet6App.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
        Expanded(child: Divider(color: Meet6App.border)),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
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
    return const Text('G',
        style: TextStyle(
            color: Color(0xFF4285F4),
            fontSize: 20,
            fontWeight: FontWeight.w900));
  }
}

class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: TextStyle(
          color: Meet6App.muted,
          fontSize: 10.5,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(text: 'Devam ederek '),
          TextSpan(
              text: 'Kullanım Koşulları',
              style: TextStyle(color: Meet6App.blue, fontWeight: FontWeight.w800)),
          TextSpan(text: ' ve '),
          TextSpan(
              text: 'Gizlilik Politikası',
              style: TextStyle(color: Meet6App.blue, fontWeight: FontWeight.w800)),
          TextSpan(text: '’nı kabul etmiş olursun.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class ConnectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Meet6App.blue.withOpacity(.78)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    final points = [
      Offset(size.width / 2, 38),
      const Offset(48, 83),
      Offset(size.width - 48, 83),
      Offset(50, size.height - 62),
      Offset(size.width - 50, size.height - 62),
      Offset(size.width / 2, size.height - 32),
    ];
    for (final p in points) {
      canvas.drawLine(center, p, paint);
      canvas.drawCircle(Offset((center.dx + p.dx) / 2, (center.dy + p.dy) / 2),
          3.2, Paint()..color = Meet6App.blue);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WavePainter extends CustomPainter {
  const WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lime = Paint()
      ..color = Meet6App.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    final blue = Paint()
      ..color = Meet6App.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    final blob = Paint()..color = const Color(0xFFF0F1F8);

    canvas.drawCircle(Offset(size.width * .96, size.height * .28), 82, blob);
    canvas.drawCircle(Offset(size.width * .04, size.height * .53), 64, blob);

    final top = Path()
      ..moveTo(size.width * .64, -10)
      ..cubicTo(size.width * .72, 18, size.width * .68, 48, size.width * .79, 72)
      ..cubicTo(size.width * .88, 94, size.width * .82, 126, size.width * 1.03, 145);
    canvas.drawPath(top, lime);

    final bottom = Path()
      ..moveTo(-18, size.height - 48)
      ..cubicTo(22, size.height - 72, 48, size.height - 18, 86, size.height - 26)
      ..cubicTo(122, size.height - 34, 142, size.height + 12, 185, size.height + 2);
    canvas.drawPath(bottom, blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
