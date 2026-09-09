import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/gift_service.dart';
import '../../../theme/app_colors.dart';

class XpRewardsSheet extends StatefulWidget {
  const XpRewardsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const XpRewardsSheet(),
    );
  }

  @override
  State<XpRewardsSheet> createState() => _XpRewardsSheetState();
}

class _RewardItem {
  const _RewardItem({
    required this.level,
    required this.type,
    required this.title,
    required this.unlocked,
    required this.claimed,
  });

  final int level;
  final String type;
  final String title;
  final bool unlocked;
  final bool claimed;
}

class _RewardGroup {
  const _RewardGroup({required this.level, required this.items});

  final int level;
  final List<_RewardItem> items;

  bool get unlocked => items.any((item) => item.unlocked);
  bool get claimed => items.isNotEmpty && items.every((item) => item.claimed);
}

class _XpRewardsSheetState extends State<XpRewardsSheet> {
  static const int _maxLevel = 30;

  static const List<(int, String, String)> _fallbackRewards = [
    (2, 'coins', '25 jeton'),
    (3, 'frame', 'Lime profil çerçevesi'),
    (5, 'coins', '75 jeton'),
    (5, 'badge', 'Yükselen rozet'),
    (7, 'premium_days', '1 günlük Premium'),
    (10, 'premium_days', '3 günlük Premium'),
    (10, 'frame', 'Neon profil çerçevesi'),
    (12, 'coins', '150 jeton'),
    (15, 'premium_days', '7 günlük Premium'),
    (18, 'badge', 'Animasyonlu yıldız rozeti'),
    (20, 'coins', '300 jeton'),
    (20, 'frame', 'Elite profil çerçevesi'),
    (25, 'premium_days', '7 günlük Premium'),
    (30, 'badge', 'Meet6 Elite rozeti'),
    (30, 'effect', 'Elite oda efekti'),
  ];

  late Future<Map<String, dynamic>> _future = GiftService.me();

