import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../services/api_service.dart';
import '../../services/premium_subscription_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../../widgets/phone_frame.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  PremiumStatus? status;
  List<Package> packages = const [];
  bool loading = true;
  bool actionRunning = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final serverStatus = await PremiumSubscriptionService.status();
      List<Package> available = const [];
      String? packageError;
      try {
        available = await PremiumSubscriptionService.packages();
      } catch (e) {
        packageError = e is ApiException ? e.message : 'Mağaza ürünleri yüklenemedi.';
      }
      if (!mounted) return;
      setState(() {
        status = serverStatus;
        packages = available;
        loading = false;
        if (!serverStatus.premium && available.isEmpty) error = packageError;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Premium bilgisi yüklenemedi.';
      });
    }
  }

  Future<void> _purchase(Package package) async {
    if (actionRunning) return;
    setState(() {
      actionRunning = true;
      error = null;
    });
    try {
      final updated = await PremiumSubscriptionService.purchase(package);
      if (!mounted) return;
      setState(() => status = updated);
      if (updated.premium) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meet6 Premium aktif edildi.')),
        );
      } else {
        setState(() {
          error = 'Satın alma mağazada tamamlandı ancak sunucu entitlement doğrulaması henüz aktif görünmüyor.';
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message ?? 'Satın alma tamamlanamadı.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'Satın alma tamamlanamadı.');
    } finally {
      if (mounted) setState(() => actionRunning = false);
    }
  }

  Future<void> _restore() async {
    if (actionRunning) return;
    setState(() {
      actionRunning = true;
      error = null;
    });
    try {
      final updated = await PremiumSubscriptionService.restore();
      if (!mounted) return;
      setState(() => status = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.premium
                ? 'Premium satın alımın geri yüklendi.'
                : 'Bu hesap için aktif Premium satın alımı bulunamadı.',
          ),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message ?? 'Satın alımlar geri yüklenemedi.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'Satın alımlar geri yüklenemedi.');
    } finally {
      if (mounted) setState(() => actionRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final premium = status?.premium == true;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: PhoneFrame(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: actionRunning ? null : () => Navigator.of(context).pop(premium),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 6),
                    const Meet6MiniBrand(height: 27, forceLogo2: true),
                    const Spacer(),
                    if (premium)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.lime,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'AKTİF',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.workspace_premium_rounded, color: AppColors.lime, size: 38),
                                SizedBox(height: 14),
                                Text(
                                  'Meet6 Premium',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 29,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                                SizedBox(height: 7),
                                Text(
                                  'Daha hızlı oda bul, 1’e 1 sesli eşleş ve 30 dakikalık Premium yazılı odaları kullan.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const _Benefit(
                            icon: Icons.bolt_rounded,
                            title: 'Oda önceliği',
                            subtitle: 'Premium kullanıcılar aynı oda modunda kuyrukta öncelikli değerlendirilir.',
                          ),
                          const _Benefit(
                            icon: Icons.record_voice_over_rounded,
                            title: '1’e 1 sesli eşleşme',
                            subtitle: 'Tercihlerine uyan bir Premium kullanıcıyla 15 dakika birebir sesli konuş.',
                          ),
                          const _Benefit(
                            icon: Icons.timer_rounded,
                            title: '30 dakikalık yazılı odalar',
                            subtitle: 'İstersen 6 kişilik yazılı oda deneyimini Premium olarak 30 dakikaya çıkar.',
                          ),
                          const _Benefit(
                            icon: Icons.tune_rounded,
                            title: 'Premium oda filtreleri',
                            subtitle: 'Premium oda seçenekleri server-side entitlement ile korunur.',
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(0x18E76A60),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0x55E76A60)),
                              ),
                              child: Text(
                                error!,
                                style: const TextStyle(
                                  color: Color(0xFFE76A60),
                                  fontSize: 11.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          if (premium)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.lime.withValues(alpha: .18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.lime.withValues(alpha: .55)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Premium üyeliğin aktif',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                  ),
                                  if (status?.expiresAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bitiş: ${_date(status!.expiresAt!)}${status!.willRenew ? ' · Otomatik yenilenir' : ''}',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else ...[
                            if (packages.isEmpty)
                              OutlinedButton.icon(
                                onPressed: actionRunning ? null : _load,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Mağaza ürünlerini yeniden yükle'),
                              )
                            else
                              for (final package in packages) ...[
                                _PackageCard(
                                  package: package,
                                  disabled: actionRunning,
                                  onPurchase: () => _purchase(package),
                                ),
                                const SizedBox(height: 10),
                              ],
                          ],
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: actionRunning ? null : _restore,
                            child: const Text('Satın alımları geri yükle'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Premium durumu cihazdaki bir bayrağa göre değil, mağaza satın alımı RevenueCat ve Meet6 sunucusu tarafından doğrulandıktan sonra etkinleşir.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.lime,
              foregroundColor: AppColors.navy,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.2,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
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

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.disabled,
    required this.onPurchase,
  });

  final Package package;
  final bool disabled;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lime, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  product.priceString,
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: disabled ? null : onPurchase,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Satın al'),
          ),
        ],
      ),
    );
  }
}
