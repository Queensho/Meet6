import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/red_flag_game_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../../widgets/phone_frame.dart';
import '../chat/room_chat_screen.dart';
import '../messages/private_chat_screen.dart';

class RedFlagGreenFlagRoomScreen extends StatefulWidget {
  const RedFlagGreenFlagRoomScreen({
    super.key,
    required this.roomId,
    this.profileName = '',
  });

  final String roomId;
  final String profileName;

  @override
  State<RedFlagGreenFlagRoomScreen> createState() =>
      _RedFlagGreenFlagRoomScreenState();
}

class _RedFlagGreenFlagRoomScreenState
    extends State<RedFlagGreenFlagRoomScreen> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  Map<String, dynamic>? state;
  final messages = <Map<String, dynamic>>[];
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
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic>? get recommendation {
    final raw = state?['recommendation'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Map<String, dynamic> get decision {
    final raw = state?['finalDecision'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Duration get remaining {
    final end = DateTime.tryParse(state?['phaseEndsAt']?.toString() ?? '');
    if (end == null) return Duration.zero;
    final diff = end.toLocal().difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
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
      if (data['phase']?.toString() == 'discussion') {
        await _loadMessages();
      }
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
    } on ApiException catch (e) {
      if (mounted) setState(() {
        loading = false;
        error = e.message;
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final incoming = await RedFlagGameApiService.messages(
        widget.roomId,
        after: lastMessageId,
      );
      if (!mounted || incoming.isEmpty) return;
      setState(() {
        for (final message in incoming) {
          final id = int.tryParse(message['id']?.toString() ?? '') ?? 0;
          if (id > lastMessageId) lastMessageId = id;
          if (!messages.any((m) => m['id']?.toString() == '$id')) {
            messages.add(message);
          }
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

  Future<void> _finalChoice(bool match) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await RedFlagGameApiService.finalChoice(
        widget.roomId,
        match: match,
      );
      if (!mounted) return;
      setState(() {
        state = data;
        loading = false;
      });
      final status = data['finalDecision'] is Map
          ? (data['finalDecision'] as Map)['status']?.toString()
          : null;
      if (status == 'matched') _openChat();
      if (status == 'continue') _continueRoom();
    } on ApiException catch (e) {
      if (mounted) setState(() {
        loading = false;
        error = e.message;
      });
    }
  }

  void _continueRoom() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RoomChatScreen(
          roomId: widget.roomId,
          profileName: widget.profileName,
        ),
      ),
    );
  }

  void _openChat() {
    final rec = recommendation;
    final matchId = decision['matchId']?.toString() ?? '';
    if (rec == null || matchId.isEmpty) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          matchId: matchId,
          name: rec['partnerName']?.toString() ?? 'Meet6',
          userId: rec['partnerUserId']?.toString() ?? '',
          photoUrl: rec['partnerPhotoUrl']?.toString() ?? '',
          fromNewMatch: true,
        ),
      ),
    );
  }

  String _clock(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF071022) : const Color(0xFFF7F9FF),
      body: PhoneFrame(
        child: SafeArea(
          child: loading && state == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.navy),
                )
              : phase == 'final'
                  ? _finalScreen(dark)
                  : Column(
                      children: [
                        _header(dark),
                        _players(dark),
                        Expanded(
                          child: phase == 'discussion'
                              ? _discussion(dark)
                              : _choice(dark),
                        ),
                      ],
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
            color: dark ? Colors.white10 : Colors.white,
            shape: const CircleBorder(),
            elevation: dark ? 0 : 3,
            child: IconButton(
              onPressed: _continueRoom,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: dark ? Colors.white : AppColors.navy,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Red Flag / Green Flag',
                  style: TextStyle(
                    color: dark ? Colors.white : AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${questionIndex + 1}/6 soru',
                  style: TextStyle(
                    color: dark ? Colors.white60 : const Color(0xFF717A95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              _clock(remaining),
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _players(bool dark) {
    return SizedBox(
      height: 82,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final p = players[index];
          final name = p['name']?.toString() ?? 'Oyuncu';
          final photo = p['photoUrl']?.toString() ?? '';
          return SizedBox(
            width: 56,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE9EDF6),
                  backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                  child: photo.isEmpty
                      ? Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? Colors.white70 : AppColors.navy,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF111A2D) : Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: AppColors.lime,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  question['prompt']?.toString() ?? 'Davranışı değerlendir',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark ? Colors.white : AppColors.navy,
                    fontSize: 28,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '15 saniye içinde seçimini yap.',
                  style: TextStyle(
                    color: dark ? Colors.white60 : const Color(0xFF7A839C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _flagButton(
                  label: 'RED FLAG',
                  icon: Icons.flag_rounded,
                  selected: myChoice == 'red',
                  red: true,
                  onTap: () => _choose('red'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _flagButton(
                  label: 'GREEN FLAG',
                  icon: Icons.flag_rounded,
                  selected: myChoice == 'green',
                  red: false,
                  onTap: () => _choose('green'),
                ),
              ),
            ],
          ),
          if (myChoice != null) ...[
            const SizedBox(height: 14),
            const Text(
              'Seçimin kaydedildi. Diğer oyuncular bekleniyor…',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6F7893),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _flagButton({
    required String label,
    required IconData icon,
    required bool selected,
    required bool red,
    required VoidCallback onTap,
  }) {
    final color = red ? const Color(0xFFFF4F64) : const Color(0xFF50D890);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 116,
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color, width: selected ? 3 : 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : color, size: 34),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _discussion(bool dark) {
    final result = state?['result'] is Map
        ? Map<String, dynamic>.from(state!['result'] as Map)
        : <String, dynamic>{};
    final red = (result['red'] as num?)?.toInt() ?? 0;
    final green = (result['green'] as num?)?.toInt() ?? 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF111A2D) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  question['prompt']?.toString() ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark ? Colors.white : AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _resultPill('$red RED', const Color(0xFFFF4F64))),
                    const SizedBox(width: 10),
                    Expanded(child: _resultPill('$green GREEN', const Color(0xFF50D890))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${_clock(remaining)} tartışma süresi',
                  style: const TextStyle(
                    color: Color(0xFF717A95),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: messages.length,
            itemBuilder: (_, index) {
              final m = messages[index];
              final name = m['display_name']?.toString();
              final body = m['body']?.toString() ?? '';
              final system = m['sender_user_id'] == null;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: system
                      ? AppColors.lime.withOpacity(.18)
                      : (dark ? Colors.white10 : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  system ? body : '${name ?? 'Oyuncu'}: $body',
                  style: TextStyle(
                    color: dark ? Colors.white : AppColors.navy,
                    fontWeight: system ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Nedenini yaz…',
                    filled: true,
                    fillColor: dark ? Colors.white10 : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: sending ? null : _sendMessage,
                style: IconButton.styleFrom(backgroundColor: AppColors.navy),
                icon: const Icon(Icons.send_rounded, color: AppColors.lime),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.55)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _finalScreen(bool dark) {
    final rec = recommendation;
    if (rec == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border_rounded, size: 62, color: AppColors.navy),
              const SizedBox(height: 16),
              const Text(
                'Bu turda uygun bir oyun eşleşmesi bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _continueRoom, child: const Text('Odaya devam et')),
            ],
          ),
        ),
      );
    }
    final partnerName = rec['partnerName']?.toString() ?? 'Oyuncu';
    final partnerPhoto = rec['partnerPhotoUrl']?.toString() ?? '';
    final compatibility = (rec['compatibility'] as num?)?.toInt() ?? 0;
    final same = (rec['sameAnswers'] as num?)?.toInt() ?? 0;
    final different = (rec['differentAnswers'] as num?)?.toInt() ?? 0;
    final me = players.firstWhere(
      (p) => p['name']?.toString() == widget.profileName,
      orElse: () => players.firstWhere(
        (p) => p['id']?.toString() != rec['partnerUserId']?.toString(),
        orElse: () => const <String, dynamic>{},
      ),
    );
    final status = decision['status']?.toString() ?? 'pending';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: _continueRoom,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navy),
                ),
              ),
              const Spacer(),
              const Meet6MiniBrand(height: 28, forceLogo2: true),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Oyun sonucu',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 42,
              height: .95,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '6 soru tamamlandı · En yakın görüş uyumun bulundu',
            style: TextStyle(
              color: Color(0xFF7C839D),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Color(0x11000000), blurRadius: 24, offset: Offset(0, 10)),
              ],
            ),
            child: Row(
              children: [
                Expanded(child: _finalPerson(me, widget.profileName.isEmpty ? 'Sen' : widget.profileName)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      const Icon(Icons.favorite_rounded, color: Color(0xFF99DD00), size: 42),
                      const SizedBox(height: 4),
                      const Text('Uyum', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
                      Text(
                        '%$compatibility',
                        style: const TextStyle(
                          color: Color(0xFF2454FF),
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _finalPerson(
                    {'name': partnerName, 'photoUrl': partnerPhoto},
                    partnerName,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _statBox('🟩', '$same aynı seçim', 'Aynı fikirdesiniz')),
              const SizedBox(width: 8),
              Expanded(child: _statBox('🟥', '$different farklı seçim', 'Farklı bakış')),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.lime.withOpacity(.2),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: partnerPhoto.isEmpty ? null : NetworkImage(partnerPhoto),
                  child: partnerPhoto.isEmpty ? Text(partnerName[0].toUpperCase()) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                      children: [
                        const TextSpan(text: 'Sistem sana\n'),
                        TextSpan(
                          text: '$partnerName’i öneriyor',
                          style: const TextStyle(color: Color(0xFF2454FF)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (status == 'pending') ...[
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: loading ? null : () => _finalChoice(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: AppColors.navy,
                ),
                child: Text('$partnerName ile eşleş →', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: OutlinedButton(
                onPressed: loading ? null : () => _finalChoice(false),
                child: const Text('Odaya devam et', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ] else if (status == 'waiting')
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Seçimin gizli olarak kaydedildi. Karşılıklı olursa eşleşme gerçekleşir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF747C96), fontWeight: FontWeight.w700),
                ),
              ),
            )
          else if (status == 'matched')
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: _openChat,
                style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
                child: const Text('Eşleştiniz 💚  Özel mesaja geç'),
              ),
            ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              '🔒 Seçimin gizlidir. Karşılıklı olursa eşleşme gerçekleşir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A91A7), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Center(child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
          ],
        ],
      ),
    );
  }

  Widget _finalPerson(Map<String, dynamic> p, String fallback) {
    final name = p['name']?.toString().isNotEmpty == true ? p['name'].toString() : fallback;
    final photo = p['photoUrl']?.toString() ?? '';
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 112,
            width: 112,
            child: photo.isEmpty
                ? Container(
                    color: const Color(0xFFEAF0FF),
                    alignment: Alignment.center,
                    child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                  )
                : Image.network(photo, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _statBox(String emoji, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text('$emoji  $title', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 3),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8A91A7), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
