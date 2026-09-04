import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import '../services/runtime_app_config_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.config,
  });

  final RuntimeAppConfig config;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  static const _avatars = [
    'assets/images/Avatar1.png',
    'assets/images/Avatar2.png',
    'assets/images/Avatar3.png',
    'assets/images/Avatar4.png',
    'assets/images/Avatar5.png',
    'assets/images/Avatar6.png',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await OnboardingService.markCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _next() {
    if (_page >= 2) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomMinutes = widget.config.roomDurationMinutes;
    final extensionMinutes = widget.config.extensionMinutes;
    final selectionSeconds = widget.config.selectionSeconds;
    final minimumUsers = widget.config.minimumUsers;

    final pages = <Widget>[
      _OnboardingPage(
        eyebrow: 'MEET6 ODALARI',
        title: '$minimumUsers kişi. $roomMinutes dakika.\nGerçek sohbet.',
        description:
            'Kaydırmalı profil yok. Uygun $minimumUsers kişi aynı canlı odaya girer, $roomMinutes dakika boyunca birlikte sohbet eder.',
        visual: _RoomVisual(avatars: _avatars),
      ),
      _OnboardingPage(
        eyebrow: 'GİZLİ SEÇİM',
        title: 'Sohbet biter.\nSeçimin sana kalır.',
        description:
            'Oda sonunda $selectionSeconds saniyelik gizli seçim başlar. İstersen sohbeti +$extensionMinutes dakika uzatmak için oy kullanabilirsin.',
        visual: const _SelectionVisual(),
      ),
      const _OnboardingPage(
        eyebrow: 'KARŞILIKLI EŞLEŞME',
        title: 'İkiniz de seçerseniz\nsohbet devam eder.',
        description:
            'Seçim karşılıklıysa eşleşme oluşur ve özel mesajlaşma açılır. Tek taraflı seçim diğer kullanıcıya gösterilmez.',
        visual: _MatchVisual(),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 14, 0),
              child: Row(
                children: [
                  const Meet6MiniBrand(height: 25),
                  const Spacer(),
                  TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: const Text(
                      'Atla',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => _page = value),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final selected = index == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: selected ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.blue : AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _finishing ? null : _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _finishing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.lime,
                              ),
                            )
                          : Text(
                              _page == 2 ? 'Meet6’ya başla' : 'Devam et',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.visual,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 300,
            width: double.infinity,
            child: visual,
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              eyebrow,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 34,
              height: 1.03,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomVisual extends StatelessWidget {
  const _RoomVisual({required this.avatars});

  final List<String> avatars;

  static const _positions = [
    Alignment(-.72, -.72),
    Alignment(.02, -.94),
    Alignment(.72, -.64),
    Alignment(-.78, .40),
    Alignment(.02, .84),
    Alignment(.78, .38),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 238,
          height: 238,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
        ),
        Container(
          width: 164,
          height: 164,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.lime,
            border: Border.all(color: AppColors.navy, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withOpacity(.14),
                blurRadius: 38,
                spreadRadius: 8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '6',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 88,
              height: .9,
              fontWeight: FontWeight.w900,
              letterSpacing: -7,
            ),
          ),
        ),
        for (var i = 0; i < avatars.length; i++)
          Align(
            alignment: _positions[i],
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withOpacity(.14),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  avatars[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: AppColors.softSurface,
                    child: Icon(Icons.person_rounded, color: AppColors.muted),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectionVisual extends StatelessWidget {
  const _SelectionVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 330),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_rounded, color: AppColors.lime, size: 20),
                SizedBox(width: 7),
                Text(
                  'Gizli seçim',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _ChoiceBubble(icon: Icons.close_rounded, label: 'Geç'),
                _ChoiceBubble(icon: Icons.favorite_rounded, label: 'Seç'),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Seçimin karşı tarafa gösterilmez.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceBubble extends StatelessWidget {
  const _ChoiceBubble({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.blue, size: 34),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MatchVisual extends StatelessWidget {
  const _MatchVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 260,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withOpacity(.10),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            top: 38,
            child: _AvatarTile(asset: 'assets/images/Avatar2.png'),
          ),
          Positioned(
            right: 24,
            top: 38,
            child: _AvatarTile(asset: 'assets/images/Avatar5.png'),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.navy,
              size: 34,
            ),
          ),
          const Positioned(
            bottom: 24,
            child: Text(
              'Eşleşme oluştu',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.blue, width: 3),
      ),
      child: ClipOval(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: AppColors.softSurface,
            child: Icon(Icons.person_rounded, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}
