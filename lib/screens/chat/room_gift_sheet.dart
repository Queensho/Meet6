import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/gift_service.dart';
import '../../theme/app_colors.dart';
import 'coin_store_sheet.dart';

const Map<String, String> _giftAssetByCode = {
  'rose': 'assets/images/H1.png',
  'coffee': 'assets/images/H2.png',
  'heart': 'assets/images/H3.png',
  'sparkle': 'assets/images/H4.png',
  'balloon': 'assets/images/H5.png',
  'rocket': 'assets/images/H6.png',
  'diamond': 'assets/images/H7.png',
  'crown': 'assets/images/H8.png',
};

Widget _giftVisual(Map<String, dynamic> gift, {double size = 50}) {
  final code = gift['code']?.toString() ?? gift['gift_code']?.toString() ?? '';
  final asset = _giftAssetByCode[code];
  final emoji = gift['emoji']?.toString() ?? '🎁';

  if (asset == null) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * .58),
        ),
      ),
    );
  }

  return Image.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    errorBuilder: (_, __, ___) => SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * .58),
        ),
      ),
    ),
  );
}

class RoomGiftSheet extends StatefulWidget {
  const RoomGiftSheet({
    super.key,
    required this.roomId,
    required this.members,
    required this.myUserId,
  });

  final String roomId;
  final List<Map<String, dynamic>> members;
  final String myUserId;

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String roomId,
    required List<Map<String, dynamic>> members,
    required String myUserId,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomGiftSheet(
        roomId: roomId,
        members: members,
        myUserId: myUserId,
      ),
    );
  }

  @override
  State<RoomGiftSheet> createState() => _RoomGiftSheetState();
}

class _RoomGiftSheetState extends State<RoomGiftSheet> {
  Map<String, dynamic>? catalog;
  String? selectedRecipientId;
  String? selectedGiftCode;
  bool loading = true;
  bool sending = false;
  String? error;

  List<Map<String, dynamic>> get recipients => widget.members
      .where((member) => member['user_id']?.toString() != widget.myUserId)
      .toList(growable: false);

