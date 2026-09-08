import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../services/mini_game_selection_service.dart';
import '../../services/party_matchmaking_service.dart';
import '../../services/premium_subscription_service.dart';
import '../../services/runtime_app_config_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../premium/premium_screen.dart';
import 'room_searching_screen.dart';

class RoomRulesScreen extends StatefulWidget {
  const RoomRulesScreen({super.key, this.profileName = ''});
  final String profileName;

  @override
  State<RoomRulesScreen> createState() => _RoomRulesScreenState();
}

class _RoomRulesScreenState extends State<RoomRulesScreen> {
  bool premium = false;
  bool premiumLoading = true;
  bool partyLoading = false;
  int roomDurationMinutes = 15;
  String roomMode = 'text';
  late String selectedGame;

  static const games = <_GameInfo>[
    _GameInfo(id: 'two_truths_one_lie', title: 'İki Doğru Bir Yalan', subtitle: 'Kendini anlat, hangisi yalan?', icon: Icons.sports_esports_rounded, recommended: true, active: true),
    _GameInfo(id: 'red_flag_green_flag', title: 'Red Flag / Green Flag', subtitle: '6 soru • 15 sn seçim • 2 dk tartışma', icon: Icons.flag_rounded, active: true),
    _GameInfo(id: 'tabu', title: 'Tabu', subtitle: 'Yazıyla anlat • 5 kişi tahmin etsin • 60 sn', icon: Icons.record_voice_over_rounded, active: true),
    _GameInfo(id: 'question_answer', title: 'Soru Cevap', subtitle: '6 kişiye aynı sorular', icon: Icons.question_answer_rounded),
    _GameInfo(id: 'this_or_that', title: 'Bu mu Daha mı?', subtitle: 'Zor tercihler, eğlenceli sohbetler', icon: Icons.favorite_rounded),
    _GameInfo(id: 'common_ground', title: 'Ortak Nokta', subtitle: 'Sizi birleştiren ne?', icon: Icons.groups_rounded),
    _GameInfo(id: 'quick_round', title: 'Hızlı Tur', subtitle: 'Kısa sorular, hızlı cevaplar', icon: Icons.bolt_rounded),
  ];

  bool get voiceMode => roomMode == 'voice';
  bool get gameMode => roomMode == 'game';
  bool get fixedFifteenMode => voiceMode || gameMode;
  _GameInfo get selectedGameInfo => games.firstWhere((g) => g.id == selectedGame, orElse: () => games.first);

  int get modeIndex {
    switch (roomMode) {
      case 'voice': return 1;
      case 'game': return 2;
      default: return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    selectedGame = MiniGameSelectionService.selectedGameKey;
    if (!games.any((g) => g.id == selectedGame && g.active)) selectedGame = 'two_truths_one_lie';
    MiniGameSelectionService.select(selectedGame);
    _loadPremium();
  }

  Future<void> _loadPremium() async {
    try {
      final value = await PremiumSubscriptionService.status();
      if (!mounted) return;
      setState(() {
        premium = value.premium;
        premiumLoading = false;
        if (!premium && voiceMode) { roomMode = 'text'; roomDurationMinutes = 15; }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { premium = false; premiumLoading = false; if (voiceMode) roomMode = 'text'; roomDurationMinutes = 15; });
    }
  }

  Future<void> _selectMode(String mode) async {
    if (premiumLoading) return;
    if (mode == 'voice' && !premium) {
      final activated = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PremiumScreen()));
      if (!mounted) return;
      if (activated == true) await _loadPremium();
      if (!mounted || !premium) return;
    }
    setState(() { roomMode = mode; if (mode != 'text') roomDurationMinutes = 15; });
  }

  Future<void> _cycleMode() async {
    if (premiumLoading) return;
    if (!premium) {
      setState(() {
        roomMode = gameMode ? 'text' : 'game';
        roomDurationMinutes = 15;
      });
      return;
    }
    const modes = ['text', 'voice', 'game'];
    await _selectMode(modes[(modeIndex + 1) % modes.length]);
  }

