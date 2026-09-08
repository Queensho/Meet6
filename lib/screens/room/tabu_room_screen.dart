import 'dart:async';

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

  List<Map<String, dynamic>> _messages(Map<String, dynamic>? source) =>
      _maps(source?['messages']);

  int _secondsLeft(String key) {
    final end = DateTime.tryParse(state?[key]?.toString() ?? '');
    if (end == null) return 0;
    return end.difference(DateTime.now()).inSeconds.clamp(0, 999);
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

  Widget _avatar(Map<String, dynamic> p, {double radius = 25, bool ring = false}) {
    final name = p['name']?.toString() ?? 'Oyuncu';
    final photo = _photo(p);
    return Container(
      width: radius * 2 + 6,
      height: radius * 2 + 6,
      padding: EdgeInsets.all(ring ? 3 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring ? Border.all(color: lime, width: 3) : null,
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 7),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: navy.withOpacity(.05), blurRadius: 12)]),
          child: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded, color: navy, size: 29)),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Meet6MiniBrand(height: 27, forceLogo2: true),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(20)),
                child: const Text('TABU', style: TextStyle(color: lime, fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 5),
            const Text('6 kişi · Kelimelerle eğlen', style: TextStyle(color: Color(0xFF8D93A6), fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        Container(
          width: 57,
          height: 57,
          decoration: BoxDecoration(color: const Color(0xFFF2F0FF), borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${index + 1}/$total', style: const TextStyle(color: navy, fontSize: 17, fontWeight: FontWeight.w900)),
            const Text('Tur', style: TextStyle(color: Color(0xFF8E93A5), fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 61,
          height: 61,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 61,
              height: 61,
              child: CircularProgressIndicator(value: progress, strokeWidth: 7, backgroundColor: const Color(0xFFE4E9C9), valueColor: const AlwaysStoppedAnimation<Color>(lime)),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: navy, shape: BoxShape.circle),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$seconds', style: const TextStyle(color: lime, fontSize: 18, height: 1, fontWeight: FontWeight.w900)),
                const Text('sn', style: TextStyle(color: Colors.white, fontSize: 9)),
              ]),
            ),
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
      height: guesserView ? 134 : 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 13),
        itemBuilder: (_, i) {
          final p = players[i];
          final isNarrator = p['id']?.toString() == narratorId;
          final name = p['name']?.toString() ?? 'Oyuncu';
          final xp = (p['xp'] as num?)?.toInt() ?? 0;
          final isMe = me.isNotEmpty && name.trim() == me;
          final ring = guesserView ? isMe : isNarrator;

          return SizedBox(
            width: 72,
            child: Column(children: [
              Stack(clipBehavior: Clip.none, children: [
                _avatar(p, radius: 29, ring: ring),
                Positioned(
                  right: -1,
                  bottom: 2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: const Color(0xFF16A13A), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: navy, fontSize: 12.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              if (guesserView && isNarrator)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFE9E6FF), borderRadius: BorderRadius.circular(14)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.volume_up_rounded, color: Color(0xFF5038EA), size: 13),
                    SizedBox(width: 3),
                    Text('Anlatıyor', style: TextStyle(color: Color(0xFF5038EA), fontSize: 9.5, fontWeight: FontWeight.w900)),
                  ]),
                )
              else if (guesserView && isMe)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
                  decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(18)),
                  child: Text('$xp XP', style: const TextStyle(color: navy, fontSize: 10.5, fontWeight: FontWeight.w900)),
                )
              else
                Text('$xp XP', style: const TextStyle(color: Color(0xFF8E93A5), fontSize: 10.5, fontWeight: FontWeight.w700)),
            ]),
          );
        },
      ),
    );
  }

  Widget _narratorCard() {
    final target = state?['target']?.toString() ?? '';
    final forbidden = state?['forbidden'] is List ? (state!['forbidden'] as List).map((e) => e.toString()).toList() : const <String>[];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: const Color(0xFF162B77).withOpacity(.10), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(18)),
          child: const Text('ANLATACAĞIN KELİME', style: TextStyle(color: navy, fontSize: 13, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 18),
        Text(target, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 38, height: 1, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
        const SizedBox(height: 22),
        const Text('Yasaklı kelimeler (kullanamazsın)', style: TextStyle(color: Color(0xFFBFC4D5), fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 13),
        Wrap(spacing: 9, runSpacing: 9, alignment: WrapAlignment.center, children: forbidden.map((w) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: coral, borderRadius: BorderRadius.circular(23)),
          child: Text(w, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        )).toList()),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFF26386F), borderRadius: BorderRadius.circular(14)),
          child: const Row(children: [
            Icon(Icons.lightbulb_rounded, color: Color(0xFFFFD84D), size: 23),
            SizedBox(width: 10),
            Expanded(child: Text('İpucu: Kelimeyi anlatırken yasaklı kelimeleri ve bunların köklerini kullanmamaya dikkat et.', style: TextStyle(color: Colors.white, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w700))),
          ]),
        ),
      ]),
    );
  }

  Widget _guesserCard() {
    final narrator = state?['narratorName']?.toString() ?? 'Anlatıcı';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 3, 20, 12),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF2FFD0), Color(0xFFE9FF9F)]),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(color: navy, shape: BoxShape.circle),
          child: const Icon(Icons.campaign_rounded, color: lime, size: 42),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$narrator anlatıyor', style: const TextStyle(color: navy, fontSize: 24, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -.6)),
            const SizedBox(height: 8),
            const Text(
              'Hedef kelime ve yasaklı kelimeler sana gösterilmez.\nİlk doğru tahmin +20 XP.',
              style: TextStyle(color: Color(0xFF666D7D), fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _systemHint({required bool correct}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: correct ? const Color(0xFFE9FFD1) : const Color(0xFFF0ECFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(correct ? Icons.check_circle_rounded : Icons.group_rounded, color: correct ? const Color(0xFF71D82C) : const Color(0xFF583DF2), size: 23),
          const SizedBox(width: 9),
          Text(
            correct ? 'Doğru tahmin için\ndevam edin!' : 'Sadece tahmin yazın,\nsohbet etmeyin.',
            style: TextStyle(color: correct ? navy : const Color(0xFF4938C8), fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w800),
          ),
        ]),
      ),
    );
  }

  Widget _feed() {
    final messages = _messages(state);
    final players = _maps(state?['players']);
    final guesserView = state?['isNarrator'] != true;

    Map<String, dynamic>? byId(String id) {
      for (final p in players) {
        if (p['id']?.toString() == id) return p;
      }
      return null;
    }

    final hintInsert = messages.length >= 3 ? 3 : messages.length;
    final extra = guesserView ? 2 : 0;

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(28, 8, 22, 16),
      itemCount: messages.length + extra,
      itemBuilder: (_, rawIndex) {
        if (guesserView && rawIndex == hintInsert) return _systemHint(correct: true);
        if (guesserView && rawIndex == hintInsert + 1) return _systemHint(correct: false);
        var i = rawIndex;
        if (guesserView && rawIndex > hintInsert + 1) i -= 2;
        if (i < 0 || i >= messages.length) return const SizedBox.shrink();

        final m = messages[i];
        final narratorMsg = m['role']?.toString() == 'narrator';
        final userId = m['userId']?.toString() ?? m['senderUserId']?.toString() ?? '';
        final p = byId(userId) ?? <String, dynamic>{'name': m['name']?.toString() ?? 'Oyuncu'};
        final name = m['name']?.toString() ?? p['name']?.toString() ?? 'Oyuncu';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              _avatar(p, radius: 24),
              Positioned(right: 1, bottom: 1, child: Container(width: 9, height: 9, decoration: BoxDecoration(color: const Color(0xFF16A13A), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.2)))),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(narratorMsg ? '$name (Anlatıyor)' : name, overflow: TextOverflow.ellipsis, style: TextStyle(color: narratorMsg ? const Color(0xFF1E79E9) : navy, fontSize: 13, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 10),
                  Text(m['time']?.toString() ?? '', style: const TextStyle(color: Color(0xFFA5A9B7), fontSize: 11.5)),
                ]),
                const SizedBox(height: 5),
                Container(
                  constraints: const BoxConstraints(maxWidth: 330),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  decoration: BoxDecoration(color: narratorMsg ? paleBlue : const Color(0xFFF0F1F5), borderRadius: BorderRadius.circular(16)),
                  child: Text(m['text']?.toString() ?? '', style: const TextStyle(color: navy, fontSize: 14.5, height: 1.3, fontWeight: FontWeight.w600)),
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
        padding: narrator ? const EdgeInsets.fromLTRB(18, 10, 18, 9) : const EdgeInsets.fromLTRB(22, 13, 22, 14),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (narrator) ...[
            SizedBox(
              width: 116,
              child: Column(children: [
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: enabled ? _skip : null,
                    style: OutlinedButton.styleFrom(foregroundColor: coral, side: const BorderSide(color: Color(0xFFFFA3AA)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27))),
                    icon: const Icon(Icons.skip_next_rounded, size: 19),
                    label: const Text('Pas geç', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Bu kelimeyi geç', style: TextStyle(color: Color(0xFF9AA0B0), fontSize: 10.5)),
              ]),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(children: [
              SizedBox(
                height: narrator ? 52 : 58,
                child: TextField(
                  controller: input,
                  enabled: enabled,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  maxLength: narrator ? 200 : 80,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: narrator ? 'Mesajını yaz, kelimeyi anlat...' : 'Tahminini yaz...',
                    hintStyle: const TextStyle(color: Color(0xFFB1B5C3), fontSize: 15, fontWeight: FontWeight.w700),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFDDE1EA))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFDDE1EA))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFC9D0DE))),
                  ),
                ),
              ),
              if (narrator) ...[
                const SizedBox(height: 5),
                Align(alignment: Alignment.centerRight, child: Text('${input.text.length}/200', style: const TextStyle(color: Color(0xFF9AA0B0), fontSize: 10.5))),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: narrator ? 56 : 60,
            height: narrator ? 56 : 60,
            child: IconButton.filled(
              onPressed: enabled ? _send : null,
              style: IconButton.styleFrom(backgroundColor: navy, foregroundColor: lime, disabledBackgroundColor: navy),
              icon: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: lime))
                  : const Icon(Icons.send_rounded, size: 30),
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

  Widget _result() {
    final result = state?['lastResult'] is Map ? Map<String, dynamic>.from(state!['lastResult'] as Map) : <String, dynamic>{};
    final kind = result['kind']?.toString() ?? '';
    final correct = kind == 'correct';
    final tabu = kind == 'tabu';
    final target = result['target']?.toString() ?? '';

    if (!correct) {
      final title = tabu ? 'TABU!' : '$target pas geçildi';
      final subtitle = tabu
          ? (state?['isNarrator'] == true ? 'Yasaklı kelime: ${result['forbiddenWord'] ?? ''} · −10 XP' : 'Anlatıcı tabu yaptı · −10 XP')
          : 'Yeni kelime geliyor...';
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(tabu ? Icons.block_rounded : Icons.skip_next_rounded, color: tabu ? coral : const Color(0xFF77839B), size: 58),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: navy, fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF70778B), fontWeight: FontWeight.w800)),
          ]),
        ),
      );
    }

    final guesserName = result['guesserName']?.toString() ?? 'Oyuncu';
    final narratorName = result['narratorName']?.toString() ?? 'Anlatıcı';
    final guesser = _playerByName(guesserName) ?? <String, dynamic>{'name': guesserName};
    final narrator = _playerByName(narratorName) ?? <String, dynamic>{'name': narratorName};

    Widget scoreCard(Map<String, dynamic> p, String label, String xp, Color accent) {
      final name = p['name']?.toString() ?? 'Oyuncu';
      return Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(color: const Color(0xFFF7F8FC), borderRadius: BorderRadius.circular(25)),
          child: Column(children: [
            _avatar(p, radius: 42, ring: true),
            const SizedBox(height: 8),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(xp, style: TextStyle(color: accent, fontSize: 19, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Color(0xFF858B9E), fontSize: 12)),
          ]),
        ),
      );
    }

    return Stack(children: [
      Positioned.fill(child: Container(color: navy.withOpacity(.22))),
      Center(
        child: Container(
          width: 360,
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: navy.withOpacity(.18), blurRadius: 36, offset: const Offset(0, 18))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 92, height: 92, decoration: const BoxDecoration(color: Color(0xFFDFFF85), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Color(0xFF42C957), size: 58)),
            const SizedBox(height: 14),
            Text('$target bulundu!', textAlign: TextAlign.center, style: const TextStyle(color: navy, fontSize: 28, height: 1.05, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('Tebrikler! Doğru tahmin edildi.', style: TextStyle(color: Color(0xFF7F8598), fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Row(children: [
              scoreCard(guesser, 'Doğru tahmin', '+20 XP', const Color(0xFF38C850)),
              const SizedBox(width: 12),
              scoreCard(narrator, 'Anlattı', '+15 XP', const Color(0xFF5A6FF0)),
            ]),
            const SizedBox(height: 20),
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(28)),
              child: Row(children: [
                const Expanded(child: Text('Devam ediyor...', textAlign: TextAlign.center, style: TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w900))),
                Text('${_secondsLeft('phaseEndsAt')} sn', style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(width: 5),
                const Icon(Icons.chevron_right_rounded, color: navy, size: 26),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _turnResult() {
    final t = state?['currentTurn'] is Map ? Map<String, dynamic>.from(state!['currentTurn'] as Map) : <String, dynamic>{};
    final narrator = state?['narratorName']?.toString() ?? 'Anlatıcı';
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(28)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$narrator’nun turu bitti', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Text('${t['correct'] ?? 0} doğru   ·   ${t['tabu'] ?? 0} tabu   ·   ${t['pass'] ?? 0} pas', style: const TextStyle(color: lime, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Toplam ${(t['xp'] as num?)?.toInt() ?? 0} XP', style: const TextStyle(color: Colors.white70, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
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
              IconButton(onPressed: () => Navigator.of(context).pop(), style: IconButton.styleFrom(backgroundColor: Colors.white), icon: const Icon(Icons.arrow_back_rounded, color: navy)),
              const Spacer(),
              const Meet6MiniBrand(height: 27, forceLogo2: true),
            ]),
            const SizedBox(height: 24),
            const Text('Tabu sonucu', style: TextStyle(color: navy, fontSize: 38, height: 1, fontWeight: FontWeight.w900, letterSpacing: -1.4)),
            const SizedBox(height: 8),
            const Text('6 anlatıcı turu tamamlandı · Final puan tablosu', style: TextStyle(color: Color(0xFF7F8598), fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: board.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = board[i];
                  final name = p['name']?.toString() ?? 'Oyuncu';
                  return Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: i == 0 ? lime.withOpacity(.35) : Colors.white, borderRadius: BorderRadius.circular(22)),
                    child: Row(children: [
                      SizedBox(width: 34, child: Text('${i + 1}.', style: const TextStyle(color: navy, fontSize: 20, fontWeight: FontWeight.w900))),
                      _avatar(p, radius: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name, style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w900))),
                      Text('${(p['xp'] as num?)?.toInt() ?? 0} XP', style: const TextStyle(color: Color(0xFF4265E8), fontSize: 16, fontWeight: FontWeight.w900)),
                    ]),
                  );
                },
              ),
            ),
            SizedBox(
              height: 58,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
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
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (state?['phase']?.toString() == 'final') return _final();

    final phase = state?['phase']?.toString() ?? 'play';
    final narrator = state?['isNarrator'] == true;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: pageBg,
      body: SafeArea(
        child: Column(children: [
          _header(),
          _players(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Text(error!, style: const TextStyle(color: Color(0xFFD65A60), fontSize: 10.5, fontWeight: FontWeight.w800)),
            ),
          if (phase == 'play') narrator ? _narratorCard() : _guesserCard(),
          Expanded(child: phase == 'word_result' ? _result() : phase == 'turn_result' ? _turnResult() : _feed()),
          if (phase == 'play') _composer(),
        ]),
      ),
    );
  }
}
