import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/gift_service.dart';
import '../../../theme/app_colors.dart';
import '../../premium/premium_profile_card.dart';

class ProfileHero extends StatefulWidget {
  const ProfileHero({
    super.key,
    required this.name,
    this.imageUrl = '',
  });

  final String name;
  final String imageUrl;

  @override
  State<ProfileHero> createState() => _ProfileHeroState();
}

class _ProfileHeroState extends State<ProfileHero> {
  late final Future<Map<String, dynamic>> _giftSummary = GiftService.me();

  String get initial {
    final value = widget.name.trim();
    return value.isEmpty ? 'S' : value.characters.first.toUpperCase();
  }

  String _formatXp(int value) {
    final raw = math.max(0, value).toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write('.');
      out.write(raw[i]);
    }
    return out.toString();
  }

  int _profileLevel(int xp) {
    final safeXp = math.max(0, xp);
    return math.min(20, 1 + math.sqrt(safeXp / 50).floor());
  }

  Widget _xpBadge() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _giftSummary,
      builder: (context, snapshot) {
        final raw = snapshot.data?['summary'];
        final summary = raw is Map
            ? Map<String, dynamic>.from(raw)
            : const <String, dynamic>{};
        final giftXp = (summary['giftXp'] as num?)?.toInt() ?? 0;
        final generosityXp = (summary['generosityXp'] as num?)?.toInt() ?? 0;
        final totalXp = giftXp + generosityXp;
        final level = _profileLevel(totalXp);

        return Semantics(
          label: 'Seviye $level, ${_formatXp(totalXp)} XP',
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-.18, -.28),
                radius: 1.05,
                colors: [
                  Color(0xFF1D2B4D),
                  Color(0xFF07142F),
                ],
              ),
              border: Border.all(color: AppColors.navy, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.lime.withValues(alpha: .85),
                  width: 1.7,
                ),
              ),
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(
                      child: SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.lime,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Lv ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: '$level',
                                style: const TextStyle(
                                  color: AppColors.lime,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatXp(totalXp)} XP',
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 8.3,
                            height: 1,
                            letterSpacing: .15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _avatar(String resolvedImage) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 132,
          height: 132,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.lime,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.navy.withValues(alpha: .72),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x32000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: resolvedImage.isNotEmpty
                  ? Image.network(
                      resolvedImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _Fallback(initial: initial),
                    )
                  : _Fallback(initial: initial),
            ),
          ),
        ),
        Positioned(
          right: 7,
          bottom: 8,
          child: Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: const Color(0xFF2ED66B),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedImage = ApiService.absoluteMediaUrl(widget.imageUrl);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 184,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(34),
              bottomRight: Radius.circular(34),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -55,
                right: -48,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.navy.withValues(alpha: .08),
                      width: 26,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -38,
                bottom: -64,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.blue.withValues(alpha: .08),
                      width: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -58,
          child: SizedBox(
            width: 282,
            height: 136,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                _avatar(resolvedImage),
                const Positioned(
                  left: 17,
                  top: 29,
                  child: PremiumProfileCard(),
                ),
                Positioned(
                  right: 17,
                  top: 29,
                  child: _xpBadge(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.lime,
          fontSize: 42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
