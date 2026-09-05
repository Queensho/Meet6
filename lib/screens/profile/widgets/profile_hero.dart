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

  Widget _giftLevels() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _giftSummary,
      builder: (context, snapshot) {
        final raw = snapshot.data?['summary'];
        if (raw is! Map) return const SizedBox.shrink();
        final summary = Map<String, dynamic>.from(raw);
        final giftLevel = summary['giftLevel'] ?? 1;
        final generosityLevel = summary['generosityLevel'] ?? 1;
        final badges = summary['badges'];
        final firstBadge = badges is List && badges.isNotEmpty ? badges.first.toString() : null;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: .2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎁 Lv $giftLevel  ·  ✨ Lv $generosityLevel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (firstBadge != null) ...[
                const SizedBox(width: 7),
                Container(width: 1, height: 12, color: Colors.white24),
                const SizedBox(width: 7),
                Text(
                  firstBadge,
                  style: const TextStyle(
                    color: AppColors.lime,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
              const Positioned(
                top: 18,
                left: 0,
                right: 0,
                child: Center(child: PremiumProfileCard()),
              ),
              Positioned(
                top: 58,
                left: 12,
                right: 12,
                child: Center(child: _giftLevels()),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -58,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 116,
                height: 116,
                padding: const EdgeInsets.all(5),
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
              Positioned(
                right: 2,
                bottom: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                ),
              ),
            ],
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
