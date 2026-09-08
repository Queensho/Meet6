import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
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

  static const pageBg = Color(0xFFF8F9FD);
  static const navy = AppColors.navy;
  static const lime = AppColors.lime;
  static const coral = Color(0xFFFF5F68);
  static const paleBlue = Color(0xFFE9EFFF);
  static const line = Color(0xFFE7E9F0);

  @override
  void initState() {
    super.initState();
    input.addListener(_inputChanged);
    _connect();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _inputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    sub?.cancel();
    clock?.cancel();
    input.removeListener(_inputChanged);
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

  List<Map<String, dynamic>> _maps(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> _messages(Map<String, dynamic>? source) => _maps(source?['messages']);

  int _secondsLeft(String key) {
    final end = DateTime.tryParse(state?[key]?.toString() ?? '');
    if (end == null) return 0;
    final ms = end.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) return 0;
    return math.min(999, (ms / 1000).ceil());
  }

  String _photo(Map<String, dynamic> p) {
    final raw = p['photoUrl']?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return raw;
    return '${AppConfig.apiBaseUrl}${raw.startsWith('/') ? raw : '/$raw'}';
  }

  void _scrollSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
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

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending || state?['phase']?.toString() != 'play') return;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget _avatar(Map<String, dynamic> p, {double radius = 24, bool ring = false, Color? ringColor}) {
    final name = p['name']?.toString() ?? 'Oyuncu';
    final photo = _photo(p);
    return Container(
      width: radius * 2 + 6,
      height: radius * 2 + 6,
      padding: EdgeInsets.all(ring ? 3 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring ? Border.all(color: ringColor ?? lime, width: 3) : null,
      ),
      child: ClipOval(
        child: photo.isEmpty
            ? Container(
                color: const Color(0xFFD9DDE8),
                alignment: Alignment.center,
                child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: navy, fontWeight: FontWeight.w900)),
              )
            : Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFD9DDE8),
                  alignment: Alignment.center,
                  child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: navy, fontWeight: FontWeight.w900)),
                ),
              ),
      ),
    );
  }

  Widget _header() {
    final index = (state?['narratorIndex'] as num?)?.toInt() ?? 0;
    final total = (state?['totalNarrators'] as num?)?.toInt() ?? 6;
    final seconds = _secondsLeft('turnEndsAt');
    final progress = (seconds / 60).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        SizedBox(
          width: 42,
          height: 42,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(backgroundColor: Colors.white),
            icon: const Icon(Icons.arrow_back_rounded, color: navy, size: 24),
          ),
        ),
        const SizedBox(width: 10),
        const Meet6MiniBrand(height: 23, forceLogo2: true),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(16)),
          child: const Text('TABU', style: TextStyle(color: lime, fontWeight: FontWeight.w900, fontSize: 11)),
        ),
        const Spacer(),
        Text('${index + 1}/$total', style: const TextStyle(color: navy, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        SizedBox(
          width: 46,
          height: 46,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                backgroundColor: const Color(0xFFE4E9C9),
                valueColor: const AlwaysStoppedAnimation<Color>(lime),
              ),
            ),
            Text('$seconds', style: const TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w900)),
          ]),
        ),
      ]),
    );
  }

  Widget _players() {
    final players = _maps(state?['players']);
    final narratorId = state?['narratorUserId']?.toString();
    final me = widget.profileName.trim();
    final guesserView = state?['isNarrator'] != true;

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = players[i];
          final isNarrator = p['id']?.toString() == narratorId;
          final name = p['name']?.toString() ?? 'Oyuncu';
          final isMe = me.isNotEmpty && name.trim() == me;
          return SizedBox(
            width: 60,
            child: Column(children: [
              _avatar(p, radius: 22, ring: guesserView ? isMe : isNarrator),
              const SizedBox(height: 2),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: navy, fontSize: 10.5, fontWeight: FontWeight.w900)),
              if (guesserView && isNarrator)
                const Text('Anlatıyor', style: TextStyle(color: Color(0xFF5038EA), fontSize: 8.5, fontWeight: FontWeight.w900)),
            ]),
          );
        },
      ),
    );
  }

  Widget _narratorCard() {
    final target = state?['target']?.toString() ?? '';
    final forbidden = state?['forbidden'] is List
        ? (state!['forbidden'] as List).map((e) => e.toString()).toList()
        : const <String>[];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(22)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(14)),
            child: const Text('ANLAT', style: TextStyle(color: navy, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              target,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 27, height: 1, fontWeight: FontWeight.w900),
            ),
          ),
        ]),
        const SizedBox(height: 9),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: forbidden.map((w) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: coral, borderRadius: BorderRadius.circular(16)),
              child: Text(w, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
            )).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _guesserCard() {
    final narrator = state?['narratorName']?.toString() ?? 'Anlatıcı';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF2FFD0), Color(0xFFE9FF9F)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: navy, shape: BoxShape.circle),
          child: const Icon(Icons.campaign_rounded, color: lime, size: 24),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('$narrator anlatıyor', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            const Text('Tahminini mesaj alanına yaz.', style: TextStyle(color: Color(0xFF666D7D), fontSize: 11.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _feed() {
    final messages = _messages(state);
    final players = _maps(state?['players']);

    Map<String, dynamic>? byId(String id) {
      for (final p in players) {
        if (p['id']?.toString() == id) return p;
      }
      return null;
    }

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final m = messages[i];
        final narratorMsg = m['role']?.toString() == 'narrator';
        final userId = m['userId']?.toString() ?? m['senderUserId']?.toString() ?? '';
        final p = byId(userId) ?? <String, dynamic>{'name': m['name']?.toString() ?? 'Oyuncu'};
        final name = m['name']?.toString() ?? p['name']?.toString() ?? 'Oyuncu';
        final at = DateTime.tryParse(m['at']?.toString() ?? '');
        final time = at == null ? '' : '${at.toLocal().hour.toString().padLeft(2, '0')}:${at.toLocal().minute.toString().padLeft(2, '0')}';

        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _avatar(p, radius: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      narratorMsg ? '$name · anlatıcı' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: narratorMsg ? const Color(0xFF1E79E9) : navy, fontSize: 11.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(time, style: const TextStyle(color: Color(0xFFA5A9B7), fontSize: 9.5)),
                ]),
                const SizedBox(height: 3),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: narratorMsg ? paleBlue : const Color(0xFFF0F1F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    m['text']?.toString() ?? '',
                    style: const TextStyle(color: navy, fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ]),
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
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: line))),
        child: Row(children: [
          if (narrator) ...[
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: enabled ? _skip : null,
                child: const Text('Pas', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: input,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                maxLength: narrator ? 200 : 80,
                style: const TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: narrator ? 'Kelimeyi anlat...' : 'Tahminini yaz...',
                  hintStyle: const TextStyle(color: Color(0xFFB1B5C3), fontSize: 13.5, fontWeight: FontWeight.w700),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFDDE1EA))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFDDE1EA))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFC9D0DE))),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 46,
            child: IconButton.filled(
              onPressed: enabled ? _send : null,
              style: IconButton.styleFrom(backgroundColor: navy, foregroundColor: lime),
              icon: sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: lime))
                  : const Icon(Icons.send_rounded, size: 24),
            ),
          ),
        ]),
      ),
    );
  }

  Map<String, dynamic>? _playerByName(String name) {
    for (final p in _maps(state?['players'])) {
      if (p['name']?.toString() == name) return p;
    }
    return null;
  }

  Widget _countdownBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(23)),
      child: Row(children: [
        const Expanded(child: Text('Devam ediyor...', style: TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w900))),
        Text('${_secondsLeft('phaseEndsAt')} sn', style: const TextStyle(color: navy, fontSize: 14, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _resultOverlay() {
    final result = state?['lastResult'] is Map
        ? Map<String, dynamic>.from(state!['lastResult'] as Map)
        : <String, dynamic>{};
    final kind = result['kind']?.toString() ?? '';
    final target = result['target']?.toString() ?? '';

    String title;
    String subtitle;
    IconData icon;
    Color iconBg;

    if (kind == 'tabu') {
      title = 'TABU!';
      subtitle = 'Yasaklı kelime kullanıldı. Sıradaki anlatıcı geliyor.';
      icon = Icons.block_rounded;
      iconBg = coral;
    } else if (kind == 'pass') {
      title = 'Pas geçildi!';
      subtitle = 'Aynı anlatıcı için yeni kelime geliyor.';
      icon = Icons.skip_next_rounded;
      iconBg = const Color(0xFF68728A);
    } else {
      title = target.isEmpty ? 'Doğru tahmin!' : '$target bulundu!';
      subtitle = 'Yeni kelime hazırlanıyor.';
      icon = Icons.check_rounded;
      iconBg = const Color(0xFF42C957);
    }

    return Stack(children: [
      Positioned.fill(child: Container(color: const Color(0xFF10172A).withOpacity(.58))),
      Center(
        child: Container(
          width: 340,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(color: iconBg.withOpacity(.14), shape: BoxShape.circle),
              child: Icon(icon, color: iconBg, size: 48),
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: navy, fontSize: 27, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7F8598), fontSize: 14, height: 1.35, fontWeight: FontWeight.w700)),
            if (kind == 'tabu') ...[
              const SizedBox(height: 10),
              Text(
                result['forbiddenWord']?.toString() ?? '',
                style: const TextStyle(color: coral, fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
            const SizedBox(height: 18),
            _countdownBar(),
          ]),
        ),
      ),
    ]);
  }

  Widget _turnResult() {
    final t = state?['currentTurn'] is Map
        ? Map<String, dynamic>.from(state!['currentTurn'] as Map)
        : <String, dynamic>{};
    final narrator = state?['narratorName']?.toString() ?? 'Anlatıcı';
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(28)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$narrator’nun turu bitti', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Text('${t['correct'] ?? 0} doğru · ${t['tabu'] ?? 0} tabu · ${t['pass'] ?? 0} pas', style: const TextStyle(color: lime, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('${_secondsLeft('phaseEndsAt')} sn sonra sıradaki anlatıcı', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _final() {
    final board = _maps(state?['leaderboard']);
    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded, color: navy)),
              const Spacer(),
              const Meet6MiniBrand(height: 27, forceLogo2: true),
            ]),
            const SizedBox(height: 20),
            const Text('Tabu sonucu', style: TextStyle(color: navy, fontSize: 34, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: board.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = board[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: i == 0 ? lime.withOpacity(.35) : Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      SizedBox(width: 32, child: Text('${i + 1}.', style: const TextStyle(color: navy, fontSize: 18, fontWeight: FontWeight.w900))),
                      _avatar(p, radius: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(p['name']?.toString() ?? 'Oyuncu', style: const TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w900))),
                      Text('${(p['xp'] as num?)?.toInt() ?? 0} XP', style: const TextStyle(color: Color(0xFF4265E8), fontSize: 15, fontWeight: FontWeight.w900)),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _playLayer() {
    final narrator = state?['isNarrator'] == true;
    return Column(children: [
      _header(),
      _players(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Text(error!, style: const TextStyle(color: Color(0xFFD65A60), fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      narrator ? _narratorCard() : _guesserCard(),
      Expanded(child: _feed()),
      _composer(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final phase = state?['phase']?.toString() ?? 'play';
    if (phase == 'final') return _final();

    if (phase == 'word_result') {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: pageBg,
        body: SafeArea(
          child: Stack(children: [
            Positioned.fill(child: _playLayer()),
            Positioned.fill(child: _resultOverlay()),
          ]),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: pageBg,
      body: SafeArea(
        child: phase == 'turn_result'
            ? Column(children: [_header(), _players(), Expanded(child: _turnResult())])
            : _playLayer(),
      ),
    );
  }
}