  Future<void> _selectDuration(int minutes) async {
    if (premiumLoading) return;
    if (minutes == 15) { setState(() => roomDurationMinutes = 15); return; }
    if (fixedFifteenMode) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(voiceMode ? 'Premium birebir sesli eşleşmeler 15 dakikadır.' : 'Mini oyun odaları 15 dakikadır.')));
      return;
    }
    if (premium) { setState(() => roomDurationMinutes = 30); return; }
    final activated = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PremiumScreen()));
    if (!mounted) return;
    if (activated == true) { await _loadPremium(); if (mounted && premium) setState(() => roomDurationMinutes = 30); }
  }

  Future<void> _openGamePicker() async {
    if (!gameMode) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          margin: EdgeInsets.only(top: MediaQuery.of(sheetContext).size.height * .16),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          decoration: const BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 48, height: 5, decoration: BoxDecoration(color: AppColors.navy.withOpacity(.45), borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Oyun seç', style: TextStyle(color: AppColors.navy, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -.8)),
                  SizedBox(height: 4),
                  Text('6 kişilik mini oyun odalarında oynanacak oyunu seç.', style: TextStyle(color: AppColors.navy, fontSize: 13, fontWeight: FontWeight.w700)),
                ])),
                IconButton(onPressed: () => Navigator.pop(sheetContext), style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(.35)), icon: const Icon(Icons.close_rounded, color: AppColors.navy, size: 28)),
              ]),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: SingleChildScrollView(
                  child: Column(children: [
                    for (final game in games) ...[
                      _GamePickerTile(game: game, selected: selectedGame == game.id, onTap: () {
                        if (!game.active) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${game.title} yakında aktif olacak.')));
                          return;
                        }
                        Navigator.pop(sheetContext, game.id);
                      }),
                      if (game != games.last) const SizedBox(height: 10),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    MiniGameSelectionService.select(picked);
    setState(() => selectedGame = picked);
  }

  void _startSearch(BuildContext context) {
    if (gameMode) MiniGameSelectionService.select(selectedGame);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RoomSearchingScreen(profileName: widget.profileName, roomDurationMinutes: roomDurationMinutes, roomMode: roomMode)));
  }

  Future<void> _openPartyOptions() async {
    if (voiceMode) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arkadaşınla Katıl yazılı oda ve mini oyunlarda kullanılabilir.')));
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(30)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 46, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 18),
            const Icon(Icons.group_add_rounded, color: AppColors.lime, size: 44),
            const SizedBox(height: 10),
            const Text('Arkadaşınla Katıl', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('1 arkadaşını getir, kalan 4 kişiyi Meet6 bulsun. İkiniz aynı odada kalırsınız.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(
              onPressed: () => Navigator.pop(sheetContext, 'create'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.lime, foregroundColor: AppColors.navy),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Arkadaşını davet et', style: TextStyle(fontWeight: FontWeight.w900)),
            )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 52, child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(sheetContext, 'accept'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30)),
              icon: const Icon(Icons.key_rounded),
              label: const Text('Davet kodum var', style: TextStyle(fontWeight: FontWeight.w900)),
            )),
          ]),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'create') await _createPartyInvite();
    if (action == 'accept') await _acceptPartyInvite();
  }

  Future<void> _createPartyInvite() async {
    if (partyLoading) return;
    setState(() => partyLoading = true);
    try {
      if (gameMode) MiniGameSelectionService.select(selectedGame);
      final result = await PartyMatchmakingService.create(
        roomMode: roomMode,
        roomDurationMinutes: roomDurationMinutes,
        gameKey: gameMode ? selectedGame : null,
      );
      final raw = result['party'];
      final party = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final code = party['code']?.toString() ?? '';
      if (code.isEmpty) throw const ApiException('Davet kodu oluşturulamadı.');
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Davet kodu $code panoya kopyalandı.')));
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => RoomSearchingScreen(
          profileName: widget.profileName,
          roomDurationMinutes: roomDurationMinutes,
          roomMode: roomMode,
          partyCode: code,
        ),
      ));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => partyLoading = false);
    }
  }

  Future<void> _acceptPartyInvite() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Davet kodunu gir'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          decoration: const InputDecoration(hintText: 'Örn. A1B2C3', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim().toUpperCase()), child: const Text('Katıl')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || code == null || code.isEmpty) return;

    setState(() => partyLoading = true);
    try {
      final result = await PartyMatchmakingService.accept(code);
      final raw = result['party'];
      final party = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final targetMode = party['roomMode']?.toString() == 'game' ? 'game' : 'text';
      final targetGame = party['gameKey']?.toString();
      final targetDuration = (party['roomDurationMinutes'] as num?)?.toInt() ?? 15;
      if (targetMode == 'game' && targetGame != null && targetGame.isNotEmpty) {
        MiniGameSelectionService.select(targetGame);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => RoomSearchingScreen(
          profileName: widget.profileName,
          roomDurationMinutes: targetDuration,
          roomMode: targetMode,
          partyCode: code,
        ),
      ));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => partyLoading = false);
    }
  }

  _ModeInfo _modeInfo(RuntimeAppConfig runtime) {
    if (voiceMode) return const _ModeInfo(icon: Icons.mic_rounded, title: 'Birebir Sesli', subtitle: '1 kişiyle özel sesli görüşme', pill: 'Premium');
    if (gameMode) return _ModeInfo(icon: Icons.sports_esports_rounded, title: '${runtime.minimumUsers} Kişi Mini Oyun', subtitle: 'Oyun + sohbet • ${selectedGameInfo.title}', pill: 'Yeni');
    return _ModeInfo(icon: Icons.groups_2_rounded, title: '${runtime.minimumUsers} Kişi Yazılı', subtitle: '${runtime.minimumUsers} kişi birlikte yazılı sohbet', pill: roomDurationMinutes == 30 ? 'Premium' : 'Standart');
  }

  String get _searchLabel {
    if (voiceMode) return 'Birebir sesli eşleşme ara';
    if (gameMode) return '${selectedGameInfo.title} odası ara';
    return '$roomDurationMinutes dk oda ara';
  }

  IconData get _searchIcon => voiceMode ? Icons.mic_rounded : gameMode ? Icons.sports_esports_rounded : Icons.search_rounded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RuntimeAppConfig>(
      valueListenable: RuntimeAppConfigService.listenable,
      builder: (context, runtime, _) {
        final info = _modeInfo(runtime);
        return Scaffold(
          backgroundColor: AppColors.lime,
          body: LayoutBuilder(builder: (context, viewport) {
            final desktop = viewport.maxWidth > 520;
            final width = desktop ? 390.0 : viewport.maxWidth;
            final height = desktop ? 844.0 : viewport.maxHeight;
            return Container(
              color: desktop ? const Color(0xFFEFF1F7) : AppColors.lime,
              alignment: Alignment.center,
              child: Container(
                width: width,
                height: height,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: AppColors.lime, borderRadius: desktop ? BorderRadius.circular(32) : BorderRadius.zero),
                child: SafeArea(child: Column(children: [
                  Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 2), child: Row(children: [
                    IconButton(onPressed: () => Navigator.of(context).pop(), style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(.38)), icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy)),
                    const Spacer(),
                    const Meet6MiniBrand(height: 26, forceLogo2: true),
                  ])),
                  Expanded(child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 2, 22, 30),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Center(child: _ModeOrbit(selectedIndex: modeIndex, premium: premium, loading: premiumLoading, onCenterTap: _cycleMode, onModeTap: (index) { const modes = ['text', 'voice', 'game']; _selectMode(modes[index]); })),
                      const SizedBox(height: 2),
                      const Center(child: Text('6’ya bas, modu değiştir', style: TextStyle(color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.w900))),
                      const SizedBox(height: 14),
                      const Center(child: Text('Odaya katılmadan önce', textAlign: TextAlign.center, style: TextStyle(color: AppColors.navy, fontSize: 28, height: 1.02, fontWeight: FontWeight.w900, letterSpacing: -1.1))),
                      const SizedBox(height: 6),
                      Center(child: Text('Meet6 odaları kısa, gerçek ve güvenli sohbetler için tasarlandı.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.navy.withOpacity(.72), fontSize: 12.5, fontWeight: FontWeight.w600))),
                      const SizedBox(height: 20),
                      const _SectionTitle(title: 'Oda seçimi', subtitle: '6’nın çevresindeki modlardan birini seç.'),
                      const SizedBox(height: 10),
                      _SelectedModeCard(info: info, onTap: gameMode ? _openGamePicker : null, showChevron: gameMode),
                      const SizedBox(height: 22),
                      const _SectionTitle(title: 'Süre seçimi', subtitle: 'Ne kadar sohbet etmek istersin?'),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _DurationChoice(selected: roomDurationMinutes == 15, label: '15 dk', onTap: () => _selectDuration(15))),
                        const SizedBox(width: 10),
                        Expanded(child: _DurationChoice(selected: roomDurationMinutes == 30, label: '30 dk', premium: true, disabled: fixedFifteenMode, onTap: () => _selectDuration(30))),
                      ]),
                      const SizedBox(height: 8),
                      Text(voiceMode ? 'Birebir sesli eşleşmeler 15 dakikadır.' : gameMode ? 'Mini oyun odaları 6 kişilik ve 15 dakikadır.' : '15 dk herkes için. 30 dk Premium üyelikte açılır.', style: TextStyle(color: AppColors.navy.withOpacity(.62), fontSize: 10.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 22),
                      const _SectionTitle(title: 'Oda kuralları', subtitle: 'Herkes için daha iyi bir deneyim.'),
                      const SizedBox(height: 10),
                      _RuleTile(
                        icon: gameMode ? Icons.sports_esports_rounded : Icons.visibility_off_rounded,
                        title: gameMode ? 'Oyun sohbeti başlatır' : 'Kararınız gizlidir',
                        subtitle: gameMode
                            ? selectedGame == 'red_flag_green_flag'
                                ? '6 soru oynanır. Her soruda 15 sn seçim ve 2 dk tartışma vardır.'
                                : selectedGame == 'tabu'
                                    ? 'Her oyuncu 60 saniye anlatıcı olur. Anlatıcı yazıyla anlatır, diğer 5 kişi tahmin eder.'
                                    : '${selectedGameInfo.title} oda içinde sırayla oynanır.'
                            : 'Görüşme bitince ${runtime.selectionSeconds} saniyelik gizli seçim başlar.',
                      ),
                      _RuleTile(
                        icon: Icons.favorite_rounded,
                        title: gameMode ? (selectedGame == 'tabu' ? 'İlk doğru tahmin puan alır' : 'Finalde oyun uyumu hesaplanır') : 'Saygılı ve doğal ol',
                        subtitle: gameMode
                            ? selectedGame == 'tabu'
                                ? 'Tahminciler yasaklı kelimeleri kullanabilir. Yasak sadece anlatıcı için geçerlidir.'
                                : 'XP ayrı kalır. Oyun uyumu yalnızca bu oyundaki cevap benzerliğidir.'
                            : 'Hakaret, taciz ve rahatsız edici davranışlara yer yok.',
                        last: true,
                      ),
                    ]),
                  )),
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
                    child: Column(children: [
                      if (!voiceMode) ...[
                        SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(
                          onPressed: premiumLoading || partyLoading ? null : _openPartyOptions,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            side: BorderSide(color: AppColors.navy.withOpacity(.45), width: 1.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: partyLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                              : const Icon(Icons.group_add_rounded),
                          label: const Text('Arkadaşınla Katıl · 2 + 4', style: TextStyle(fontWeight: FontWeight.w900)),
                        )),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(width: double.infinity, height: 58, child: FilledButton(
                        onPressed: premiumLoading || partyLoading ? null : () => _startSearch(context),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_searchIcon, size: 24), const SizedBox(width: 10), Flexible(child: Text(_searchLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)))]),
                      )),
                    ]),
                  ),
                ])),
              ),
            );
          }),
        );
      },
    );
  }
}

