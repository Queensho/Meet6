import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  int roomDurationMinutes = 15;
  String roomMode = 'text';
  String selectedGame = 'two_truths_one_lie';

  bool get voiceMode => roomMode == 'voice';
  bool get gameMode => roomMode == 'game';
  bool get fixedFifteenMode => voiceMode || gameMode;

  static const games = <_GameInfo>[
    _GameInfo(
      id: 'two_truths_one_lie',
      title: 'İki Doğru Bir Yalan',
      subtitle: 'Kendini anlat, hangisi yalan?',
      icon: Icons.sports_esports_rounded,
      recommended: true,
      active: true,
    ),
    _GameInfo(
      id: 'question_answer',
      title: 'Soru Cevap',
      subtitle: '6 kişiye aynı sorular',
      icon: Icons.question_answer_rounded,
    ),
    _GameInfo(
      id: 'this_or_that',
      title: 'Bu mu Daha mı?',
      subtitle: 'Zor tercihler, eğlenceli sohbetler',
      icon: Icons.favorite_rounded,
    ),
    _GameInfo(
      id: 'common_ground',
      title: 'Ortak Nokta',
      subtitle: 'Sizi birleştiren ne?',
      icon: Icons.groups_rounded,
    ),
    _GameInfo(
      id: 'quick_round',
      title: 'Hızlı Tur',
      subtitle: 'Kısa sorular, hızlı cevaplar',
      icon: Icons.bolt_rounded,
    ),
  ];

  _GameInfo get selectedGameInfo =>
      games.firstWhere((g) => g.id == selectedGame, orElse: () => games.first);

  int get modeIndex {
    switch (roomMode) {
      case 'voice':
        return 1;
      case 'game':
        return 2;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPremium();
  }

  Future<void> _loadPremium() async {
    try {
      final value = await PremiumSubscriptionService.status();
      if (!mounted) return;
      setState(() {
        premium = value.premium;
        premiumLoading = false;
        if (!premium && voiceMode) {
          roomMode = 'text';
          roomDurationMinutes = 15;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        premium = false;
        premiumLoading = false;
        if (voiceMode) roomMode = 'text';
        roomDurationMinutes = 15;
      });
    }
  }

  Future<void> _selectMode(String mode) async {
    if (premiumLoading) return;
    if (mode == 'voice' && !premium) {
      final activated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PremiumScreen()),
      );
      if (!mounted) return;
      if (activated == true) await _loadPremium();
      if (!mounted || !premium) return;
    }
    setState(() {
      roomMode = mode;
      if (mode != 'text') roomDurationMinutes = 15;
    });
  }

  Future<void> _cycleMode() async {
    const modes = ['text', 'voice', 'game'];
    await _selectMode(modes[(modeIndex + 1) % modes.length]);
  }

  Future<void> _selectDuration(int minutes) async {
    if (premiumLoading) return;
    if (minutes == 15) {
      setState(() => roomDurationMinutes = 15);
      return;
    }
    if (fixedFifteenMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(voiceMode
              ? 'Premium birebir sesli eşleşmeler 15 dakikadır.'
              : 'Mini oyun odaları şimdilik 15 dakikadır.'),
        ),
      );
      return;
    }
    if (premium) {
      setState(() => roomDurationMinutes = 30);
      return;
    }
    final activated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
    if (!mounted) return;
    if (activated == true) {
      await _loadPremium();
      if (mounted && premium) setState(() => roomDurationMinutes = 30);
    }
  }

  Future<void> _openGamePicker() async {
    if (!gameMode) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: EdgeInsets.only(top: MediaQuery.of(sheetContext).size.height * .18),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            decoration: const BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withOpacity(.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Oyun seç',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.8,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '6 kişilik mini oyun odalarında oynanacak oyunu seç.',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(.35),
                      ),
                      icon: const Icon(Icons.close_rounded, color: AppColors.navy, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final game in games) ...[
                  _GamePickerTile(
                    game: game,
                    selected: selectedGame == game.id,
                    onTap: () {
                      if (!game.active) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${game.title} yakında aktif olacak.')),
                        );
                        return;
                      }
                      Navigator.pop(sheetContext, game.id);
                    },
                  ),
                  if (game != games.last) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() => selectedGame = picked);
  }

  void _startSearch(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RoomSearchingScreen(
          profileName: widget.profileName,
          roomDurationMinutes: roomDurationMinutes,
          roomMode: roomMode,
        ),
      ),
    );
  }

  _ModeInfo _modeInfo(RuntimeAppConfig runtime) {
    if (voiceMode) {
      return const _ModeInfo(
        icon: Icons.mic_rounded,
        title: 'Birebir Sesli',
        subtitle: '1 kişiyle özel sesli görüşme',
        pill: 'Premium',
      );
    }
    if (gameMode) {
      return _ModeInfo(
        icon: Icons.sports_esports_rounded,
        title: '${runtime.minimumUsers} Kişi Mini Oyun',
        subtitle: 'Oyun + sohbet • ${selectedGameInfo.title}',
        pill: 'Yeni',
      );
    }
    return _ModeInfo(
      icon: Icons.groups_2_rounded,
      title: '${runtime.minimumUsers} Kişi Yazılı',
      subtitle: '${runtime.minimumUsers} kişi birlikte yazılı sohbet',
      pill: roomDurationMinutes == 30 ? 'Premium' : 'Standart',
    );
  }

  String get _searchLabel {
    if (voiceMode) return 'Birebir sesli eşleşme ara';
    if (gameMode) return 'Mini oyun odası ara';
    return '$roomDurationMinutes dk oda ara';
  }

  IconData get _searchIcon {
    if (voiceMode) return Icons.mic_rounded;
    if (gameMode) return Icons.sports_esports_rounded;
    return Icons.search_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RuntimeAppConfig>(
      valueListenable: RuntimeAppConfigService.listenable,
      builder: (context, runtime, _) {
        final info = _modeInfo(runtime);
        return Scaffold(
          backgroundColor: AppColors.lime,
          body: LayoutBuilder(
            builder: (context, viewport) {
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
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: desktop ? BorderRadius.circular(32) : BorderRadius.zero,
                    boxShadow: desktop
                        ? const [BoxShadow(color: Color(0x22000000), blurRadius: 28, offset: Offset(0, 14))]
                        : null,
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 2),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(.38)),
                                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                              ),
                              const Spacer(),
                              const Meet6MiniBrand(height: 26, forceLogo2: true),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 2, 22, 30),
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: _ModeOrbit(
                                    selectedIndex: modeIndex,
                                    premium: premium,
                                    loading: premiumLoading,
                                    onCenterTap: _cycleMode,
                                    onModeTap: (index) {
                                      const modes = ['text', 'voice', 'game'];
                                      _selectMode(modes[index]);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Center(
                                  child: Text(
                                    '6’ya bas, modu değiştir',
                                    style: TextStyle(color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Center(
                                  child: Text(
                                    'Odaya katılmadan önce',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 28,
                                      height: 1.02,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    'Meet6 odaları kısa, gerçek ve güvenli sohbetler için tasarlandı.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.navy.withOpacity(.72),
                                      fontSize: 12.5,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const _SectionTitle(
                                  title: 'Oda seçimi',
                                  subtitle: '6’nın çevresindeki modlardan birini seç.',
                                ),
                                const SizedBox(height: 10),
                                _SelectedModeCard(
                                  info: info,
                                  onTap: gameMode ? _openGamePicker : null,
                                  showChevron: gameMode,
                                ),
                                const SizedBox(height: 22),
                                const _SectionTitle(
                                  title: 'Süre seçimi',
                                  subtitle: 'Ne kadar sohbet etmek istersin?',
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DurationChoice(
                                        selected: roomDurationMinutes == 15,
                                        label: '15 dk',
                                        onTap: () => _selectDuration(15),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _DurationChoice(
                                        selected: roomDurationMinutes == 30,
                                        label: '30 dk',
                                        premium: true,
                                        disabled: fixedFifteenMode,
                                        onTap: () => _selectDuration(30),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  voiceMode
                                      ? 'Birebir sesli eşleşmeler 15 dakikadır.'
                                      : gameMode
                                          ? 'Mini oyun odaları 6 kişilik ve 15 dakikadır.'
                                          : '15 dk herkes için. 30 dk Premium üyelikte açılır.',
                                  style: TextStyle(
                                    color: AppColors.navy.withOpacity(.62),
                                    fontSize: 10.5,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const _SectionTitle(
                                  title: 'Oda kuralları',
                                  subtitle: 'Herkes için daha iyi bir deneyim.',
                                ),
                                const SizedBox(height: 10),
                                _RuleTile(
                                  icon: gameMode ? Icons.sports_esports_rounded : Icons.visibility_off_rounded,
                                  title: gameMode ? 'Oyun sohbeti başlatır' : 'Kararınız gizlidir',
                                  subtitle: gameMode
                                      ? '${selectedGameInfo.title} oda içinde sırayla oynanır.'
                                      : 'Görüşme bitince ${runtime.selectionSeconds} saniyelik gizli seçim başlar.',
                                ),
                                _RuleTile(
                                  icon: Icons.timer_rounded,
                                  title: 'Süre bitince görüşme kapanır',
                                  subtitle: 'İsterseniz oylamayla +${runtime.extensionMinutes} dakika uzatılabilir.',
                                ),
                                const _RuleTile(
                                  icon: Icons.favorite_rounded,
                                  title: 'Saygılı ve doğal ol',
                                  subtitle: 'Hakaret, taciz ve rahatsız edici davranışlara yer yok.',
                                  last: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
                          decoration: BoxDecoration(
                            color: AppColors.lime.withOpacity(.98),
                            boxShadow: [
                              BoxShadow(color: AppColors.navy.withOpacity(.08), blurRadius: 18, offset: const Offset(0, -8)),
                            ],
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: FilledButton(
                              onPressed: premiumLoading ? null : () => _startSearch(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                disabledBackgroundColor: AppColors.navy.withOpacity(.6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_searchIcon, size: 24),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      _searchLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GameInfo {
  const _GameInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.recommended = false,
    this.active = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool recommended;
  final bool active;
}

class _GamePickerTile extends StatelessWidget {
  const _GamePickerTile({required this.game, required this.selected, required this.onTap});

  final _GameInfo game;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          minHeight: 82,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(22),
            border: selected ? Border.all(color: Colors.white.withOpacity(.7), width: 1.5) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(game.icon, color: Colors.white, size: 29),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(.62), fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (game.recommended)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(99)),
                  child: const Text(
                    'Önerilen',
                    style: TextStyle(color: AppColors.navy, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
              Icon(
                game.active ? Icons.chevron_right_rounded : Icons.lock_clock_rounded,
                color: AppColors.lime,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeInfo {
  const _ModeInfo({required this.icon, required this.title, required this.subtitle, required this.pill});
  final IconData icon;
  final String title;
  final String subtitle;
  final String pill;
}

class _ModeOrbit extends StatelessWidget {
  const _ModeOrbit({
    required this.selectedIndex,
    required this.premium,
    required this.loading,
    required this.onCenterTap,
    required this.onModeTap,
  });

  final int selectedIndex;
  final bool premium;
  final bool loading;
  final VoidCallback onCenterTap;
  final ValueChanged<int> onModeTap;

  static const _icons = [Icons.groups_2_rounded, Icons.mic_rounded, Icons.sports_esports_rounded];
  static const _labels = ['Yazılı', 'Sesli', 'Mini Oyun'];

  @override
  Widget build(BuildContext context) {
    final targetTurns = -selectedIndex / 3;
    return SizedBox(
      width: 270,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 154,
            height: 154,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(.62), width: 1.5),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: targetTurns),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (context, turns, _) {
              final base = turns * 2 * math.pi - math.pi / 2;
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: List.generate(3, (index) {
                  final angle = base + index * (2 * math.pi / 3);
                  const radius = 76.0;
                  final selected = index == selectedIndex;
                  final locked = index == 1 && !premium;
                  return Transform.translate(
                    offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius),
                    child: GestureDetector(
                      onTap: loading ? null : () => onModeTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: selected ? 76 : 58,
                        height: selected ? 76 : 58,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.navy : Colors.white.withOpacity(.62),
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? AppColors.navy : AppColors.navy.withOpacity(.08)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navy.withOpacity(selected ? .18 : .07),
                              blurRadius: selected ? 18 : 10,
                              spreadRadius: selected ? 2 : 0,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _icons[index],
                                  color: selected ? AppColors.lime : AppColors.navy,
                                  size: selected ? 28 : 23,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _labels[index],
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: selected ? Colors.white : AppColors.navy,
                                    fontSize: selected ? 8.5 : 7.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            if (locked)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 19,
                                  height: 19,
                                  decoration: const BoxDecoration(color: Color(0xFFFFD968), shape: BoxShape.circle),
                                  child: const Icon(Icons.workspace_premium_rounded, color: AppColors.navy, size: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          GestureDetector(
            onTap: loading ? null : onCenterTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lime,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.white.withOpacity(.64), blurRadius: 22, spreadRadius: 5),
                  BoxShadow(color: AppColors.navy.withOpacity(.14), blurRadius: 24, spreadRadius: 5),
                ],
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.navy),
                    )
                  : const Text(
                      '6',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 64,
                        height: .9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedModeCard extends StatelessWidget {
  const _SelectedModeCard({required this.info, this.onTap, this.showChevron = false});

  final _ModeInfo info;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: AppColors.navy.withOpacity(.14), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: Colors.white.withOpacity(.1), shape: BoxShape.circle),
              child: Icon(info.icon, color: AppColors.lime, size: 29),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    info.subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 11, height: 1.25, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: info.pill == 'Premium' ? const Color(0xFFFFD968) : AppColors.lime,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                info.pill,
                style: const TextStyle(color: AppColors.navy, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.lime, size: 26),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 19,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: AppColors.navy.withOpacity(.67), fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DurationChoice extends StatelessWidget {
  const _DurationChoice({
    required this.selected,
    required this.label,
    required this.onTap,
    this.premium = false,
    this.disabled = false,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final bool premium;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.navy;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: disabled ? .55 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.white.withOpacity(disabled ? .25 : .4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.navy.withOpacity(.07)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule_rounded, color: foreground, size: 21),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(color: foreground, fontSize: 16, fontWeight: FontWeight.w900)),
              if (premium) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFFD968), borderRadius: BorderRadius.circular(999)),
                  child: const Icon(Icons.workspace_premium_rounded, color: AppColors.navy, size: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.icon, required this.title, required this.subtitle, this.last = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.36),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.navy.withOpacity(.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.lime, size: 22),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.navy, fontSize: 13.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppColors.navy.withOpacity(.66), fontSize: 10.5, height: 1.25, fontWeight: FontWeight.w600),
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
