import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/coin_store_service.dart';
import '../../theme/app_colors.dart';

class CoinStoreSheet extends StatefulWidget {
  const CoinStoreSheet({super.key});

  static Future<int?> show(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CoinStoreSheet(),
    );
  }

  @override
  State<CoinStoreSheet> createState() => _CoinStoreSheetState();
}

class _CoinStoreSheetState extends State<CoinStoreSheet> {
  CoinStoreSnapshot? snapshot;
  bool loading = true;
  String? buyingProductId;
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
      final data = await CoinStoreService.load();
      if (!mounted) return;
      setState(() {
        snapshot = data;
        loading = false;
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
        error = 'Jeton paketleri yüklenemedi.';
      });
    }
  }

  Future<void> _buy(CoinPackOption option) async {
    if (buyingProductId != null) return;
    setState(() => buyingProductId = option.productId);
    try {
      final balance = await CoinStoreService.purchase(option);
      if (!mounted) return;
      setState(() {
        snapshot = CoinStoreSnapshot(
          coinBalance: balance,
          options: snapshot?.options ?? const [],
        );
        buyingProductId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${option.coinAmount} jeton hesabına eklendi.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => buyingProductId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => buyingProductId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satın alma tamamlanamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = snapshot;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .72),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🪙', style: TextStyle(fontSize: 25)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jeton mağazası',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Hediyeler için jeton yükle',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '🪙 ${data?.coinBalance ?? 0}',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
                )
              else if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                      ],
                    ),
                  ),
                )
              else if (data == null || data.options.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'Jeton paketleri mağazada henüz yapılandırılmadı.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: data.options.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.42,
                    ),
                    itemBuilder: (_, index) {
                      final option = data.options[index];
                      final busy = buyingProductId == option.productId;
                      return InkWell(
                        onTap: buyingProductId == null ? () => _buy(option) : null,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '🪙 ${option.coinAmount}',
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 7),
                              busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: AppColors.lime,
                                      ),
                                    )
                                  : Text(
                                      option.priceText,
                                      style: const TextStyle(
                                        color: AppColors.lime,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Satın alma Google Play / App Store üzerinden yapılır. Jeton bakiyesi sunucu tarafından doğrulanır.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(snapshot?.coinBalance),
                  child: const Text('Kapat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