class _GameInfo {
  const _GameInfo({required this.id, required this.title, required this.subtitle, required this.icon, this.recommended = false, this.active = false});
  final String id; final String title; final String subtitle; final IconData icon; final bool recommended; final bool active;
}

class _GamePickerTile extends StatelessWidget {
  const _GamePickerTile({required this.game, required this.selected, required this.onTap});
  final _GameInfo game; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(22), border: selected ? Border.all(color: Colors.white.withOpacity(.72), width: 1.5) : null),
        child: Row(children: [
          Container(width: 58, height: 58, decoration: BoxDecoration(color: Colors.white.withOpacity(.10), shape: BoxShape.circle), child: Icon(game.icon, color: Colors.white, size: 29)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(game.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(game.subtitle, style: TextStyle(color: Colors.white.withOpacity(.62), fontSize: 12, fontWeight: FontWeight.w700))])),
          if (game.recommended) Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(99)), child: const Text('Önerilen', style: TextStyle(color: AppColors.navy, fontSize: 10, fontWeight: FontWeight.w900))),
          Icon(game.active ? Icons.chevron_right_rounded : Icons.lock_clock_rounded, color: AppColors.lime, size: 30),
        ]),
      ),
    );
  }
}

class _ModeInfo { const _ModeInfo({required this.icon, required this.title, required this.subtitle, required this.pill}); final IconData icon; final String title; final String subtitle; final String pill; }

