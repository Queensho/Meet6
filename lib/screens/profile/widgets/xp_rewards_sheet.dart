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
      default:
        return Icons.military_tech_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
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
                          onPressed: () => setState(() => _future = GiftService.me()),
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
            final level = (summary['profileLevel'] as num?)?.toInt() ?? 1;
            final nextXp = (summary['nextLevelXp'] as num?)?.toInt();
            final currentStart = level <= 1 ? 0 : 50 * (level - 1) * (level - 1);
            final progress = nextXp == null
                ? 1.0
                : ((xp - currentStart) / (nextXp - currentStart))
                    .clamp(0.0, 1.0)
                    .toDouble();
            final rawList = rewardsInfo['rewards'];
            final rewards = rawList is List
                ? rawList
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList(growable: false)
                : const <Map<String, dynamic>>[];

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
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
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.navy,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          'Lv $level',
                          style: const TextStyle(
                            color: AppColors.lime,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                  : '${_format(xp)} / ${_format(nextXp)} XP',
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
                      minHeight: 9,
                      value: progress,
                      color: AppColors.lime,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'XP kazandıkça jeton, profil ödülleri ve ücretsiz Premium açılır. Hediye kaynaklı Meet6 XP günlük 100 XP ile sınırlıdır.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Seviye ödülleri',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...rewards.map((reward) {
                    final rewardLevel = (reward['level'] as num?)?.toInt() ?? 1;
                    final type = reward['rewardType']?.toString() ?? '';
                    final title = reward['title']?.toString() ?? 'Ödül';
                    final unlocked = reward['unlocked'] == true;
                    final claimed = reward['claimed'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: unlocked
                            ? AppColors.lime.withValues(alpha: .11)
                            : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: unlocked
                              ? AppColors.lime.withValues(alpha: .55)
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: unlocked
                                  ? AppColors.lime
                                  : scheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _rewardIcon(type),
                              color: unlocked
                                  ? AppColors.navy
                                  : scheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lv $rewardLevel',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (claimed)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.lime,
                              size: 22,
                            )
                          else
                            Icon(
                              Icons.lock_outline_rounded,
                              color: scheme.onSurfaceVariant,
                              size: 19,
                            ),
                        ],
                      ),
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
