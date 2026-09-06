import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/gift_service.dart';
import '../../../services/premium_subscription_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/xp_level_ring.dart';
import '../../premium/premium_screen.dart';
import 'xp_rewards_sheet.dart';

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
  late Future<PremiumStatus> _premiumStatus;

  @override
  void initState() {
    super.initState();
    _premiumStatus = PremiumSubscriptionService.status();
  }

  String get initial {
    final value = widget.name.trim();
    return value.isEmpty ? 'S' : value.characters.first.toUpperCase();
  }

  int _profileLevel(int xp) {
    final safeXp = math.max(0, xp);
    return math.min(30, 1 + math.sqrt(safeXp / 50).floor());
  }

  Future<void> _openPremium() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
    if (!mounted) return;
    setState(() {
      _premiumStatus = PremiumSubscriptionService.status();
    });
  }

  Widget _xpBadge() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _giftSummary,
      builder: (context, snapshot) {
        final raw = snapshot.data?['summary'];
        final summary = raw is Map
            ? Map<String, dynamic>.from(raw)
            : const <String, dynamic>{};
        final totalXp = (summary['profileXp'] as num?)?.toInt() ?? 0;
        final level =
            (summary['profileLevel'] as num?)?.toInt() ?? _profileLevel(totalXp);

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 58,
            height: 58,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: AppColors.lime,
                ),
              ),
            ),
          );
        }

        return XpLevelRing(
          level: level,
          totalXp: totalXp,
          size: 58,
          onTap: () => XpRewardsSheet.show(context),
        );
      },
    );
  }

  Widget _premiumBadge() {
    return FutureBuilder<PremiumStatus>(
      future: _premiumStatus,
      builder: (context, snapshot) {
        final premium = snapshot.data?.premium == true;
        return Semantics(
          button: true,
          label: premium
              ? 'Meet6 Premium üyeliğini görüntüle.'
              : 'Meet6 Premium satın alma ekranını aç.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openPremium,
            child: Image.asset(
              premium
                  ? 'assets/images/premium_badge.png'
                  : 'assets/images/Premiumpasif.png',
              width: 92,
              height: 76,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
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
            width: 310,
            height: 150,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                _avatar(resolvedImage),
                Positioned(
                  left: 28,
                  top: 37,
                  child: _premiumBadge(),
                ),
                Positioned(
                  right: 28,
                  top: 37,
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
