import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/mini_game_api_service.dart';
import '../../theme/app_colors.dart';
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
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
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

  Future<void> _act(Future<Map<String, dynamic>> Function() action) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await action();
      if (!mounted) return;
      setState(() => state = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'İşlem tamamlanamadı.');
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
    for (final controller in controllers) controller.clear();
    setState(() {
      lieIndex = 2;
      selectedVote = null;
    });
    await _act(() => MiniGameApiService.next(widget.roomId));
  }

  Future<void> _finalChoice(bool match) async {
    await _act(() => MiniGameApiService.finalChoice(widget.roomId, match: match));
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
    final decision = finalDecision;
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

  List<Map<String, dynamic>> get players {
    final raw = state?['players'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> get leaderboard {
    final raw = state?['leaderboard'];
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF071022) : const Color(0xFFF8FAFF),
      body: PhoneFrame(
        child: SafeArea(
          child: Column(
            children: [
              _header(dark),
              if (phase != 'final') _playersRow(dark),
              if (phase != 'final') ...[
                const SizedBox(height: 8),
                _turnChip(),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  child: loading && state == null
                      ? const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: CircularProgressIndicator(color: AppColors.navy),
                        )
                      : error != null && state == null
                          ? _errorCard()
                          : phase == 'final'
                              ? _finalCard(dark)
                              : _gameCard(dark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 18, 8),
      child: Row(
        children: [
          Material(
            color: dark ? Colors.white10 : const Color(0xFFF1F4FA),
            shape: const CircleBorder(),
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
                  phase == 'final' ? 'Oyun Sonucu' : 'Mini Oyun Odası',
                  style: TextStyle(
                    color: dark ? Colors.white : AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  phase == 'final' ? 'Oyun Uyumu' : 'İki Doğru Bir Yalan',
                  style: TextStyle(
                    color: dark ? Colors.white60 : const Color(0xFF6F7893),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              phase == 'final' ? 'FİNAL' : '${roundIndex + 1}/6 TUR',
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

  Widget _avatar(Map<String, dynamic> player, {double radius = 25}) {
    final name = player['name']?.toString() ?? 'Oyuncu';
    final photo = player['photoUrl']?.toString() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFF0F2F8),
      backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
      child: photo.isEmpty
          ? Text(
              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
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
          final name = p['name']?.toString() ?? 'Oyuncu';
          final active = p['id']?.toString() == ownerUserId;
          return SizedBox(
            width: 60,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(active ? 3 : 1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active
                          ? AppColors.lime
                          : (dark ? Colors.white24 : const Color(0xFFE0E5EF)),
                      width: active ? 3 : 1,
                    ),
                  ),
                  child: _avatar(p),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? Colors.white70 : const Color(0xFF69738D),
                    fontSize: 10.5,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
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
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        isMyTurn ? 'Sıra Sende' : 'Sıra $ownerName’de',
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _cardShell(bool dark, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111A2D) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _gameCard(bool dark) {
    return _cardShell(
      dark,
      Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: AppColors.lime,
                  size: 33,
                ),
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
                      style: TextStyle(
                        color: dark ? Colors.white : AppColors.navy,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      phase == 'write' && isMyTurn
                          ? 'İki doğru ve bir yalan yaz.'
                          : '$ownerName 3 ifade yazdı. Sence hangisi yalan?',
                      style: TextStyle(
                        color: dark ? Colors.white60 : const Color(0xFF7C859E),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _writeArea(bool dark) {
    if (!isMyTurn) return _waitingPanel('$ownerName ifadelerini hazırlıyor…', dark);
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
            title: Text(
              'Bu ifade yalan',
              style: TextStyle(
                color: dark ? Colors.white : AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        _primaryButton('İfadeleri gönder', Icons.send_rounded, _submitStatements),
      ],
    );
  }

  Widget _voteArea(bool dark) {
    if (isMyTurn) return _waitingPanel('Diğer 5 oyuncu oy kullanıyor…', dark);
    return Column(
      children: [
        for (var i = 0; i < statements.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: loading ? null : () => setState(() => selectedVote = i),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selectedVote == i
                      ? AppColors.lime.withOpacity(.16)
                      : (dark ? Colors.white10 : const Color(0xFFF8FAFD)),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selectedVote == i ? AppColors.lime : const Color(0xFFE2E7F0),
                    width: selectedVote == i ? 2 : 1,
                  ),
                ),
                child: Text(
                  statements[i],
                  style: TextStyle(
                    color: dark ? Colors.white : AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.lime.withOpacity(.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Doğru tahmin +20 XP • XP seviye sistemine eklenir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _primaryButton('Seçimini gönder', Icons.send_rounded, _submitVote),
      ],
    );
  }

  Widget _resultArea(bool dark) {
    final raw = state?['result'];
    final result = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final lie = (result['lieIndex'] as num?)?.toInt() ?? -1;
    final countsRaw = result['voteCounts'];
    final counts = countsRaw is List
        ? countsRaw.map((e) => (e as num?)?.toInt() ?? 0).toList()
        : <int>[];
    return Column(
      children: [
        for (var i = 0; i < statements.length; i++)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: i == lie
                  ? AppColors.lime.withOpacity(.22)
                  : (dark ? Colors.white10 : const Color(0xFFF8FAFD)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: i == lie ? AppColors.lime : const Color(0xFFE2E7F0),
                width: i == lie ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    statements[i],
                    style: TextStyle(
                      color: dark ? Colors.white : AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${i < counts.length ? counts[i] : 0} oy',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        _primaryButton(
          roundIndex >= 5 ? 'Finale geç' : 'Sonraki oyuncu',
          Icons.arrow_forward_rounded,
          _next,
        ),
      ],
    );
  }

  Widget _finalCard(bool dark) {
    final rec = recommendation;
    final status = finalDecision['status']?.toString() ?? 'pending';
    return _cardShell(
      dark,
      Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.navy,
            ),
            child: const Icon(Icons.favorite_rounded, color: AppColors.lime, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            '6 tur tamamlandı',
            style: TextStyle(
              color: dark ? Colors.white : AppColors.navy,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'XP ve Oyun Uyumu birbirinden ayrı hesaplanır.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: dark ? Colors.white60 : const Color(0xFF75809A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _xpBoard(dark),
          const SizedBox(height: 18),
          if (rec == null)
            _noRecommendation(dark)
          else if (status == 'matched')
            _matchedResult(rec, dark)
          else if (status == 'continue' || status == 'no_match')
            _noMatchResult(dark)
          else if (status == 'waiting')
            _waitingMatch(rec, dark)
          else
            _recommendation(rec, dark),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }

  Widget _xpBoard(bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? Colors.white10 : const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Oyun XP',
            style: TextStyle(
              color: dark ? Colors.white : AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < leaderboard.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}.',
                      style: TextStyle(
                        color: dark ? Colors.white70 : AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      leaderboard[i]['name']?.toString() ?? 'Oyuncu',
                      style: TextStyle(
                        color: dark ? Colors.white : AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '+${(leaderboard[i]['xp'] as num?)?.toInt() ?? 0} XP',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _recommendation(Map<String, dynamic> rec, bool dark) {
    final compatibility = (rec['compatibility'] as num?)?.toInt() ?? 0;
    final partner = <String, dynamic>{
      'name': rec['partnerName'],
      'photoUrl': rec['partnerPhotoUrl'],
    };
    final name = rec['partnerName']?.toString() ?? 'Oyuncu';
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.lime.withOpacity(.16),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.lime, width: 2),
          ),
          child: Column(
            children: [
              _avatar(partner, radius: 37),
              const SizedBox(height: 10),
              Text(
                '$name ile en yakın sonuçlara sahipsiniz.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Oyun Uyumu  %$compatibility',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Öneri 6 turdaki cevap benzerliğine ve karşılıklı eşleşme tercihlerine göre oluşturuldu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF667089),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _primaryButton('$name ile eşleş', Icons.favorite_rounded, () => _finalChoice(true)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: loading ? null : () => _finalChoice(false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text(
              'Odaya devam et',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Seçimler gizlidir. Karşı tarafın seçimi açıklanmaz.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: dark ? Colors.white54 : const Color(0xFF8A93A8),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _waitingMatch(Map<String, dynamic> rec, bool dark) {
    return Column(
      children: [
        const CircularProgressIndicator(color: AppColors.lime),
        const SizedBox(height: 12),
        Text(
          'Seçimin gizli olarak kaydedildi.',
          style: TextStyle(
            color: dark ? Colors.white : AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Karşılıklı seçim oluşursa burada göreceksin.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: dark ? Colors.white60 : const Color(0xFF75809A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        TextButton(onPressed: _continueRoom, child: const Text('Odaya dön')),
      ],
    );
  }

  Widget _matchedResult(Map<String, dynamic> rec, bool dark) {
    final name = rec['partnerName']?.toString() ?? 'Oyuncu';
    return Column(
      children: [
        const Text('💚', style: TextStyle(fontSize: 46)),
        Text(
          'Eşleştiniz!',
          style: TextStyle(
            color: dark ? Colors.white : AppColors.navy,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$name de seninle eşleşmeyi seçti.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: dark ? Colors.white60 : const Color(0xFF75809A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _primaryButton('Özel mesaja geç', Icons.chat_bubble_rounded, _openPrivateChat),
      ],
    );
  }

  Widget _noMatchResult(bool dark) {
    return Column(
      children: [
        Icon(Icons.groups_rounded, size: 48, color: dark ? Colors.white70 : AppColors.navy),
        const SizedBox(height: 8),
        Text(
          'Eşleşme oluşmadı',
          style: TextStyle(
            color: dark ? Colors.white : AppColors.navy,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Diğer kişinin ne seçtiği gizli kalır.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: dark ? Colors.white60 : const Color(0xFF75809A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        _primaryButton('Odaya dön', Icons.arrow_back_rounded, _continueRoom),
      ],
    );
  }

  Widget _noRecommendation(bool dark) {
    return Column(
      children: [
        Icon(Icons.person_search_rounded, size: 50, color: dark ? Colors.white70 : AppColors.navy),
        const SizedBox(height: 8),
        Text(
          'Bu odada uygun eşleşme önerisi oluşmadı.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: dark ? Colors.white : AppColors.navy,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 14),
        _primaryButton('Odaya devam et', Icons.groups_rounded, _continueRoom),
      ],
    );
  }

  Widget _waitingPanel(String text, bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? Colors.white10 : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.lime),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: dark ? Colors.white70 : AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _errorCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
          const SizedBox(height: 10),
          Text(error ?? 'Mini oyun yüklenemedi.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}
