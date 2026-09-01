import 'package:flutter/material.dart';

void main() => runApp(const Meet6App());

class Meet6App extends StatelessWidget {
  const Meet6App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meet6',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B63E6),
          brightness: Brightness.light,
        ),
      ),
      home: const EntryScreen(),
    );
  }
}

class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  void _showDemo(BuildContext context, String text) {
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const _HeroArea(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Tanışmanın yeni yolu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            color: Color(0xFF171717),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '6 kişi, 15 dakika, serbest sohbet.\nSohbetin sonunda gizli seçimini yap.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.45,
                            color: Color(0xFF777777),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _PrimaryEntryButton(
                          label: 'E-posta ile devam et',
                          icon: Icons.mail_outline_rounded,
                          dark: true,
                          onTap: () => _showDemo(context, 'E-posta ile kayıt / giriş'),
                        ),
                        const SizedBox(height: 12),
                        _PrimaryEntryButton(
                          label: 'Telefon numarasıyla devam et',
                          icon: Icons.phone_iphone_rounded,
                          onTap: () => _showDemo(context, 'Telefon ile kayıt / giriş'),
                        ),
                        const SizedBox(height: 22),
                        const _OrDivider(),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _SocialSquareButton(
                                icon: Icons.apple_rounded,
                                semantics: 'Apple',
                                onTap: () => _showDemo(context, 'Apple ile devam et'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SocialSquareButton(
                                icon: Icons.g_mobiledata_rounded,
                                semantics: 'Google',
                                onTap: () => _showDemo(context, 'Google ile devam et'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Zaten hesabın var mı?',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF777777),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _showDemo(context, 'Giriş yap'),
                              child: const Text(
                                'Giriş yap',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Devam ederek Kullanım Koşulları ve Gizlilik Politikası’nı kabul etmiş olursun.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: Color(0xFFA0A0A0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroArea extends StatelessWidget {
  const _HeroArea();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 370,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFCDEEFF),
            Color(0xFFE9D4FF),
            Color(0xFFFFD9E5),
          ],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -48,
            top: 40,
            child: _BlurBubble(size: 150, color: Color(0x33FFFFFF)),
          ),
          Positioned(
            right: -20,
            bottom: 42,
            child: _BlurBubble(size: 120, color: Color(0x26FFFFFF)),
          ),
          Center(
            child: SizedBox(
              width: 310,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: const [
                  _OrbitRing(size: 238),
                  _OrbitRing(size: 168),
                  _Meet6Mark(),
                  Positioned(top: 4, left: 118, child: _FloatingIcon(icon: Icons.favorite_rounded, tint: Color(0xFFFF647C))),
                  Positioned(top: 52, right: 17, child: _FloatingIcon(icon: Icons.location_on_rounded, tint: Color(0xFFFF6F7F))),
                  Positioned(bottom: 58, right: 9, child: _FloatingIcon(icon: Icons.chat_bubble_rounded, tint: Color(0xFF59A6FF))),
                  Positioned(bottom: 2, left: 120, child: _FloatingIcon(icon: Icons.timer_rounded, tint: Color(0xFF8B63E6))),
                  Positioned(bottom: 62, left: 10, child: _FloatingIcon(icon: Icons.groups_2_rounded, tint: Color(0xFF42CDBE))),
                  Positioned(top: 56, left: 14, child: _FloatingIcon(icon: Icons.auto_awesome_rounded, tint: Color(0xFFB66BFF))),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 18,
            left: 20,
            child: Text(
              'meet6',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
                color: Color(0xFF1B1730),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.68),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_rounded, size: 15, color: Color(0xFF6F5AE8)),
                  SizedBox(width: 5),
                  Text(
                    '6 kişi',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meet6Mark extends StatelessWidget {
  const _Meet6Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(31),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'M',
              style: TextStyle(
                color: Color(0xFF1D1930),
                fontSize: 46,
                fontWeight: FontWeight.w900,
                letterSpacing: -4,
              ),
            ),
            TextSpan(
              text: '6',
              style: TextStyle(
                color: Color(0xFF8B63E6),
                fontSize: 46,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.9),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: tint, size: 28),
    );
  }
}

class _OrbitRing extends StatelessWidget {
  const _OrbitRing({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          width: 1.4,
          color: Colors.white.withOpacity(.58),
        ),
      ),
    );
  }
}

class _BlurBubble extends StatelessWidget {
  const _BlurBubble({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PrimaryEntryButton extends StatelessWidget {
  const _PrimaryEntryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.dark = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: dark ? const Color(0xFF202223) : const Color(0xFFF7F7F7),
          foregroundColor: dark ? Colors.white : const Color(0xFF202020),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: dark
                ? BorderSide.none
                : const BorderSide(color: Color(0xFFECECEC)),
          ),
        ),
      ),
    );
  }
}

class _SocialSquareButton extends StatelessWidget {
  const _SocialSquareButton({
    required this.icon,
    required this.semantics,
    required this.onTap,
  });

  final IconData icon;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      button: true,
      child: SizedBox(
        height: 58,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFF8F8F8),
            side: const BorderSide(color: Color(0xFFEEEEEE)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Icon(icon, size: 30, color: const Color(0xFF171717)),
        ),
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
        Expanded(child: Divider(color: Color(0xFFE8E8E8))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'veya',
            style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE8E8E8))),
      ],
    );
  }
}
