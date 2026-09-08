import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/tabu_game_api_service.dart';
import '../../services/tabu_realtime_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';

class TabuRoomScreen extends StatefulWidget {
  const TabuRoomScreen({super.key, required this.roomId, this.profileName = ''});
  final String roomId;
  final String profileName;

  @override
  State<TabuRoomScreen> createState() => _TabuRoomScreenState();
}

class _TabuRoomScreenState extends State<TabuRoomScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  StreamSubscription<TabuRealtimeEvent>? sub;
  Timer? clock;
  Map<String, dynamic>? state;
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _connect();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    clock?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _stateFrom(Map<String, dynamic> data) {
    final raw = data['state'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (data['game']?.toString() == 'tabu') return data;
    return null;
  }

  Future<void> _connect() async {
    await sub?.cancel();
    sub = TabuRealtimeService.events.listen((event) {
      if (!mounted) return;
      final roomId = event.data['roomId']?.toString();
      if (roomId != null && roomId.isNotEmpty && roomId != widget.roomId) return;
      final next = _stateFrom(event.data);
      if (next != null) {
        final before = _messages(state).length;
        setState(() {
          state = next;
          loading = false;
          error = null;
        });
        if (_messages(next).length > before) _scrollSoon();
      }
      if (event.type == 'connection:disconnected') {
        setState(() => error = 'Bağlantı yenileniyor...');
      }
    });
    try {
      final joined = await TabuRealtimeService.join(widget.roomId);
      if (!mounted) return;
      final next = _stateFrom(joined);
      if (next == null) throw const ApiException('Tabu durumu alınamadı.');
      setState(() {
        state = next;
        loading = false;
        error = null;
      });
    } on ApiException catch (e) {
      try {
        final fallback = await TabuGameApiService.state(widget.roomId);
        if (!mounted) return;
        setState(() {
          state = fallback;
          loading = false;
          error = 'Canlı bağlantı yeniden kuruluyor.';
        });
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted) _connect();
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          loading = false;
          error = e.message;
        });
      }
    }
  }

  List<Map<String, dynamic>> _maps(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> _messages(Map<String, dynamic>? source) => _maps(source?['messages']);

  int _secondsLeft(String key) {
    final end = DateTime.tryParse(state?[key]?.toString() ?? '');
    if (end == null) return 0;
    return end.difference(DateTime.now()).inSeconds.clamp(0, 999);
  }

  void _scrollSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending || state == null || state?['phase']?.toString() != 'play') return;
    setState(() => sending = true);
    try {
      final result = state?['isNarrator'] == true
          ? await TabuRealtimeService.speakerMessage(widget.roomId, text)
          : await TabuRealtimeService.guess(widget.roomId, text);
      final next = _stateFrom(result);
      if (!mounted) return;
      input.clear();
      if (next != null) setState(() => state = next);
      _scrollSoon();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _skip() async {
    if (sending || state?['isNarrator'] != true || state?['phase']?.toString() != 'play') return;
    setState(() => sending = true);
    try {
      final result = await TabuRealtimeService.skip(widget.roomId);
      final next = _stateFrom(result);
      if (mounted && next != null) setState(() => state = next);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget _header() {
    final index = (state?['narratorIndex'] as num?)?.toInt() ?? 0;
    final total = (state?['totalNarrators'] as num?)?.toInt() ?? 6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(backgroundColor: Colors.white),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
        ),
        const SizedBox(width: 8),
        const Meet6MiniBrand(height: 25, forceLogo2: true),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(99)),
          child: const Text('TABU', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w900, fontSize: 10)),
        ),
        const Spacer(),
        Text('${index + 1}/$total', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
          child: Text('${_secondsLeft('turnEndsAt')}', style: const TextStyle(color: AppColors.lime, fontSize: 18, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }

  Widget _players() {
    final players = _maps(state?['players']);
    final narratorId = state?['narratorUserId']?.toString();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = players[i];
          final active = p['id']?.toString() == narratorId;
          final name = p['name']?.toString() ?? 'Oyuncu';
          return Container(
            width: 106,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.lime : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: active ? AppColors.navy : const Color(0xFFE5E8F0)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.navy,
                child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 7),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.navy, fontSize: 10.5, fontWeight: FontWeight.w900)),
                Text('${(p['xp'] as num?)?.toInt() ?? 0} XP', style: TextStyle(color: AppColors.navy.withOpacity(.6), fontSize: 9, fontWeight: FontWeight.w800)),
              ])),
            ]),
          );
        },
      ),
    );
  }

  Widget _roleCard() {
    if (state?['isNarrator'] == true) {
      final target = state?['target']?.toString() ?? '';
      final forbidden = (state?['forbidden'] is List) ? (state!['forbidden'] as List).map((e) => e.toString()).toList() : const <String>[];
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(26)),
        child: Column(children: [
          const Text('ANLATACAĞIN KELİME', style: TextStyle(color: AppColors.lime, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 5),
          Text(target, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 12),
          const Text('Yasaklı kelimeler', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: forbidden.map((w) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xFFFF5A60), borderRadius: BorderRadius.circular(99)),
              child: Text(w, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            )).toList(),
          ),
        ]),
      );
    }
    final narrator = state?['narratorName']?.toString() ?? 'Anlatıcı';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.lime.withOpacity(.42), borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        const CircleAvatar(backgroundColor: AppColors.navy, child: Icon(Icons.campaign_rounded, color: AppColors.lime)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$narrator anlatıyor', style: const TextStyle(color: AppColors.navy, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('Hedef kelime ve yasaklı kelimeler sana gönderilmez. İlk doğru tahmin +20 XP.', style: TextStyle(color: AppColors.navy.withOpacity(.68), fontSize: 10.5, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }

  Widget _feed() {
    final messages = _messages(state);
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final m = messages[i];
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['name']?.toString() ?? '', style: TextStyle(color: narrator ? AppColors.lime : const Color(0xFF4265E8), fontSize: 10, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(m['text']?.toString() ?? '', style: TextStyle(color: narrator ? Colors.white : AppColors.navy, fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      },
    );
  }

  Widget _composer() {
    final narrator = state?['isNarrator'] == true;
    final enabled = state?['phase']?.toString() == 'play' && !sending;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E8F0)))),
        child: Row(children: [
          if (narrator) ...[
            OutlinedButton(
              onPressed: enabled ? _skip : null,
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF5A60), side: const BorderSide(color: Color(0xFFFFA4A8))),
              child: const Text('Pas geç', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: TextField(
            controller: input,
            enabled: enabled,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            maxLength: narrator ? 240 : 80,
            decoration: InputDecoration(
              counterText: '',
              hintText: narrator ? 'Mesajını yaz, kelimeyi anlat...' : 'Tahminini yaz...',
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          )),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: enabled ? _send : null,
            style: IconButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.lime),
            icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime)) : const Icon(Icons.send_rounded),
          ),
        ]),
      ),
    );
  }

  Widget _result() {
    final result = state?['lastResult'] is Map ? Map<String, dynamic>.from(state!['lastResult'] as Map) : <String, dynamic>{};
    final kind = result['kind']?.toString() ?? '';
    final correct = kind == 'correct';
    final tabu = kind == 'tabu';
    final target = result['target']?.toString() ?? '';
    final title = correct ? '$target bulundu 🎉' : tabu ? 'TABU! 🚫' : '$target pas geçildi';
    final subtitle = correct
        ? '${result['guesserName'] ?? 'Bir oyuncu'} +20 XP\n${result['narratorName'] ?? 'Anlatıcı'} +15 XP'
        : tabu
            ? (state?['isNarrator'] == true ? 'Yasaklı kelime: ${result['forbiddenWord'] ?? ''} · −10 XP' : 'Anlatıcı tabu yaptı · −10 XP')
            : 'Yeni kelime geliyor...';
    return Center(child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(.08), blurRadius: 24)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(correct ? Icons.check_circle_rounded : tabu ? Icons.block_rounded : Icons.skip_next_rounded, color: correct ? const Color(0xFF52C934) : tabu ? const Color(0xFFFF5A60) : const Color(0xFF77839B), size: 58),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.navy, fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: AppColors.navy.withOpacity(.68), height: 1.45, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text('${_secondsLeft('phaseEndsAt')} sn', style: const TextStyle(color: Color(0xFF4265E8), fontWeight: FontWeight.w900)),
      ]),
    ));
  }

  Widget _turnResult() {
    final t = state?['currentTurn'] is Map ? Map<String, dynamic>.from(state!['currentTurn'] as Map) : <String, dynamic>{};
    final narrator = state?['narratorName']?.toString() ?? 'Anlatıcı';
    return Center(child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(28)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$narrator’nun turu bitti', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Text('${t['correct'] ?? 0} doğru   ·   ${t['tabu'] ?? 0} tabu   ·   ${t['pass'] ?? 0} pas', style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Toplam ${(t['xp'] as num?)?.toInt() ?? 0} XP', style: const TextStyle(color: Colors.white70, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('${_secondsLeft('phaseEndsAt')} sn sonra sıradaki anlatıcı', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ));
  }

  Widget _final() {
    final board = _maps(state?['leaderboard']);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconButton(onPressed: () => Navigator.of(context).pop(), style: IconButton.styleFrom(backgroundColor: Colors.white), icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy)),
            const Spacer(),
            const Meet6MiniBrand(height: 27, forceLogo2: true),
          ]),
          const SizedBox(height: 24),
          const Text('Tabu sonucu', style: TextStyle(color: AppColors.navy, fontSize: 38, height: 1, fontWeight: FontWeight.w900, letterSpacing: -1.4)),
          const SizedBox(height: 8),
          Text('6 anlatıcı turu tamamlandı · Final puan tablosu', style: TextStyle(color: AppColors.navy.withOpacity(.58), fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Expanded(child: ListView.separated(
            itemCount: board.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = board[i];
              final name = p['name']?.toString() ?? 'Oyuncu';
              return Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: i == 0 ? AppColors.lime.withOpacity(.35) : Colors.white, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  SizedBox(width: 34, child: Text('${i + 1}.', style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900))),
                  CircleAvatar(backgroundColor: AppColors.navy, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(name, style: const TextStyle(color: AppColors.navy, fontSize: 16, fontWeight: FontWeight.w900))),
                  Text('${(p['xp'] as num?)?.toInt() ?? 0} XP', style: const TextStyle(color: Color(0xFF4265E8), fontSize: 16, fontWeight: FontWeight.w900)),
                ]),
              );
            },
          )),
          SizedBox(height: 58, child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(backgroundColor: AppColors.lime, foregroundColor: AppColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: const Text('Ana sayfaya dön', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          )),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (state?['phase']?.toString() == 'final') return _final();
    final phase = state?['phase']?.toString() ?? 'play';
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(child: Column(children: [
        _header(),
        _players(),
        if (error != null) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(error!, style: const TextStyle(color: Color(0xFFD65A60), fontSize: 10.5, fontWeight: FontWeight.w800)),
        ),
        if (phase == 'play') _roleCard(),
        Expanded(child: phase == 'word_result' ? _result() : phase == 'turn_result' ? _turnResult() : _feed()),
        if (phase == 'play') _composer(),
      ])),
    );
  }
}
