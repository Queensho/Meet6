import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/mini_game_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../../widgets/phone_frame.dart';
import '../chat/room_chat_screen.dart';
import '../messages/private_chat_screen.dart';

class MiniGameRoomScreen extends StatefulWidget {
  const MiniGameRoomScreen({
    super.key,
    required this.roomId,
    this.profileName = '',
  });

  final String roomId;
  final String profileName;

  @override
  State<MiniGameRoomScreen> createState() => _MiniGameRoomScreenState();
}

class _MiniGameRoomScreenState extends State<MiniGameRoomScreen> {
  final controllers = List.generate(3, (_) => TextEditingController());
  Map<String, dynamic>? state;
  String? error;
  bool loading = true;
  int lieIndex = 2;
  int? selectedVote;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !loading) _load(silent: true);
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    for (final c in controllers) c.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final data = await MiniGameApiService.state(widget.roomId);
      if (!mounted) return;
      setState(() {
        state = data;
        if (!silent) error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || silent) return;
      setState(() => error = e.message);
    } catch (_) {
      if (!mounted || silent) return;
      setState(() => error = 'Mini oyun yüklenemedi.');
    } finally {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  Future<void> _act(Future<Map<String, dynamic>> Function() fn) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await fn();
      if (!mounted) return;
      setState(() => state = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'İşlem tamamlanamadı.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submitStatements() async {
    final values = controllers.map((c) => c.text.trim()).toList();
    if (values.any((v) => v.length < 2)) {
      setState(() => error = 'Üç ifadeyi de doldur.');
      return;
    }
    await _act(() => MiniGameApiService.submitStatements(
          widget.roomId,
          values,
          lieIndex,
        ));
  }

  Future<void> _submitVote() async {
    if (selectedVote == null) {
      setState(() => error = 'Yalan olduğunu düşündüğün ifadeyi seç.');
      return;
    }
    await _act(() => MiniGameApiService.vote(widget.roomId, selectedVote!));
  }

  Future<void> _next() async {
    for (final c in controllers) c.clear();
    setState(() {
      lieIndex = 2;
      selectedVote = null;
    });
    await _act(() => MiniGameApiService.next(widget.roomId));
  }

  Future<void> _finalChoice(bool match) async {
    await _act(() => MiniGameApiService.finalChoice(widget.roomId, match: match));
  }

  void _goHome() {
    refreshTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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

  void _openPrivateChat() {
    final rec = recommendation;
    final matchId = finalDecision['matchId']?.toString() ?? '';
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

  List<Map<String, dynamic>> get players {
    final raw = state?['players'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<String> get statements {
    final raw = state?['statements'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList();
  }

  Map<String, dynamic>? get recommendation {
    final raw = state?['recommendation'];
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  Map<String, dynamic> get finalDecision {
    final raw = state?['finalDecision'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  String get phase => state?['phase']?.toString() ?? 'write';
  String get ownerName => state?['ownerName']?.toString() ?? 'Oyuncu';
  String get ownerUserId => state?['ownerUserId']?.toString() ?? '';
  bool get isMyTurn => state?['isMyTurn'] == true;
  int get roundIndex => (state?['roundIndex'] as num?)?.toInt() ?? 0;

  Map<String, dynamic> get me {
    if (players.isEmpty) return const {};
    final byName = players.where((p) => p['name']?.toString() == widget.profileName);
    if (byName.isNotEmpty) return byName.first;
    final partnerId = recommendation?['partnerUserId']?.toString();
    final other = players.where((p) => p['id']?.toString() != partnerId);
    return other.isNotEmpty ? other.first : players.first;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF071022) : const Color(0xFFF7F9FF),
      body: PhoneFrame(
        child: SafeArea(
          child: loading && state == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.navy))
              : error != null && state == null
                  ? _errorCard()
                  : phase == 'final'
                      ? _finalScreen(dark)
                      : _gameScreen(dark),
        ),
      ),
    );
  }

  Widget _gameScreen(bool dark) {
    return Column(
      children: [
        _gameHeader(dark),
        _playersRow(dark),
        const SizedBox(height: 8),
        _turnChip(),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: _gameCard(dark),
          ),
        ),
      ],
    );
  }

  Widget _gameHeader(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 18, 8),
      child: Row(
        children: [
          _roundBack(dark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mini Oyun Odası',
                    style: TextStyle(
                        color: dark ? Colors.white : AppColors.navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                Text('İki Doğru Bir Yalan',
                    style: TextStyle(
                        color: dark ? Colors.white60 : const Color(0xFF727B97),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(24)),
            child: Text('${roundIndex + 1}/6 TUR',
                style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _roundBack(bool dark) {
    return Material(
      color: dark ? Colors.white10 : Colors.white,
      shape: const CircleBorder(),
      elevation: dark ? 0 : 4,
      shadowColor: Colors.black12,
      child: IconButton(
        onPressed: _goHome,
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: dark ? Colors.white : AppColors.navy),
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> player, {double radius = 25, bool rounded = false}) {
    final name = player['name']?.toString() ?? 'Oyuncu';
    final photo = player['photoUrl']?.toString() ?? '';
    final child = photo.isEmpty
        ? Container(
            color: const Color(0xFFF0F2F8),
            alignment: Alignment.center,
            child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900)),
          )
        : Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
            return Container(
              color: const Color(0xFFF0F2F8),
              alignment: Alignment.center,
              child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900)),
            );
          });
    return ClipRRect(
      borderRadius: BorderRadius.circular(rounded ? 28 : radius * 2),
      child: SizedBox(width: radius * 2, height: radius * 2, child: child),
    );
  }

  Widget _playersRow(bool dark) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final p = players[index];
          final active = p['id']?.toString() == ownerUserId;
          return SizedBox(
            width: 60,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: active ? AppColors.lime : const Color(0xFFE0E5EF),
                        width: active ? 3 : 1),
                  ),
                  child: _avatar(p),
                ),
                const SizedBox(height: 4),
                Text(p['name']?.toString() ?? 'Oyuncu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: dark ? Colors.white70 : const Color(0xFF69738D),
                        fontSize: 10.5,
                        fontWeight: active ? FontWeight.w900 : FontWeight.w700)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _turnChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(22)),
      child: Text(isMyTurn ? 'Sıra Sende' : 'Sıra $ownerName’de',
          style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900, fontSize: 13)),
    );
  }

  Widget _gameCard(bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111A2D) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                child: const Icon(Icons.sports_esports_rounded, color: AppColors.lime, size: 33),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phase == 'write' && isMyTurn
                          ? '3 ifade yaz'
                          : phase == 'result'
                              ? 'Sonuç açıklandı'
                              : 'Yalanı tahmin et',
                      style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 23, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      phase == 'write' && isMyTurn
                          ? 'İki doğru ve bir yalan yaz.'
                          : '$ownerName 3 ifade yazdı. Sence hangisi yalan?',
                      style: TextStyle(color: dark ? Colors.white60 : const Color(0xFF7C859E), fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (phase == 'write') _writeArea(dark),
          if (phase == 'vote') _voteArea(dark),
          if (phase == 'result') _resultArea(dark),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }

  Widget _writeArea(bool dark) {
    if (!isMyTurn) return _waiting('$ownerName ifadelerini hazırlıyor…', dark);
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          TextField(
            controller: controllers[i],
            maxLength: 120,
            decoration: InputDecoration(
              counterText: '',
              hintText: '${i + 1}. ifade',
              filled: true,
              fillColor: dark ? Colors.white10 : const Color(0xFFF8FAFD),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
          RadioListTile<int>(
            value: i,
            groupValue: lieIndex,
            dense: true,
            activeColor: AppColors.lime,
            onChanged: loading ? null : (v) => setState(() => lieIndex = v ?? 2),
            title: Text('Bu ifade yalan',
                style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontWeight: FontWeight.w800)),
          ),
        ],
        _primaryButton('İfadeleri gönder', Icons.send_rounded, _submitStatements),
      ],
    );
  }

  Widget _voteArea(bool dark) {
    if (isMyTurn) return _waiting('Diğer 5 oyuncu oy kullanıyor…', dark);
    return Column(
      children: [
        for (var i = 0; i < statements.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: loading ? null : () => setState(() => selectedVote = i),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selectedVote == i ? AppColors.lime.withOpacity(.16) : (dark ? Colors.white10 : const Color(0xFFF8FAFD)),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: selectedVote == i ? AppColors.lime : const Color(0xFFE2E7F0), width: selectedVote == i ? 2 : 1),
                ),
                child: Text(statements[i],
                    style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        const SizedBox(height: 6),
        _primaryButton('Seçimini gönder', Icons.send_rounded, _submitVote),
      ],
    );
  }

  Widget _resultArea(bool dark) {
    final raw = state?['result'];
    final result = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final lie = (result['lieIndex'] as num?)?.toInt() ?? -1;
    final countsRaw = result['voteCounts'];
    final counts = countsRaw is List ? countsRaw.map((e) => (e as num?)?.toInt() ?? 0).toList() : <int>[];
    return Column(
      children: [
        for (var i = 0; i < statements.length; i++)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: i == lie ? AppColors.lime.withOpacity(.22) : (dark ? Colors.white10 : const Color(0xFFF8FAFD)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: i == lie ? AppColors.lime : const Color(0xFFE2E7F0), width: i == lie ? 2 : 1),
            ),
            child: Row(children: [
              Expanded(child: Text(statements[i], style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontWeight: FontWeight.w800))),
              Text('${i < counts.length ? counts[i] : 0} oy', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
            ]),
          ),
        Text(lie >= 0 ? 'Yalan ${lie + 1}. ifadeydi' : 'Tur tamamlandı',
            style: TextStyle(color: dark ? Colors.white : AppColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        _primaryButton(roundIndex >= 5 ? 'Oyun sonucunu gör' : 'Sonraki oyuncu', Icons.arrow_forward_rounded, _next),
      ],
    );
  }

  Widget _finalScreen(bool dark) {
    final rec = recommendation;
    final partnerName = rec?['partnerName']?.toString() ?? 'Oyuncu';
    final compatibility = (rec?['compatibility'] as num?)?.toInt() ?? 0;
    final same = (compatibility * 6 / 100).round().clamp(0, 6);
    final different = 6 - same;
    final status = finalDecision['status']?.toString() ?? 'pending';

    if (status == 'matched') {
      return _matchedFinal(partnerName, compatibility);
    }

    return Stack(
      children: [
        Positioned(
          right: -34,
          top: -42,
          child: Transform.rotate(
            angle: .32,
            child: Container(
              width: 240,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(36),
              ),
            ),
          ),
        ),
        Positioned(
          right: -90,
          top: 112,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF2FF),
              borderRadius: BorderRadius.circular(110),
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _roundBack(dark),
                  const Spacer(),
                  const Meet6MiniBrand(height: 34, forceLogo2: true),
                ],
              ),
              const SizedBox(height: 30),
              const Text('Oyun sonucu',
                  style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 52,
                      height: .95,
                      letterSpacing: -2.5,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Text('6 soru tamamlandı · En yakın görüş\nuyumun bulundu',
                  style: TextStyle(
                      color: dark ? Colors.white70 : const Color(0xFF7B83A4),
                      fontSize: 20,
                      height: 1.25,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              _compatibilityHero(dark, partnerName, compatibility),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _statTile(Icons.flag_rounded, const Color(0xFF83D90B), '$same aynı seçim', 'Aynı fikirdesiniz')),
                  const SizedBox(width: 10),
                  Expanded(child: _statTile(Icons.flag_rounded, const Color(0xFFFF3F55), '$different farklı seçim', 'Farklı bakış açıları')),
                  const SizedBox(width: 10),
                  Expanded(child: _statTile(Icons.schedule_rounded, const Color(0xFF2F60FF), '12 dk tartışma', 'Güzel sohbet!')),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF4FFE0), Color(0xFFEDFFD2)]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    _partnerAvatar(rec, size: 82),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sistem sana',
                              style: TextStyle(color: AppColors.navy, fontSize: 27, fontWeight: FontWeight.w900, height: 1)),
                          Text('$partnerName’yu öneriyor',
                              style: const TextStyle(color: Color(0xFF2A5BFF), fontSize: 27, fontWeight: FontWeight.w900, height: 1.05)),
                          const SizedBox(height: 8),
                          Text('$partnerName da seni seçerse özel sohbete geçersiniz.',
                              style: const TextStyle(color: Color(0xFF737A96), fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Icon(Icons.favorite_border_rounded, color: Color(0xFF9BE20C), size: 42),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (status == 'waiting')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5FF), borderRadius: BorderRadius.circular(22)),
                  child: const Text('Seçimin kaydedildi. Karşı tarafın seçimi gizli tutuluyor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton(
                    onPressed: loading ? null : () => _finalChoice(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.navy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('$partnerName ile eşleş', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 18),
                      const Icon(Icons.arrow_forward_rounded, size: 30),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 62,
                  child: OutlinedButton(
                    onPressed: loading ? null : () async {
                      await _finalChoice(false);
                      if (mounted) _continueRoom();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: Color(0xFFAFB7D0), width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: const Text('Odaya devam et', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, color: Color(0xFF2A5BFF), size: 22),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text('Seçimin gizlidir. Karşılıklı olursa eşleşme gerçekleşir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF8A91AD), fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _compatibilityHero(bool dark, String partnerName, int compatibility) {
    final partner = recommendation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111A2D) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.07), blurRadius: 26, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _profileBlock(me, AppColors.blue)),
              SizedBox(
                width: 112,
                child: Column(
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF5FFE3),
                        border: Border.all(color: const Color(0xFFD9FF8A), width: 2),
                      ),
                      child: const Icon(Icons.favorite_rounded, color: Color(0xFF8AD510), size: 34),
                    ),
                    const SizedBox(height: 6),
                    const Text('Uyum', style: TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
                    Text('%$compatibility',
                        style: const TextStyle(color: Color(0xFF2A5BFF), fontSize: 44, height: 1, fontWeight: FontWeight.w900, letterSpacing: -2)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFF1FFD9), borderRadius: BorderRadius.circular(18)),
                      child: const Text('Harika bir uyum!', style: TextStyle(color: Color(0xFF46670A), fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _profileBlock({
                  'name': partnerName,
                  'photoUrl': partner?['partnerPhotoUrl']?.toString() ?? '',
                }, AppColors.lime),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileBlock(Map<String, dynamic> data, Color accent) {
    final name = data['name']?.toString() ?? 'Oyuncu';
    return Column(
      children: [
        Container(
          width: 122,
          height: 122,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: _avatar(data, radius: 56, rounded: true),
        ),
        const SizedBox(height: 10),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _partnerAvatar(Map<String, dynamic>? rec, {double size = 72}) {
    return _avatar({
      'name': rec?['partnerName']?.toString() ?? 'Oyuncu',
      'photoUrl': rec?['partnerPhotoUrl']?.toString() ?? '',
    }, radius: size / 2);
  }

  Widget _statTile(IconData icon, Color color, String title, String subtitle) {
    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.9), borderRadius: BorderRadius.circular(22)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Flexible(child: Text(title, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.navy, fontSize: 13, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 5),
          Text(subtitle, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8B92AA), fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _matchedFinal(String partnerName, int compatibility) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_rounded, color: AppColors.lime, size: 86),
            const SizedBox(height: 18),
            const Text('Eşleştiniz 💚',
                style: TextStyle(color: AppColors.navy, fontSize: 36, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('$partnerName ile oyun uyumunuz %$compatibility.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF737A96), fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 28),
            _primaryButton('Özel mesaja geç', Icons.chat_bubble_rounded, _openPrivateChat),
            const SizedBox(height: 12),
            TextButton(onPressed: _continueRoom, child: const Text('Odaya dön')),
          ],
        ),
      ),
    );
  }

  Widget _waiting(String text, bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? Colors.white10 : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        const CircularProgressIndicator(color: AppColors.lime),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center,
            style: TextStyle(color: dark ? Colors.white70 : AppColors.navy, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback action) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: loading ? null : action,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _errorCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 10),
            Text(error ?? 'Mini oyun yüklenemedi.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
