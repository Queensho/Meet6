import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/tabu_game_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';

class TabuRoomScreen extends StatefulWidget {
  const TabuRoomScreen({
    super.key,
    required this.roomId,
    this.profileName = '',
  });

  final String roomId;
  final String profileName;

  @override
  State<TabuRoomScreen> createState() => _TabuRoomScreenState();
}

class _TabuRoomScreenState extends State<TabuRoomScreen> {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  Timer? pollTimer;
  Timer? clockTimer;
  Map<String, dynamic>? state;
  bool loading = true;
  bool sending = false;
  bool polling = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
    pollTimer = Timer.periodic(const Duration(milliseconds: 900), (_) => _load(silent: true));
    clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    clockTimer?.cancel();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (polling || !mounted) return;
    polling = true;
    try {
      final data = await TabuGameApiService.state(widget.roomId);
      if (!mounted) return;
      final oldMessageCount = (state?['messages'] is List) ? (state!['messages'] as List).length : 0;
      final newMessageCount = (data['messages'] is List) ? (data['messages'] as List).length : 0;
      setState(() {
        state = data;
        loading = false;
        error = null;
      });
      if (newMessageCount > oldMessageCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => error = e.message);
    } catch (_) {
      if (!mounted || silent) return;
      setState(() => error = 'Tabu odası yüklenemedi.');
    } finally {
      polling = false;
    }
  }

  void _scrollBottom() {
    if (!scrollController.hasClients) return;
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  int _secondsLeft(String key) {
    final raw = state?[key]?.toString();
    final end = raw == null ? null : DateTime.tryParse(raw);
    if (end == null) return 0;
    final seconds = end.difference(DateTime.now()).inSeconds;
    return seconds.clamp(0, 999);
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending || state == null) return;
    final isNarrator = state?['isNarrator'] == true;
    setState(() => sending = true);
    try {
      final data = isNarrator
          ? await TabuGameApiService.clue(widget.roomId, text)
          : await TabuGameApiService.guess(widget.roomId, text);
      if (!mounted) return;
      controller.clear();
      setState(() => state = data);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _pass() async {
    if (sending) return;
    setState(() => sending = true);
    try {
      final data = await TabuGameApiService.pass(widget.roomId);
      if (!mounted) return;
      setState(() => state = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Widget _top() {
    final narratorIndex = (state?['narratorIndex'] as num?)?.toInt() ?? 0;
    final total = (state?['totalNarrators'] as num?)?.toInt() ?? 6;
    final seconds = _secondsLeft('turnEndsAt');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(backgroundColor: Colors.white),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
          ),
          const SizedBox(width: 8),
          const Meet6MiniBrand(height: 25, forceLogo2: true),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(99)),
            child: const Text('TABU', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w900, fontSize: 11)),
          ),
          const Spacer(),
          Text('${narratorIndex + 1}/$total', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
            child: Text('$seconds', style: const TextStyle(color: AppColors.lime, fontSize: 19, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _scoreStrip() {
    final players = _maps(state?['players']);
    return SizedBox(
      height: 68,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final p = players[index];
          final narrator = p['id']?.toString() == state?['narratorUserId']?.toString();
          return Container(
            width: 112,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: narrator ? AppColors.lime : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: narrator ? AppColors.navy : const Color(0xFFE3E6EF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p['name']?.toString() ?? 'Oyuncu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text('${(p['xp'] as num?)?.toInt() ?? 0} XP', style: TextStyle(color: AppColors.navy.withOpacity(.65), fontSize: 10, fontWeight: FontWeight.w800)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _narratorCard() {
    final target = state?['target']?.toString() ?? '';
    final forbidden = (state?['forbidden'] is List)
        ? (state!['forbidden'] as List).map((e) => e.toString()).toList()
        : const <String>[];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(26)),
      child: Column(
        children: [
          const Text('ANLATACAĞIN KELİME', style: TextStyle(color: AppColors.lime, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 5),
          Text(target, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 13),
          const Text('Yasaklı kelimeler', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: forbidden
                .map((word) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(color: const Color(0xFFFF5C65), borderRadius: BorderRadius.circular(99)),
                      child: Text(word, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _guesserBanner() {
    final narrator = state?['narratorName']?.toString() ?? 'Anlatıcı';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.lime.withOpacity(.45), borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: AppColors.navy, child: Icon(Icons.campaign_rounded, color: AppColors.lime)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$narrator anlatıyor', style: const TextStyle(color: AppColors.navy, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('Hedef ve yasaklı kelimeler gizli. İlk doğru tahmini yazan +20 XP alır.', style: TextStyle(color: AppColors.navy.withOpacity(.68), fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _messages() {
    final messages = _maps(state?['messages']);
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state?['isNarrator'] == true
                ? 'İpucu yazmaya başla. Backend her mesajını yasaklı kelimelere karşı kontrol eder.'
                : 'Anlatıcının ipuçları burada görünecek.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.navy.withOpacity(.55), fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: messages.length,
      itemBuilder: (_, index) {
        final m = messages[index];
        final narrator = m['role']?.toString() == 'narrator';
        return Align(
          alignment: narrator ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 310),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: narrator ? AppColors.navy : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: narrator ? null : Border.all(color: const Color(0xFFE0E4EE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m['name']?.toString() ?? '', style: TextStyle(color: narrator ? AppColors.lime : const Color(0xFF4265E8), fontSize: 10, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(m['text']?.toString() ?? '', style: TextStyle(color: narrator ? Colors.white : AppColors.navy, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _composer() {
    final isNarrator = state?['isNarrator'] == true;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E8F0)))),
        child: Row(
          children: [
            if (isNarrator) ...[
              OutlinedButton(
                onPressed: sending ? null : _pass,
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF5A60), side: const BorderSide(color: Color(0xFFFFA4A8))),
                child: const Text('Pas geç', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !sending,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                maxLength: isNarrator ? 240 : 80,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: isNarrator ? 'Yazıyla anlat...' : 'Tahminini yaz...',
                  filled: true,
                  fillColor: const Color(0xFFF4F6FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : _send,
              style: IconButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.lime),
              icon: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime))
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wordResult() {
    final result = state?['lastResult'] is Map
        ? Map<String, dynamic>.from(state!['lastResult'] as Map)
        : <String, dynamic>{};
    final kind = result['kind']?.toString() ?? '';
    final target = result['target']?.toString() ?? '';
    final isCorrect = kind == 'correct';
    final isTabu = kind == 'tabu';
    final color = isCorrect ? const Color(0xFF55C934) : isTabu ? const Color(0xFFFF5A60) : const Color(0xFF8892A8);
    final title = isCorrect ? '$target bulundu 🎉' : isTabu ? 'TABU! 🚫' : '$target pas geçildi';
    final subtitle = isCorrect
        ? '${result['guesserName'] ?? 'Bir oyuncu'} +20 XP · ${result['narratorName'] ?? 'Anlatıcı'} +15 XP'
        : isTabu
            ? '“${result['forbiddenWord'] ?? ''}” yasaklı kelimesi kullanıldı · −10 XP'
            : 'Yeni kelime geliyor';
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(.08), blurRadius: 30)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isCorrect ? Icons.check_circle_rounded : isTabu ? Icons.block_rounded : Icons.skip_next_rounded, color: color, size: 58),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.navy, fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: AppColors.navy.withOpacity(.65), fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text('3 saniye sonra yeni kelime', style: TextStyle(color: Color(0xFF7B849B), fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _turnResult() {
    final turn = state?['currentTurn'] is Map
        ? Map<String, dynamic>.from(state!['currentTurn'] as Map)
        : <String, dynamic>{};
    final name = state?['narratorName']?.toString() ?? 'Anlatıcı';
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(30)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.timer_off_rounded, color: AppColors.lime, size: 48),
          const SizedBox(height: 12),
          Text('$name turu bitti', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _miniStat('${turn['correct'] ?? 0}', 'doğru'),
            _miniStat('${turn['tabu'] ?? 0}', 'tabu'),
            _miniStat('${turn['pass'] ?? 0}', 'pas'),
          ]),
          const SizedBox(height: 18),
          Text('${turn['xp'] ?? 0} XP', style: const TextStyle(color: AppColors.lime, fontSize: 31, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('3 saniye sonra anlatıcı değişir', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _miniStat(String value, String label) => Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w800)),
      ]);

  Widget _final() {
    final leaderboard = _maps(state?['leaderboard']);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(onPressed: () => Navigator.of(context).pop(), style: IconButton.styleFrom(backgroundColor: Colors.white), icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy)),
              const Spacer(),
              const Meet6MiniBrand(height: 26, forceLogo2: true),
            ]),
            const SizedBox(height: 24),
            const Text('Tabu bitti! 🎉', style: TextStyle(color: AppColors.navy, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
            const SizedBox(height: 6),
            Text('6 kişi de birer kez anlatıcı oldu. Final puan tablosu:', style: TextStyle(color: AppColors.navy.withOpacity(.62), fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            ...List.generate(leaderboard.length, (index) {
              final p = leaderboard[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: index == 0 ? AppColors.lime : Colors.white, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  Text('${index + 1}', style: const TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(p['name']?.toString() ?? 'Oyuncu', style: const TextStyle(color: AppColors.navy, fontSize: 17, fontWeight: FontWeight.w900))),
                  Text('${(p['xp'] as num?)?.toInt() ?? 0} XP', style: const TextStyle(color: AppColors.navy, fontSize: 16, fontWeight: FontWeight.w900)),
                ]),
              );
            }),
            const SizedBox(height: 14),
            SizedBox(
              height: 58,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: const Text('Ana sayfaya dön', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading && state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null && state == null) {
      return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center))));
    }
    final phase = state?['phase']?.toString() ?? 'play';
    if (phase == 'final') return _final();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _top(),
            _scoreStrip(),
            if (phase == 'play') state?['isNarrator'] == true ? _narratorCard() : _guesserBanner(),
            Expanded(
              child: phase == 'word_result'
                  ? _wordResult()
                  : phase == 'turn_result'
                      ? _turnResult()
                      : _messages(),
            ),
            if (phase == 'play') _composer(),
          ],
        ),
      ),
    );
  }
}
