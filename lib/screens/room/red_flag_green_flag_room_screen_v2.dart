import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/red_flag_game_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import 'red_flag_green_flag_room_screen.dart' as legacy;

class RedFlagGreenFlagRoomScreenV2 extends StatefulWidget {
  const RedFlagGreenFlagRoomScreenV2({
    super.key,
    required this.roomId,
    this.profileName = '',
  });

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

  Map<String, dynamic> get question {
    final raw = state?['question'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> get players {
    final raw = state?['players'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Duration get remaining {
    final end = DateTime.tryParse(state?['phaseEndsAt']?.toString() ?? '');
    if (end == null) return Duration.zero;
    final diff = end.toLocal().difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String _clock(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

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
      setState(() {
        loading = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        loading = false;
        error = 'Red Flag / Green Flag yüklenemedi.';
      });
    }
  }

  Future<void> _choose(String choice) async {
    if (loading || state?['myChoice'] != null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await RedFlagGameApiService.choose(widget.roomId, choice);
      if (!mounted) return;
      setState(() {
        state = data;
        loading = false;
      });
      if (data['phase']?.toString() == 'discussion') await _loadMessages();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final incoming = await RedFlagGameApiService.messages(widget.roomId, after: lastMessageId);
      if (!mounted || incoming.isEmpty) return;
      setState(() {
        for (final message in incoming) {
          final id = int.tryParse(message['id']?.toString() ?? '') ?? 0;
          if (id > lastMessageId) lastMessageId = id;
          if (!messages.any((m) => m['id']?.toString() == '$id')) messages.add(message);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
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

  void _goHome() {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
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

  String? _choiceForSender(Map<String, dynamic> message) {
    final sender = message['sender_user_id']?.toString() ?? message['senderUserId']?.toString();
    if (sender == null || sender.isEmpty) return null;
    for (final p in players) {
      if (p['id']?.toString() == sender) return _choiceForPlayer(p);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (phase == 'final') {
      return legacy.RedFlagGreenFlagRoomScreen(roomId: widget.roomId, profileName: widget.profileName);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _goHome(),
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF071022) : const Color(0xFFF7F9FF),
        body: PhoneFrame(
          child: SafeArea(
            child: loading && state == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.navy))
                : Column(
                    children: [
                      _header(dark),
                      _playersStrip(dark),
                      Expanded(child: phase == 'discussion' ? _discussion(dark) : _choice(dark)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _header(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Material(
            color: dark ? Colors.white10 : const Color(0xFFF0F3FA),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: _goHome,
              icon: Icon(Icons.arrow_back_rounded, color: dark ? Colors.white : AppColors.navy, size: 28),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Red Flag / Green Flag',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(
                  '6 kişi mini oyun odası',
                  style: TextStyle(color: dark ? Colors.white54 : const Color(0xFF747D97), fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          _counterChip(Icons.timer_outlined, _clock(remaining), AppColors.lime, AppColors.navy),
          const SizedBox(width: 6),
          _counterChip(null, '${questionIndex + 1}/6', dark ? Colors.white10 : const Color(0xFFF0F3FA), dark ? Colors.white : AppColors.navy),
        ],
      ),
    );
  }

  Widget _counterChip(IconData? icon, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, color: fg, size: 18), const SizedBox(width: 5)],
        Text(text, style: TextStyle(color: fg, fontSize: 14.5, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _playersStrip(bool dark) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, index) {
          final p = players[index];
          final name = p['name']?.toString() ?? 'Oyuncu';
          final photo = p['photoUrl']?.toString() ?? '';
          final choice = _choiceForPlayer(p);
          final choiceColor = choice == 'red' ? const Color(0xFFFF5A60) : const Color(0xFF72DD35);
          return SizedBox(
            width: 58,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: choice == null ? const Color(0xFFE3E8F2) : choiceColor, width: choice == null ? 2 : 3),
                      ),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFFE9EDF6),
                        backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                        child: photo.isEmpty ? Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)) : null,
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: choice == null ? 15 : 21,
                        height: choice == null ? 15 : 21,
                        decoration: BoxDecoration(
                          color: choice == null ? const Color(0xFF55E321) : choiceColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: dark ? const Color(0xFF071022) : const Color(0xFFF7F9FF), width: 2.5),
                        ),
                        child: choice == null ? null : const Icon(Icons.flag_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white70 : AppColors.navy, fontSize: 9.8, fontWeight: FontWeight.w800)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _choice(bool dark) {
    final myChoice = state?['myChoice']?.toString();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 22),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF111A2D) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Color(0x0E000000), blurRadius: 22, offset: Offset(0, 8))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(color: dark ? Colors.white10 : const Color(0xFFF1F3F8), borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF68738E), size: 17),
                    const SizedBox(width: 6),
                    Text('Davranış', style: TextStyle(color: dark ? Colors.white70 : const Color(0xFF68738E), fontSize: 14, fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(height: 20),
                Text(
                  question['prompt']?.toString() ?? 'Davranışı değerlendir',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 24, height: 1.08, fontWeight: FontWeight.w900, letterSpacing: -.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _flagButton('Red Flag', true, myChoice == 'red', () => _choose('red'))),
            const SizedBox(width: 10),
            Expanded(child: _flagButton('Green Flag', false, myChoice == 'green', () => _choose('green'))),
          ]),
          const SizedBox(height: 12),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF7A839C), size: 18),
            SizedBox(width: 6),
            Flexible(child: Text('Sonuçlar herkes oy verdikten sonra açılır.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7A839C), fontSize: 11.5, fontWeight: FontWeight.w600))),
          ]),
          if (myChoice != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: dark ? Colors.white10 : Colors.white, borderRadius: BorderRadius.circular(18)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF72DD35), size: 19),
                SizedBox(width: 7),
                Text('Seçimin kaydedildi', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)),
              ]),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }

  Widget _flagButton(String label, bool red, bool selected, VoidCallback onTap) {
    final bg = red ? const Color(0xFFFF5A60) : AppColors.lime;
    final fg = red ? Colors.white : AppColors.navy;
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 82,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: selected ? Border.all(color: AppColors.navy, width: 3) : null,
          boxShadow: [BoxShadow(color: bg.withOpacity(.18), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.flag_rounded, color: fg, size: 27),
          const SizedBox(width: 8),
          Flexible(child: Text(label, maxLines: 1, style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w900))),
        ]),
      ),
    );
  }

  Widget _discussion(bool dark) {
    final result = state?['result'] is Map ? Map<String, dynamic>.from(state!['result'] as Map) : <String, dynamic>{};
    final red = (result['red'] as num?)?.toInt() ?? 0;
    final green = (result['green'] as num?)?.toInt() ?? 0;
    final redPercent = ((red / 6) * 100).round();
    final greenPercent = 100 - redPercent;
    final majority = red == green ? 'Eşit görüş' : red > green ? 'Red Flag' : 'Green Flag';

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 5, 16, 12),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                decoration: BoxDecoration(color: dark ? const Color(0xFF111A2D) : Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(children: [
                  Text(question['prompt']?.toString() ?? '', textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 18.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900), children: [
                      TextSpan(text: '$red Red Flag', style: const TextStyle(color: Color(0xFFFF4F64))),
                      const TextSpan(text: '  •  ', style: TextStyle(color: Color(0xFF727B94))),
                      TextSpan(text: '$green Green Flag', style: const TextStyle(color: Color(0xFF43C66A))),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  Text('Çoğunluk görüşü: $majority', style: TextStyle(color: dark ? Colors.white60 : const Color(0xFF6E7891), fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 28,
                      child: Row(children: [
                        if (red > 0) Expanded(flex: red, child: Container(color: const Color(0xFFFF5A60), alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 12), child: Text('$redPercent%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
                        if (green > 0) Expanded(flex: green, child: Container(color: const Color(0xFF63D73D), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 12), child: Text('$greenPercent%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(color: const Color(0xFFEFFBE8), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0xFFDDF8D5), shape: BoxShape.circle), child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF45C85F), size: 21)),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tartışma başladı', style: TextStyle(color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('Neden Red veya Green seçtiğini konuş.', style: TextStyle(color: Color(0xFF75809A), fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text(_clock(remaining), style: const TextStyle(color: Color(0xFF2A8B37), fontSize: 16, fontWeight: FontWeight.w900))),
                ]),
              ),
              const SizedBox(height: 10),
              for (final message in messages)
                if (message['sender_user_id'] != null || message['senderUserId'] != null) _messageBubble(message, dark),
              if (messages.every((m) => m['sender_user_id'] == null && m['senderUserId'] == null))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Center(child: Text('İlk yorumu sen yaz.', style: TextStyle(color: Color(0xFF8A91A7), fontWeight: FontWeight.w700))),
                ),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800))),
            ],
          ),
        ),
        _messageComposer(dark),
      ],
    );
  }

  Widget _messageBubble(Map<String, dynamic> message, bool dark) {
    final sender = message['sender_user_id']?.toString() ?? message['senderUserId']?.toString() ?? '';
    final body = message['body']?.toString() ?? '';
    final displayName = message['display_name']?.toString() ?? message['displayName']?.toString();
    final player = players.cast<Map<String, dynamic>?>().firstWhere((p) => p?['id']?.toString() == sender, orElse: () => null);
    final name = displayName?.trim().isNotEmpty == true ? displayName! : player?['name']?.toString() ?? 'Oyuncu';
    final photo = player?['photoUrl']?.toString() ?? '';
    final choice = _choiceForSender(message);
    final red = choice == 'red';
    final bubbleColor = red ? const Color(0xFFFFE8EB) : const Color(0xFFE8F8E9);
    final accent = red ? const Color(0xFFFF5260) : const Color(0xFF44C96B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFFE9EDF6),
            backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
            child: photo.isEmpty ? Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)) : null,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 11.5, fontWeight: FontWeight.w900))),
                  if (choice != null) ...[
                    const SizedBox(width: 5),
                    Icon(Icons.flag_rounded, size: 14, color: accent),
                  ],
                ]),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: dark ? accent.withOpacity(.18) : bubbleColor, borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
                  child: Text(body, style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 13.5, height: 1.25, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageComposer(bool dark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(color: dark ? const Color(0xFF071022) : const Color(0xFFF7F9FF), border: Border(top: BorderSide(color: dark ? Colors.white10 : const Color(0xFFE7EAF2)))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: messageController,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage(),
            decoration: InputDecoration(
              hintText: 'Düşünceni yaz...',
              filled: true,
              fillColor: dark ? Colors.white10 : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: dark ? Colors.white10 : const Color(0xFFDDE2EC))),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          height: 50,
          child: IconButton.filled(
            onPressed: sending ? null : _sendMessage,
            style: IconButton.styleFrom(backgroundColor: AppColors.navy),
            icon: const Icon(Icons.send_rounded, color: AppColors.lime, size: 25),
          ),
        ),
      ]),
    );
  }
}