  List<Map<String, dynamic>> get gifts {
    final raw = catalog?['gifts'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Map<String, dynamic> get wallet {
    final raw = catalog?['wallet'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Map<String, dynamic> get freeGiftAllowance {
    final raw = catalog?['freeGiftAllowance'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Map<String, dynamic>? get selectedGift {
    for (final gift in gifts) {
      if (gift['code']?.toString() == selectedGiftCode) return gift;
    }
    return null;
  }

  int get balance => (wallet['coinBalance'] as num?)?.toInt() ?? 0;
  int get freeRemaining => (freeGiftAllowance['remaining'] as num?)?.toInt() ?? 0;
  int get freeDailyLimit => (freeGiftAllowance['dailyLimit'] as num?)?.toInt() ?? 3;

  @override
  void initState() {
    super.initState();
    if (recipients.isNotEmpty) {
      selectedRecipientId = recipients.first['user_id']?.toString();
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await GiftService.catalog();
      if (!mounted) return;
      setState(() {
        catalog = data;
        selectedGiftCode ??= gifts.isEmpty ? null : gifts.first['code']?.toString();
        loading = false;
        error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    }
  }

  Future<void> _openCoinStore() async {
    final newBalance = await CoinStoreSheet.show(context);
    if (!mounted || newBalance == null) return;
    final current = catalog;
    if (current == null) {
      await _load();
      return;
    }
    final currentWallet = wallet;
    setState(() {
      catalog = {
        ...current,
        'wallet': {
          ...currentWallet,
          'coinBalance': newBalance,
        },
      };
    });
  }

  Future<void> _send() async {
    final recipientId = selectedRecipientId;
    final gift = selectedGift;
    if (recipientId == null || gift == null || sending) return;
    final cost = (gift['coinCost'] as num?)?.toInt() ?? 0;
    final dailyFree = gift['dailyFree'] == true;
    if (dailyFree && freeRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bugünkü 3 ücretsiz hediyeni kullandın.')),
      );
      return;
    }
    if (!dailyFree && balance < cost) {
      await _openCoinStore();
      return;
    }

    setState(() => sending = true);
    try {
      final result = await GiftService.sendRoomGift(
        roomId: widget.roomId,
        recipientUserId: recipientId,
        giftCode: gift['code']?.toString() ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _avatar(Map<String, dynamic> member, {double size = 42}) {
    final scheme = Theme.of(context).colorScheme;
    final photos = member['photo_urls'];
    final path = photos is List && photos.isNotEmpty ? photos.first.toString() : '';
    final name = member['display_name']?.toString().trim() ?? '';
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.navy,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: path.isEmpty
          ? Center(
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w900),
              ),
            )
          : Image.network(
              ApiService.absoluteMediaUrl(path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: AppColors.lime),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gift = selectedGift;
    final selectedCost = (gift?['coinCost'] as num?)?.toInt() ?? 0;
    final selectedDailyFree = gift?['dailyFree'] == true;
    final selectedFreeExhausted = selectedDailyFree && freeRemaining <= 0;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .78),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: loading
            ? const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
              )
            : error != null
                ? SizedBox(
                    height: 280,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                          ],
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      12,
                      18,
                      18 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
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
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppColors.lime,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.card_giftcard_rounded, color: AppColors.navy),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hediye gönder',
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Hediyeler eşleşme şansını etkilemez.',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: _openCoinStore,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '🪙 $balance',
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.add_circle_rounded, color: AppColors.lime, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.lime.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.lime.withValues(alpha: .38)),
                          ),
                          child: Row(
                            children: [
                              const Text('🎁', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bugün $freeRemaining/$freeDailyLimit ücretsiz hediye hakkın kaldı · ücretsiz hediye yalnız +1 Meet6 XP verir.',
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Kime?',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 76,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recipients.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 9),
                            itemBuilder: (_, index) {
                              final member = recipients[index];
                              final id = member['user_id']?.toString() ?? '';
                              final selected = id == selectedRecipientId;
                              final name = member['display_name']?.toString() ?? 'Meet6';
                              return InkWell(
                                onTap: () => setState(() => selectedRecipientId = id),
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 72,
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: selected ? AppColors.lime.withValues(alpha: .16) : scheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: selected ? AppColors.lime : scheme.outlineVariant,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _avatar(member, size: 38),
                                      const SizedBox(height: 4),
                                      Text(
                                        name.split(' ').first,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Hediyeler',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: gifts.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 9,
                            crossAxisSpacing: 9,
                            childAspectRatio: .78,
                          ),
                          itemBuilder: (_, index) {
                            final item = gifts[index];
                            final code = item['code']?.toString() ?? '';
                            final selected = code == selectedGiftCode;
                            final dailyFree = item['dailyFree'] == true;
                            final exhausted = dailyFree && freeRemaining <= 0;
                            return Opacity(
                              opacity: exhausted ? .5 : 1,
                              child: InkWell(
                                onTap: exhausted ? null : () => setState(() => selectedGiftCode = code),
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.fromLTRB(6, 5, 6, 7),
                                  decoration: BoxDecoration(
                                    color: selected ? AppColors.lime.withValues(alpha: .15) : scheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: selected ? AppColors.lime : scheme.outlineVariant,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _giftVisual(item, size: dailyFree ? 43 : 52),
                                      const SizedBox(height: 2),
                                      Text(
                                        item['name']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dailyFree
                                            ? (exhausted ? 'Bitti' : 'Ücretsiz')
                                            : '🪙 ${item['coinCost'] ?? 0}',
                                        style: TextStyle(
                                          color: dailyFree ? AppColors.lime : scheme.onSurfaceVariant,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Meet6 XP: ${wallet['profileXp'] ?? 0} · Hediye XP: ${wallet['giftXp'] ?? 0}',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              'Lv ${wallet['profileLevel'] ?? 1}',
                              style: const TextStyle(
                                color: AppColors.lime,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: recipients.isEmpty || gift == null || sending || selectedFreeExhausted
                                ? null
                                : _send,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.lime,
                              foregroundColor: AppColors.navy,
                              disabledBackgroundColor: scheme.surfaceContainerHigh,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                            ),
                            icon: sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2.3, color: AppColors.navy),
                                  )
                                : const Icon(Icons.card_giftcard_rounded),
                            label: Text(
                              gift == null
                                  ? 'Hediye seç'
                                  : selectedDailyFree
                                      ? 'Gönder · Ücretsiz'
                                      : 'Gönder · 🪙 $selectedCost',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        if (!selectedDailyFree && balance < selectedCost) ...[
                          const SizedBox(height: 6),
                          Center(
                            child: TextButton.icon(
                              onPressed: _openCoinStore,
                              icon: const Icon(Icons.add_circle_rounded, size: 17),
                              label: const Text('Yeterli jeton yok · Jeton yükle'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}

class RoomGiftMessageCard extends StatelessWidget {
  const RoomGiftMessageCard({
    super.key,
    required this.gift,
    required this.myUserId,
  });

  final Map<String, dynamic> gift;
  final String? myUserId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final senderId = gift['sender_user_id']?.toString();
    final recipientId = gift['recipient_user_id']?.toString();
    final sender = senderId == myUserId ? 'Sen' : gift['display_name']?.toString() ?? 'Meet6';
    final recipient = recipientId == myUserId
        ? 'sana'
        : '${gift['recipient_display_name']?.toString() ?? 'Meet6'} kişisine';
    final name = gift['gift_name']?.toString() ?? 'Hediye';
    final receivedByMe = recipientId == myUserId;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .92, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(vertical: 7),
          padding: const EdgeInsets.fromLTRB(13, 10, 14, 10),
          decoration: BoxDecoration(
            color: receivedByMe ? AppColors.lime.withValues(alpha: .13) : scheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: receivedByMe ? AppColors.lime : scheme.outlineVariant,
              width: receivedByMe ? 1.7 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _giftVisual(gift, size: 52),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$sender $recipient',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$name gönderdi',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${gift['gift_xp'] ?? 0} Hediye XP · +${gift['generosity_xp'] ?? 0} Cömertlik XP',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
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
}
