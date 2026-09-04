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
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.lime.withValues(alpha: .55),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Meet6 Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _loading
                            ? 'Üyelik durumun kontrol ediliyor...'
                            : _premium
                                ? 'Premium aktif · Üyeliğini görüntüle'
                                : 'Oda önceliği ve 30 dk Premium odalar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.lime,
                    ),
                  )
                else if (_premium)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'AKTİF',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.lime,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
