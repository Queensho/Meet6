import 'dart:math' as math;
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
                borderRadius: desktop ? BorderRadius.circular(32) : BorderRadius.zero,
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
                    child: LayoutBuilder(
                      builder: (context, phone) {
                        final w = phone.maxWidth;
                        final h = phone.maxHeight;
                        final compact = h < 720;
                        final horizontal = (w * .05).clamp(16.0, 22.0);

                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            compact ? 8 : 12,
                            horizontal,
                            14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Brand(width: w),
                              SizedBox(height: compact ? 9 : 13),
                              _Headline(width: w),
                              const SizedBox(height: 4),
                              Text(
                                '6 kişilik çevrende yeni insanlarla\nsohbet etmeye başla.',
                                style: TextStyle(
                                  color: Meet6App.muted,
                                  fontSize: (w * .034).clamp(12.0, 14.0),
                                  height: 1.32,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: compact ? 4 : 7),
                              _PeopleOrbit(compact: compact),
                              SizedBox(height: compact ? 6 : 10),
                              Row(
                                children: [
                                  const _CountryCode(),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: compact ? 48 : 52,
                                      child: TextField(
                                        controller: phoneController,
                                        keyboardType: TextInputType.phone,
                                        onChanged: (_) => setState(() {}),
                                        style: const TextStyle(
                                          color: Meet6App.navy,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '5XX XXX XX XX',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFFADB1C3),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(.8),
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
                              const SizedBox(height: 7),
                              const Row(
                                children: [
                                  Icon(Icons.lock_outline_rounded,
                                      color: Meet6App.blue, size: 16),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Numaran diğer kullanıcılara gösterilmez.',
                                      style: TextStyle(
                                        color: Meet6App.muted,
                                        fontSize: 11.3,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: compact ? 9 : 12),
                              SizedBox(
                                width: double.infinity,
                                height: compact ? 48 : 52,
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
                                      Text(
                                        'Devam et',
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      SizedBox(width: 9),
                                      Icon(Icons.arrow_forward_rounded, size: 22),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 9 : 12),
                              const _OrDivider(),
                              SizedBox(height: compact ? 9 : 12),
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
                                      icon: const Icon(
                                        Icons.apple_rounded,
                                        color: Colors.white,
                                        size: 23,
                                      ),
                                      label: 'Apple',
                                      onTap: () => demo('Apple ile devam et'),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: compact ? 9 : 12),
                              const _LegalText(),
                            ],
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

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
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
          fontSize: (width * .098).clamp(32.0, 40.0),
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
          fontSize: (width * .059).clamp(20.0, 24.0),
          height: 1.08,
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

class _PeopleOrbit extends StatelessWidget {
  const _PeopleOrbit({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final orbitHeight = math.min(
          compact ? 190.0 : 215.0,
          w * (compact ? .56 : .61),
        );
        final avatar = (w * .145).clamp(48.0, 60.0);
        final center = (w * .19).clamp(64.0, 76.0);

        return SizedBox(
          height: orbitHeight,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: ConnectionPainter()),
              ),
              _CenterSix(size: center),
              Positioned(
                top: 1,
                left: (w - avatar) / 2,
                child: _AvatarTile(index: 0, size: avatar),
              ),
              Positioned(
                top: orbitHeight * .23,
                left: w * .05,
                child: _AvatarTile(index: 1, size: avatar),
              ),
              Positioned(
                top: orbitHeight * .21,
                right: w * .05,
                child: _AvatarTile(index: 2, size: avatar),
              ),
              Positioned(
                bottom: orbitHeight * .14,
                left: w * .07,
                child: _AvatarTile(index: 3, size: avatar),
              ),
              Positioned(
                bottom: orbitHeight * .14,
                right: w * .07,
                child: _AvatarTile(index: 4, size: avatar),
              ),
              Positioned(
                bottom: 1,
                left: (w - avatar) / 2,
                child: _AvatarTile(index: 5, size: avatar),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CenterSix extends StatelessWidget {
  const _CenterSix({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Meet6App.lime,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '6',
        style: TextStyle(
          color: Meet6App.navy,
          fontSize: size * .52,
          fontWeight: FontWeight.w900,
          letterSpacing: -2,
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({required this.index, required this.size});
  final int index;
  final double size;

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
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icons[index],
        size: size * .45,
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Meet6App.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇹🇷', style: TextStyle(fontSize: 16)),
          SizedBox(width: 5),
          Text(
            '+90',
            style: TextStyle(
              color: Meet6App.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: Meet6App.muted),
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
          child: Text(
            'veya',
            style: TextStyle(
              color: Meet6App.muted,
              fontSize: 12,
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
                  fontSize: 13,
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
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
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
          fontSize: 10.3,
          height: 1.35,
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
    );
  }
}

class ConnectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Meet6App.blue.withOpacity(.72)
      ..strokeWidth = 1.35
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = Meet6App.blue;
    final center = Offset(size.width / 2, size.height / 2);
    final points = [
      Offset(size.width / 2, size.height * .13),
      Offset(size.width * .16, size.height * .34),
      Offset(size.width * .84, size.height * .33),
      Offset(size.width * .18, size.height * .72),
      Offset(size.width * .82, size.height * .72),
      Offset(size.width / 2, size.height * .88),
    ];

    for (final p in points) {
      canvas.drawLine(center, p, paint);
      canvas.drawCircle(
        Offset((center.dx + p.dx) / 2, (center.dy + p.dy) / 2),
        2.8,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
