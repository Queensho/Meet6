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

class _XpRewardsSheetState extends State<XpRewardsSheet> {
  static const int _maxLevel = 30;

  static const List<Map<String, dynamic>> _fallbackRewards = [
    {
      'rewardKey': 'lv2_coins',
      'level': 2,
      'rewardType': 'coins',
      'amount': 25,
      'title': '25 jeton',
      'cosmeticCode': null,
    },
    {
      'rewardKey': 'lv3_frame',
      'level': 3,
      'rewardType': 'frame',
      'amount': 0,
      'title': 'Lime profil çerçevesi',
      'cosmeticCode': 'frame_lime',
    },
    {
      'rewardKey': 'lv5_coins',
      'level': 5,
      'rewardType': 'coins',
      'amount': 75,
      'title': '75 jeton',
      'cosmeticCode': null,
    },
    {
      'rewardKey': 'lv5_badge',
      'level': 5,
      'rewardType': 'badge',
      'amount': 0,
      'title': 'Yükselen rozet',
      'cosmeticCode': 'badge_rising',
    },
    {
      'rewardKey': 'lv7_premium',
      'level': 7,
      'rewardType': 'premium_days',
      'amount': 1,
      'title': '1 günlük Premium',
      'cosmeticCode': null,
    },
    {
      'rewardKey': 'lv10_premium',
      'level': 10,
      'rewardType': 'premium_days',
      'amount': 3,
      'title': '3 günlük Premium',
      'cosmeticCode': null,
    },
    {
      'rewardKey': 'lv10_frame',
      'level': 10,
      'rewardType': 'frame',
      'amount': 0,
      'title': 'Neon profil çerçevesi',
      'cosmeticCode': 'frame_neon',
    },
    {
      'rewardKey': 'lv12_coins',
      'level': 12,
      'rewardType': 'coins',
      'amount': 150,
      'title': '150 jeton',
      'cosmeticCode': null,
    },
    {
      'rewardKey': 'lv15_premium',
      'level': 15,
      'rewardType': 'premium_days',
      'amount': 7,
      'title': '7 günlük Premium',
      'cosmeticCode': null,
    },
    {
      'rewardKey': 'lv18_badge',
      'level': 18,
      'rewardType': 'badge',
      'amount': 0,
      'title': 'Animasyonlu yıldız rozeti',
      'cosmeticCode': 'badge_animated_star',
    },
    {
      'rewardKey': 'lv20_coins',
      'level': 20,
      'rewardType': 'coins',
      'amount': 300,
      'title': '300 jeton',
      'cosmeticCode': null,
    },
    {
      'rewardKey': 'lv20_frame',
      'level': 20,
      'rewardType': 'frame',
      'amount': 0,
      'title': 'Elite profil çerçevesi',
      'cosmeticCode': 'frame_elite',
    },
    {
      'rewardKey': 'lv25_premium',
      'level': 25,
      'rewardType': 'premium_days',
      'amount': 7,
      'title': '7 günlük Premium',
      'cosmeticCode': null,
    },
    {
      'rewardKey': 'lv30_badge',
      'level': 30,
      'rewardType': 'badge',
      'amount': 0,
      'title': 'Meet6 Elite rozeti',
      'cosmeticCode': 'badge_meet6_elite',
    },
    {
      'rewardKey': 'lv30_effect',
      'level': 30,
      'rewardType': 'effect',
      'amount': 0,
      'title': 'Elite oda efekti',
      'cosmeticCode': 'effect_elite_room',
    },
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

  List<Map<String, dynamic>> _rewardsFrom(
    Map<String, dynamic> rewardsInfo,
  ) {
    final rawList = rewardsInfo['rewards'];
    final fromApi = rawList is List
        ? rawList
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    if (fromApi.isNotEmpty) return fromApi;
    return _fallbackRewards
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _groupRewards(
    List<Map<String, dynamic>> rewards,
    int currentLevel,
  ) {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final reward in rewards) {
      final level = (reward['level'] as num?)?.toInt() ?? 1;
      grouped.putIfAbsent(level, () => []).add(reward);
    }

    final levels = grouped.keys.toList()..sort();
    return levels.map((level) {
      final items = grouped[level] ?? const <Map<String, dynamic>>[];
      final unlockedByLevel = currentLevel >= level;
      final unlocked = unlockedByLevel ||
          items.any((item) => item['unlocked'] == true);
      final claimed = items.isNotEmpty &&
          items.every((item) => item['claimed'] == true);
      return <String, dynamic>{
        'level': level,
        'items': items,
        'unlocked': unlocked,
        'claimed': claimed,
      };
    }).toList(growable: false);
  }

  Widget _rewardCard({
    required BuildContext context,
    required Map<String, dynamic> group,
    required int xp,
    required bool isNext,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final rewardLevel = (group['level'] as num?)?.toInt() ?? 1;
    final itemsRaw = group['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final unlocked = group['unlocked'] == true;
    final claimed = group['claimed'] == true;
    final targetXp = _xpForLevel(rewardLevel);
    final remainingXp = targetXp > xp ? targetXp - xp : 0;
    final progress = targetXp <= 0
        ? 1.0
        : (xp / targetXp).clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).round();
    final titles = items
        .map((item) => item['title']?.toString().trim() ?? '')
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
    final firstType = items.isEmpty
        ? ''
        : items.first['rewardType']?.toString() ?? '';

    String status;
    if (claimed) {
      status = 'Alındı';
    } else if (unlocked) {
      status = 'Açıldı';
    } else if (isNext) {
      status = 'Sıradaki';
    } else {
      status = 'Yakında';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isNext
            ? AppColors.lime.withValues(alpha: .10)
            : unlocked
                ? AppColors.lime.withValues(alpha: .055)
                : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: isNext
              ? AppColors.lime
              : unlocked
                  ? AppColors.lime.withValues(alpha: .42)
                  : scheme.outlineVariant,
          width: isNext ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: unlocked || isNext
                      ? AppColors.lime
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  items.length > 1
                      ? Icons.redeem_rounded
                      : _rewardIcon(firstType),
                  color: unlocked || isNext
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
                          'Lv $rewardLevel',
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
                      titles.isEmpty ? 'Meet6 seviye ödülü' : titles.join(' + '),
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
                  color: claimed
                      ? AppColors.lime.withValues(alpha: .18)
                      : isNext
                          ? AppColors.lime
                          : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: claimed || isNext
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
                  unlocked
                      ? 'Bu seviye açıldı.'
                      : '${_format(remainingXp)} XP kaldı',
                  style: TextStyle(
                    color: unlocked
                        ? AppColors.lime
                        : scheme.onSurfaceVariant,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                unlocked ? '100%' : '%$percent',
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
            final progress = nextXp == null
                ? 1.0
                : ((xp - currentStart) / (nextXp - currentStart))
                    .clamp(0.0, 1.0)
                    .toDouble();
            final nextLevelRemaining = nextXp == null ? 0 : nextXp - xp;

            final rewards = _rewardsFrom(rewardsInfo);
            final groups = _groupRewards(rewards, level);
            final nextRewardLevel = groups
                .where((group) => group['unlocked'] != true)
                .map((group) => (group['level'] as num?)?.toInt() ?? 1)
                .fold<int?>(null, (current, candidate) {
              if (current == null || candidate < current) return candidate;
              return current;
            });

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
                                  : '${_format(xp)} XP · Lv ${level + 1} için ${_format(nextLevelRemaining)} XP kaldı',
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
                      value: progress,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: AppColors.lime,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'XP kazandıkça jeton, profil ödülleri ve ücretsiz Premium açılır. Hediye kaynaklı Meet6 XP günlük 100 XP ile sınırlıdır.',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11.2,
                              height: 1.35,
                              fontWeight: FontWeight.w650,
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
                      if (nextRewardLevel != null)
                        Text(
                          'Sıradaki Lv $nextRewardLevel',
                          style: const TextStyle(
                            color: AppColors.lime,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  ...groups.map((group) {
                    final rewardLevel =
                        (group['level'] as num?)?.toInt() ?? 1;
                    return _rewardCard(
                      context: context,
                      group: group,
                      xp: xp,
                      isNext: nextRewardLevel == rewardLevel,
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
