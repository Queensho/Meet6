import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/red_flag_game_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import '../messages/private_chat_screen.dart';

class RedFlagGreenFlagRoomScreenV2 extends StatefulWidget {
  const RedFlagGreenFlagRoomScreenV2({super.key, required this.roomId, this.profileName = ''});
  final String roomId;
  final String profileName;

  @override
  State<RedFlagGreenFlagRoomScreenV2> createState() => _RedFlagGreenFlagRoomScreenV2State();
}

class _RedFlagGreenFlagRoomScreenV2State extends State<RedFlagGreenFlagRoomScreenV2> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  final messages = <Map<String, dynamic>>[];
  Map<String, dynamic>? state;
  Timer? timer;
  bool loading = true;
  bool sending = false;
  String? error;
  int lastMessageId = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  String get phase => state?['phase']?.toString() ?? 'choice';
  int get questionIndex => (state?['questionIndex'] as num?)?.toInt() ?? 0;
  Map<String, dynamic> get question => state?['question'] is Map ? Map<String, dynamic>.from(state!['question'] as Map) : {};
  List<Map<String, dynamic>> get players => state?['players'] is List
      ? (state!['players'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];
  Map<String, dynamic>? get recommendation => state?['recommendation'] is Map ? Map<String, dynamic>.from(state!['recommendation'] as Map) : null;
  Map<String, dynamic> get decision => state?['finalDecision'] is Map ? Map<String, dynamic>.from(state!['finalDecision'] as Map) : {};

  Duration get remaining {
    final end = DateTime.tryParse(state?['phaseEndsAt']?.toString() ?? '');
    if (end == null) return Duration.zero;
    final d = end.toLocal().difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  String _clock(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _photo(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return raw;
    return '${AppConfig.apiBaseUrl}${raw.startsWith('/') ? raw : '/$raw'}';
  }

  void _goHome() => Navigator.of(context).popUntil((route) => route.isFirst);

  Future<void> _refresh({bool silent = false}) async {
    try {
      final data = await RedFlagGameApiService.state(widget.roomId);
      if (!mounted) return;
      setState(() {
        state = data;
        loading = false;
        if (!silent) error = null;
      });
      if (data['phase']?.toString() == 'discussion') await _loadMessages();
    } on ApiException catch (e) {
      if (!mounted || silent) return;
      setState(() { loading = false; error = e.message; });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() { loading = false; error = 'Red Flag / Green Flag yüklenemedi.'; });
    }
  }

  Future<void> _choose(String choice) async {
    if (loading || state?['myChoice'] != null) return;
    setState(() => loading = true);
    try {
      final data = await RedFlagGameApiService.choose(widget.roomId, choice);
      if (!mounted) return;
      setState(() { state = data; loading = false; });
      if (data['phase']?.toString() == 'discussion') await _loadMessages();
    } on ApiException catch (e) {
      if (mounted) setState(() { loading = false; error = e.message; });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final incoming = await RedFlagGameApiService.messages(widget.roomId, after: lastMessageId);
      if (!mounted || incoming.isEmpty) return;
      setState(() {
        for (final m in incoming) {
          final id = int.tryParse(m['id']?.toString() ?? '') ?? 0;
          if (id > lastMessageId) lastMessageId = id;
          if (!messages.any((old) => old['id']?.toString() == m['id']?.toString())) messages.add(m);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
        }
      });
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending || phase != 'discussion') return;
    setState(() => sending = true);
    try {
      await RedFlagGameApiService.sendMessage(widget.roomId, text);
      messageController.clear();
      await _loadMessages();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _finalChoice(bool match) async {
    setState(() => loading = true);
    try {
      final data = await RedFlagGameApiService.finalChoice(widget.roomId, match: match);
      if (!mounted) return;
      setState(() { state = data; loading = false; });
      final status = data['finalDecision'] is Map ? (data['finalDecision'] as Map)['status']?.toString() : '';
      if (!match || status == 'continue') _goHome();
      if (status == 'matched') _openChat();
    } on ApiException catch (e) {
      if (mounted) setState(() { loading = false; error = e.message; });
    }
  }

  void _openChat() {
    final rec = recommendation;
    final matchId = decision['matchId']?.toString() ?? '';
    if (rec == null || matchId.isEmpty) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PrivateChatScreen(
      matchId: matchId,
      name: rec['partnerName']?.toString() ?? 'Meet6',
      userId: rec['partnerUserId']?.toString() ?? '',
      photoUrl: _photo(rec['partnerPhotoUrl']?.toString()),
      fromNewMatch: true,
    )));
  }

  String? _choiceForPlayer(Map<String, dynamic> player) {
    final direct = player['choice']?.toString();
    if (direct == 'red' || direct == 'green') return direct;
    if (phase != 'discussion') return null;
    final name = player['name']?.toString() ?? '';
    if (widget.profileName.isNotEmpty && name == widget.profileName) {
      final mine = state?['myChoice']?.toString();
      if (mine == 'red' || mine == 'green') return mine;
    }
    final id = int.tryParse(player['id']?.toString() ?? '');
    final qid = int.tryParse(question['id']?.toString() ?? '');
    if (id != null && qid != null) return (id + qid) % 3 == 0 ? 'red' : 'green';
    return null;
  }

  String? _choiceForSender(Map<String, dynamic> m) {
    final sender = m['sender_user_id']?.toString() ?? m['senderUserId']?.toString();
    for (final p in players) {
      if (p['id']?.toString() == sender) return _choiceForPlayer(p);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _goHome(),
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF071022) : const Color(0xFFF7F9FF),
        body: PhoneFrame(child: SafeArea(child: loading && state == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.navy))
            : phase == 'final' ? _final(dark) : Column(children: [
                _header(dark),
                _players(dark),
                Expanded(child: phase == 'discussion' ? _discussion(dark) : _choice(dark)),
              ]))),
      ),
    );
  }

  Widget _header(bool dark) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
    child: Row(children: [
      Material(color: dark ? Colors.white10 : const Color(0xFFF0F3FA), shape: const CircleBorder(), child: IconButton(onPressed: _goHome, icon: Icon(Icons.arrow_back_rounded, color: dark ? Colors.white : AppColors.navy, size: 28))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Red Flag / Green Flag', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
        Text('6 kişi mini oyun odası', style: TextStyle(color: dark ? Colors.white54 : const Color(0xFF747D97), fontSize: 12.5, fontWeight: FontWeight.w700)),
      ])),
      _chip(Icons.timer_outlined, _clock(remaining), AppColors.lime),
      const SizedBox(width: 6),
      _chip(null, '${questionIndex + 1}/6', dark ? Colors.white10 : const Color(0xFFF0F3FA)),
    ]),
  );

  Widget _chip(IconData? icon, String text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, color: AppColors.navy, size: 18), const SizedBox(width: 5)], Text(text, style: const TextStyle(color: AppColors.navy, fontSize: 14.5, fontWeight: FontWeight.w900))]),
  );

  Widget _players(bool dark) => SizedBox(
    height: 88,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14), scrollDirection: Axis.horizontal, itemCount: players.length,
      separatorBuilder: (_, __) => const SizedBox(width: 9),
      itemBuilder: (_, i) {
        final p = players[i];
        final name = p['name']?.toString() ?? 'Oyuncu';
        final photo = _photo(p['photoUrl']?.toString());
        final choice = _choiceForPlayer(p);
        final color = choice == 'red' ? const Color(0xFFFF5A60) : const Color(0xFF72DD35);
        return SizedBox(width: 58, child: Column(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(width: 52, height: 52, padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: choice == null ? const Color(0xFFE3E8F2) : color, width: choice == null ? 2 : 3)), child: CircleAvatar(backgroundColor: const Color(0xFFE9EDF6), backgroundImage: photo.isEmpty ? null : NetworkImage(photo), child: photo.isEmpty ? Text(name.isEmpty ? '?' : name[0].toUpperCase()) : null)),
            Positioned(right: -1, bottom: -1, child: Container(width: choice == null ? 15 : 21, height: choice == null ? 15 : 21, decoration: BoxDecoration(color: choice == null ? const Color(0xFF55E321) : color, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF7F9FF), width: 2.5)), child: choice == null ? null : const Icon(Icons.flag_rounded, size: 12, color: Colors.white))),
          ]),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white70 : AppColors.navy, fontSize: 9.8, fontWeight: FontWeight.w800)),
        ]));
      },
    ),
  );

  Widget _choice(bool dark) {
    final mine = state?['myChoice']?.toString();
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 5, 16, 22), child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(20, 20, 20, 22), decoration: BoxDecoration(color: dark ? const Color(0xFF111A2D) : Colors.white, borderRadius: BorderRadius.circular(28)), child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFF1F3F8), borderRadius: BorderRadius.circular(99)), child: const Text('💬  Davranış', style: TextStyle(color: Color(0xFF68738E), fontSize: 14, fontWeight: FontWeight.w800))),
        const SizedBox(height: 20),
        Text(question['prompt']?.toString() ?? '', textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 24, height: 1.08, fontWeight: FontWeight.w900)),
      ])),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: _flagButton('Red Flag', true, mine == 'red', () => _choose('red'))), const SizedBox(width: 10), Expanded(child: _flagButton('Green Flag', false, mine == 'green', () => _choose('green')))]),
      const SizedBox(height: 12),
      const Text('ⓘ  Sonuçlar herkes oy verdikten sonra açılır.', style: TextStyle(color: Color(0xFF7A839C), fontSize: 11.5, fontWeight: FontWeight.w600)),
    ]));
  }

  Widget _flagButton(String label, bool red, bool selected, VoidCallback tap) {
    final bg = red ? const Color(0xFFFF5A60) : AppColors.lime;
    final fg = red ? Colors.white : AppColors.navy;
    return InkWell(onTap: loading ? null : tap, borderRadius: BorderRadius.circular(24), child: Container(height: 82, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24), border: selected ? Border.all(color: AppColors.navy, width: 3) : null), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.flag_rounded, color: fg, size: 27), const SizedBox(width: 8), Text(label, style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w900))])));
  }

  Widget _discussion(bool dark) {
    final result = state?['result'] is Map ? Map<String, dynamic>.from(state!['result'] as Map) : <String, dynamic>{};
    final red = (result['red'] as num?)?.toInt() ?? 0;
    final green = (result['green'] as num?)?.toInt() ?? 0;
    final redPct = ((red / 6) * 100).round();
    return Column(children: [
      Expanded(child: ListView(controller: scrollController, padding: const EdgeInsets.fromLTRB(16, 5, 16, 12), children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: dark ? const Color(0xFF111A2D) : Colors.white, borderRadius: BorderRadius.circular(24)), child: Column(children: [
          Text(question['prompt']?.toString() ?? '', textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 18.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          RichText(text: TextSpan(style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900), children: [TextSpan(text: '$red Red Flag', style: const TextStyle(color: Color(0xFFFF4F64))), const TextSpan(text: '  •  ', style: TextStyle(color: Color(0xFF727B94))), TextSpan(text: '$green Green Flag', style: const TextStyle(color: Color(0xFF43C66A)))])),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(99), child: SizedBox(height: 26, child: Row(children: [if (red > 0) Expanded(flex: red, child: Container(color: const Color(0xFFFF5A60), alignment: Alignment.center, child: Text('$redPct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))), if (green > 0) Expanded(flex: green, child: Container(color: const Color(0xFF63D73D), alignment: Alignment.center, child: Text('${100-redPct}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))))]))),
        ])),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(color: const Color(0xFFEFFBE8), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.chat_bubble_rounded, color: Color(0xFF45C85F)), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tartışma başladı', style: TextStyle(color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w900)), Text('Neden Red veya Green seçtiğini konuş.', style: TextStyle(color: Color(0xFF75809A), fontSize: 11.5))])), Text(_clock(remaining), style: const TextStyle(color: Color(0xFF2A8B37), fontWeight: FontWeight.w900))])),
        const SizedBox(height: 10),
        for (final m in messages) if (m['sender_user_id'] != null || m['senderUserId'] != null) _message(m, dark),
        if (messages.every((m) => m['sender_user_id'] == null && m['senderUserId'] == null)) const Padding(padding: EdgeInsets.symmetric(vertical: 26), child: Center(child: Text('İlk yorumu sen yaz.', style: TextStyle(color: Color(0xFF8A91A7), fontWeight: FontWeight.w700)))),
      ])),
      _composer(dark),
    ]);
  }

  Widget _message(Map<String, dynamic> m, bool dark) {
    final sender = m['sender_user_id']?.toString() ?? m['senderUserId']?.toString() ?? '';
    final player = players.cast<Map<String, dynamic>?>().firstWhere((p) => p?['id']?.toString() == sender, orElse: () => null);
    final name = m['display_name']?.toString().trim().isNotEmpty == true ? m['display_name'].toString() : player?['name']?.toString() ?? 'Oyuncu';
    final photo = _photo(player?['photoUrl']?.toString());
    final red = _choiceForSender(m) == 'red';
    final accent = red ? const Color(0xFFFF5260) : const Color(0xFF44C96B);
    final bg = red ? const Color(0xFFFFE8EB) : const Color(0xFFE8F8E9);
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 19, backgroundColor: const Color(0xFFE9EDF6), backgroundImage: photo.isEmpty ? null : NetworkImage(photo), child: photo.isEmpty ? Text(name.isEmpty ? '?' : name[0].toUpperCase()) : null),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Flexible(child: Text(name, style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 11.5, fontWeight: FontWeight.w900))), const SizedBox(width: 5), Icon(Icons.flag_rounded, size: 14, color: accent)]),
        const SizedBox(height: 3),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: dark ? accent.withOpacity(.18) : bg, borderRadius: BorderRadius.circular(15)), child: Text(m['body']?.toString() ?? '', style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 13.5, fontWeight: FontWeight.w600))),
      ])),
    ]));
  }

  Widget _composer(bool dark) => Container(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), decoration: BoxDecoration(color: dark ? const Color(0xFF071022) : const Color(0xFFF7F9FF), border: const Border(top: BorderSide(color: Color(0xFFE7EAF2)))), child: Row(children: [
    Expanded(child: TextField(controller: messageController, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendMessage(), decoration: InputDecoration(hintText: 'Düşünceni yaz...', filled: true, fillColor: dark ? Colors.white10 : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)))),
    const SizedBox(width: 8),
    SizedBox(width: 50, height: 50, child: IconButton.filled(onPressed: sending ? null : _sendMessage, style: IconButton.styleFrom(backgroundColor: AppColors.navy), icon: const Icon(Icons.send_rounded, color: AppColors.lime))),
  ]));

  Widget _final(bool dark) {
    final rec = recommendation;
    if (rec == null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Oyun tamamlandı', style: TextStyle(color: AppColors.navy, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 18), FilledButton(onPressed: _goHome, child: const Text('Ana sayfaya dön'))]));
    final name = rec['partnerName']?.toString() ?? 'Oyuncu';
    final photo = _photo(rec['partnerPhotoUrl']?.toString());
    final compatibility = (rec['compatibility'] as num?)?.toInt() ?? 0;
    final status = decision['status']?.toString() ?? 'pending';
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(children: [IconButton(onPressed: _goHome, icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy)), const Spacer(), const Text('Meet6', style: TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 20),
      const Align(alignment: Alignment.centerLeft, child: Text('Oyun sonucu', style: TextStyle(color: AppColors.navy, fontSize: 40, fontWeight: FontWeight.w900))),
      const SizedBox(height: 22),
      Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)), child: Column(children: [
        CircleAvatar(radius: 48, backgroundColor: const Color(0xFFE9EDF6), backgroundImage: photo.isEmpty ? null : NetworkImage(photo), child: photo.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 30)) : null),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('%$compatibility uyum', style: const TextStyle(color: Color(0xFF2454FF), fontSize: 34, fontWeight: FontWeight.w900)),
        Text('${rec['sameAnswers'] ?? 0} aynı seçim · ${rec['differentAnswers'] ?? 0} farklı seçim', style: const TextStyle(color: Color(0xFF7C839D), fontWeight: FontWeight.w700)),
      ])),
      const SizedBox(height: 18),
      if (status == 'pending') ...[
        SizedBox(width: double.infinity, height: 56, child: FilledButton(onPressed: loading ? null : () => _finalChoice(true), style: FilledButton.styleFrom(backgroundColor: AppColors.lime, foregroundColor: AppColors.navy), child: Text('$name ile eşleş →', style: const TextStyle(fontWeight: FontWeight.w900)))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 56, child: OutlinedButton(onPressed: loading ? null : () => _finalChoice(false), child: const Text('Odaya devam et', style: TextStyle(fontWeight: FontWeight.w900)))),
      ] else if (status == 'waiting') ...[
        const Text('Seçimin gizli olarak kaydedildi.', style: TextStyle(color: Color(0xFF747C96), fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _goHome, child: const Text('Ana sayfaya dön')),
      ] else if (status == 'matched')
        SizedBox(width: double.infinity, height: 56, child: FilledButton(onPressed: _openChat, style: FilledButton.styleFrom(backgroundColor: AppColors.navy), child: const Text('Eşleştiniz 💚  Özel mesaja geç'))),
      const SizedBox(height: 14),
      const Text('🔒 Seçimin gizlidir. Karşılıklı olursa eşleşme gerçekleşir.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8A91A7), fontSize: 12)),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
    ]));
  }
}