  String _format(int value) {
    final raw = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write('.');
      out.write(raw[i]);
    }
    return out.toString();
  }

  int _xpForLevel(int level) {
    if (level <= 1) return 0;
    final offset = level - 1;
    return 50 * offset * offset;
  }

  int _levelFromXp(int xp) {
    var level = 1;
    for (var candidate = 2; candidate <= _maxLevel; candidate++) {
      if (xp < _xpForLevel(candidate)) break;
      level = candidate;
    }
    return level;
  }

  IconData _rewardIcon(String type) {
    switch (type) {
      case 'coins':
        return Icons.monetization_on_rounded;
      case 'premium_days':
        return Icons.workspace_premium_rounded;
      case 'frame':
        return Icons.account_circle_rounded;
      case 'effect':
        return Icons.auto_awesome_rounded;
      case 'badge':
        return Icons.military_tech_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }

  List<_RewardItem> _rewardItems(
    Map<String, dynamic> rewardsInfo,
    int currentLevel,
  ) {
    final raw = rewardsInfo['rewards'];
    if (raw is List && raw.isNotEmpty) {
      return raw.whereType<Map>().map((value) {
        final item = Map<String, dynamic>.from(value);
        final rewardLevel = (item['level'] as num?)?.toInt() ?? 1;
        return _RewardItem(
          level: rewardLevel,
          type: item['rewardType']?.toString() ?? '',
          title: item['title']?.toString().trim().isNotEmpty == true
              ? item['title'].toString().trim()
              : 'Meet6 seviye ödülü',
          unlocked: item['unlocked'] == true || currentLevel >= rewardLevel,
          claimed: item['claimed'] == true,
        );
      }).toList(growable: false);
    }

    return _fallbackRewards.map((reward) {
      return _RewardItem(
        level: reward.$1,
        type: reward.$2,
        title: reward.$3,
        unlocked: currentLevel >= reward.$1,
        claimed: false,
      );
    }).toList(growable: false);
  }

  List<_RewardGroup> _groupRewards(List<_RewardItem> rewards) {
    final grouped = <int, List<_RewardItem>>{};
    for (final reward in rewards) {
      grouped.putIfAbsent(reward.level, () => []).add(reward);
    }
    final levels = grouped.keys.toList()..sort();
    return levels
        .map((level) => _RewardGroup(level: level, items: grouped[level]!))
        .toList(growable: false);
  }

  _RewardGroup? _nextReward(List<_RewardGroup> groups) {
    for (final group in groups) {
      if (!group.unlocked) return group;
    }
    return null;
  }

  Widget _rewardCard(
    BuildContext context,
    _RewardGroup group,
    int xp,
    bool isNext,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final targetXp = _xpForLevel(group.level);
    final remaining = targetXp > xp ? targetXp - xp : 0;
    final progress = targetXp <= 0
        ? 1.0
        : (xp / targetXp).clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).round();
    final title = group.items.map((item) => item.title).join(' + ');
    final icon = group.items.length > 1
        ? Icons.redeem_rounded
        : _rewardIcon(group.items.first.type);

    final status = group.claimed
        ? 'Alındı'
        : group.unlocked
            ? 'Açıldı'
            : isNext
                ? 'Sıradaki'
                : 'Yakında';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isNext
            ? AppColors.lime.withValues(alpha: .10)
            : group.unlocked
                ? AppColors.lime.withValues(alpha: .05)
                : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: isNext
              ? AppColors.lime
              : group.unlocked
                  ? AppColors.lime.withValues(alpha: .40)
                  : scheme.outlineVariant,
          width: isNext ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: group.unlocked || isNext
                      ? AppColors.lime
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: group.unlocked || isNext
                      ? AppColors.navy
                      : scheme.onSurfaceVariant,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Lv ${group.level}',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '${_format(targetXp)} XP',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 13,
                        height: 1.22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: isNext
                      ? AppColors.lime
                      : group.claimed
                          ? AppColors.lime.withValues(alpha: .18)
                          : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isNext || group.claimed
                        ? AppColors.navy
                        : scheme.onSurfaceVariant,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              color: AppColors.lime,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  group.unlocked
                      ? 'Bu seviye açıldı.'
                      : '${_format(remaining)} XP kaldı',
                  style: TextStyle(
                    color: group.unlocked
                        ? AppColors.lime
                        : scheme.onSurfaceVariant,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                group.unlocked ? '100%' : '%$percent',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .86,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 320,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.lime),
                ),
              );
            }

            if (snapshot.hasError) {
              final message = snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : 'XP bilgileri alınamadı.';
              return SizedBox(
                height: 320,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              setState(() => _future = GiftService.me()),
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final data = snapshot.data ?? const <String, dynamic>{};
            final summaryRaw = data['summary'];
            final rewardsRaw = data['xpRewards'];
            final summary = summaryRaw is Map
                ? Map<String, dynamic>.from(summaryRaw)
                : const <String, dynamic>{};
            final rewardsInfo = rewardsRaw is Map
                ? Map<String, dynamic>.from(rewardsRaw)
                : const <String, dynamic>{};

            final xp = (summary['profileXp'] as num?)?.toInt() ?? 0;
            final computedLevel = _levelFromXp(xp);
            final apiLevel = (summary['profileLevel'] as num?)?.toInt();
            final level = apiLevel != null && apiLevel >= 1 && apiLevel <= _maxLevel
                ? apiLevel
                : computedLevel;
            final isMaxLevel = level >= _maxLevel;
            final apiNextXp = (summary['nextLevelXp'] as num?)?.toInt();
            final nextXp = isMaxLevel
                ? null
                : (apiNextXp != null && apiNextXp > xp
                    ? apiNextXp
                    : _xpForLevel(level + 1));
            final currentStart = _xpForLevel(level);
            final levelProgress = nextXp == null
                ? 1.0
                : ((xp - currentStart) / (nextXp - currentStart))
                    .clamp(0.0, 1.0)
                    .toDouble();
            final levelRemaining = nextXp == null ? 0 : nextXp - xp;

            final groups = _groupRewards(_rewardItems(rewardsInfo, level));
            final nextReward = _nextReward(groups);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.navy,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          'Lv $level',
                          style: const TextStyle(
                            color: AppColors.lime,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Meet6 Seviyesi',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              nextXp == null
                                  ? '${_format(xp)} XP · Maksimum seviye'
                                  : '${_format(xp)} XP · Lv ${level + 1} için ${_format(levelRemaining)} XP kaldı',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: levelProgress,
                      color: AppColors.lime,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  if (nextXp != null) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Text(
                          'Lv $level',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_format(xp)} / ${_format(nextXp)} XP',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Lv ${level + 1}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 13),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.bolt_rounded, color: AppColors.lime, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'XP kazandıkça jeton, profil ödülleri ve ücretsiz Premium açılır. Hediye kaynaklı Meet6 XP günlük 100 XP ile sınırlıdır.',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11.2,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text(
                        'Seviye ödülleri',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      if (nextReward != null)
                        Text(
                          'Sıradaki Lv ${nextReward.level}',
                          style: const TextStyle(
                            color: AppColors.lime,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  ...groups.map(
                    (group) => _rewardCard(
                      context,
                      group,
                      xp,
                      nextReward?.level == group.level,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
