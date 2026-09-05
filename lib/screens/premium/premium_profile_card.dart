import 'package:flutter/material.dart';

import '../../services/premium_subscription_service.dart';
import '../../theme/app_colors.dart';
import 'premium_screen.dart';

class PremiumProfileCard extends StatefulWidget {
  const PremiumProfileCard({super.key});

  @override
  State<PremiumProfileCard> createState() => _PremiumProfileCardState();
}

class _PremiumProfileCardState extends State<PremiumProfileCard> {
  bool _loading = true;
  bool _premium = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await PremiumSubscriptionService.status();
      if (!mounted) return;
      setState(() {
        _premium = status.premium;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openPremium() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC94A);
    const muted = Color(0xFF9AA4B8);
    final accent = _premium ? gold : muted;

    return Semantics(
      button: true,
      label: _premium
          ? 'Meet6 Premium aktif. Premium üyeliğini yönet.'
          : 'Meet6 Premium özelliklerini görüntüle.',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: _loading ? null : _openPremium,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-.2, -.28),
                radius: 1.05,
                colors: [
                  Color(0xFF1A294B),
                  Color(0xFF09142C),
                ],
              ),
              border: Border.all(color: accent, width: 2.2),
              boxShadow: [
                const BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 7),
                ),
                if (_premium)
                  const BoxShadow(
                    color: Color(0x44FFC94A),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.lime,
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(30, 25),
                        painter: _CrownPainter(color: accent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PREMIUM',
                        style: TextStyle(
                          color: accent,
                          fontSize: 8.3,
                          height: 1,
                          letterSpacing: .45,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final crown = Path()
      ..moveTo(size.width * .08, size.height * .28)
      ..lineTo(size.width * .29, size.height * .56)
      ..lineTo(size.width * .49, size.height * .17)
      ..lineTo(size.width * .70, size.height * .56)
      ..lineTo(size.width * .92, size.height * .28)
      ..lineTo(size.width * .80, size.height * .78)
      ..lineTo(size.width * .20, size.height * .78)
      ..close();
    canvas.drawPath(crown, paint);

    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .19,
        size.height * .74,
        size.width * .62,
        size.height * .14,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(band, paint);

    final jewelPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: .74)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * .5, size.height * .58),
      size.width * .045,
      jewelPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => oldDelegate.color != color;
}