class _ModeOrbit extends StatelessWidget {
  const _ModeOrbit({required this.selectedIndex, required this.premium, required this.loading, required this.onCenterTap, required this.onModeTap});
  final int selectedIndex; final bool premium; final bool loading; final VoidCallback onCenterTap; final ValueChanged<int> onModeTap;
  static const _icons = [Icons.groups_2_rounded, Icons.mic_rounded, Icons.sports_esports_rounded];
  static const _labels = ['Yazılı', 'Sesli', 'Mini Oyun'];
  @override
  Widget build(BuildContext context) {
    final targetTurns = -selectedIndex / 3;
    return SizedBox(width: 270, height: 230, child: Stack(alignment: Alignment.center, children: [
      Container(width: 154, height: 154, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.62), width: 1.5))),
      TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: targetTurns), duration: const Duration(milliseconds: 420), curve: Curves.easeOutBack, builder: (context, turns, _) {
        final base = turns * 2 * math.pi - math.pi / 2;
        return Stack(alignment: Alignment.center, children: List.generate(3, (index) {
          final angle = base + index * (2 * math.pi / 3); const radius = 76.0; final selected = index == selectedIndex; final locked = index == 1 && !premium;
          return Transform.translate(offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius), child: GestureDetector(onTap: loading ? null : () => onModeTap(index), child: AnimatedContainer(duration: const Duration(milliseconds: 220), width: selected ? 76 : 58, height: selected ? 76 : 58, decoration: BoxDecoration(color: selected ? AppColors.navy : Colors.white.withOpacity(.62), shape: BoxShape.circle), child: Stack(alignment: Alignment.center, children: [Column(mainAxisSize: MainAxisSize.min, children: [Icon(_icons[index], color: selected ? AppColors.lime : AppColors.navy, size: selected ? 28 : 23), const SizedBox(height: 2), Text(_labels[index], style: TextStyle(color: selected ? Colors.white : AppColors.navy, fontSize: selected ? 8.5 : 7.5, fontWeight: FontWeight.w900))]), if (locked) const Positioned(right: 1, top: 1, child: Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD968), size: 17))]))));
        }));
      }),
      GestureDetector(onTap: loading ? null : onCenterTap, child: Container(width: 108, height: 108, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lime, border: Border.all(color: Colors.white, width: 3)), alignment: Alignment.center, child: loading ? const CircularProgressIndicator(color: AppColors.navy) : const Text('6', style: TextStyle(color: AppColors.navy, fontSize: 64, height: .9, fontWeight: FontWeight.w900, letterSpacing: -4)))),
    ]));
  }
}

