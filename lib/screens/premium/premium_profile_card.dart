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
    return Semantics(
      button: true,
      label: _premium
          ? 'Meet6 Premium aktif. Premium üyeliğini yönet.'
          : 'Meet6 Premium. Premium özelliklerini görüntüle.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : _openPremium,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            width: 210,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: .24),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.navy,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Meet6 Premium',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.2,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _loading
                            ? 'Kontrol ediliyor...'
                            : _premium
                                ? 'Premium aktif'
                                : '1’e 1 sesli + 30 dk',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.8,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (_loading)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppColors.lime,
                    ),
                  )
                else if (_premium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'AKTİF',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 8.3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.lime,
                    size: 19,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