class _SelectedModeCard extends StatelessWidget {
  const _SelectedModeCard({required this.info, this.onTap, this.showChevron = false}); final _ModeInfo info; final VoidCallback? onTap; final bool showChevron;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(22)), child: Row(children: [
    Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.white.withOpacity(.1), shape: BoxShape.circle), child: Icon(info.icon, color: AppColors.lime, size: 29)), const SizedBox(width: 13),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(info.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(info.subtitle, style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 11, fontWeight: FontWeight.w700))])),
    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: info.pill == 'Premium' ? const Color(0xFFFFD968) : AppColors.lime, borderRadius: BorderRadius.circular(99)), child: Text(info.pill, style: const TextStyle(color: AppColors.navy, fontSize: 10, fontWeight: FontWeight.w900))), if (showChevron) const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.lime),
  ])));
}

class _SectionTitle extends StatelessWidget { const _SectionTitle({required this.title, required this.subtitle}); final String title; final String subtitle; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.navy, fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: AppColors.navy.withOpacity(.67), fontSize: 11.5, fontWeight: FontWeight.w600))]); }

class _DurationChoice extends StatelessWidget {
  const _DurationChoice({required this.selected, required this.label, required this.onTap, this.premium = false, this.disabled = false}); final bool selected; final String label; final VoidCallback onTap; final bool premium; final bool disabled;
  @override Widget build(BuildContext context) { final foreground = selected ? Colors.white : AppColors.navy; return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(99), child: Opacity(opacity: disabled ? .55 : 1, child: Container(height: 52, decoration: BoxDecoration(color: selected ? AppColors.navy : Colors.white.withOpacity(.4), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.schedule_rounded, color: foreground, size: 21), const SizedBox(width: 7), Text(label, style: TextStyle(color: foreground, fontSize: 16, fontWeight: FontWeight.w900)), if (premium) ...[const SizedBox(width: 7), const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD968), size: 17)]])))); }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.icon, required this.title, required this.subtitle, this.last = false}); final IconData icon; final String title; final String subtitle; final bool last;
  @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(bottom: last ? 0 : 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11), decoration: BoxDecoration(color: Colors.white.withOpacity(.36), borderRadius: BorderRadius.circular(18)), child: Row(children: [Container(width: 43, height: 43, decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle), child: Icon(icon, color: AppColors.lime, size: 22)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.navy, fontSize: 13.5, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(color: AppColors.navy.withOpacity(.66), fontSize: 10.5, fontWeight: FontWeight.w600))]))])));
}
