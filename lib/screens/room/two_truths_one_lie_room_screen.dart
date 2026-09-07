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

enum _TimedStage { prepare, answer, result, finalStage }

class _MiniGameRoomScreenState extends State<MiniGameRoomScreen> {
  static const int prepareSeconds = 45;
  static const int answerSeconds = 45;
  static const int resultSeconds = 10;

  final controllers = List.generate(3, (_) => TextEditingController());
  Map<String, dynamic>? state;
  String? error;
  bool loading = true;
  bool transitioning = false;
  int lieIndex = 2;
  int? selectedVote;
  int? trackedRound;
  int secondsLeft = prepareSeconds;
  _TimedStage timedStage = _TimedStage.prepare;
  Timer? refreshTimer;
  Timer? phaseTimer;

  @override
  void initState() {
    super.initState();
    _load();
    refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && !loading && !transitioning) _load(silent: true);
    });
    phaseTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    phaseTimer?.cancel();
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
      _applyServerState(data);
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

  void _applyServerState(Map<String, dynamic> data) {
    final nextRound = (data['roundIndex'] as num?)?.toInt() ?? 0;
    final nextPhase = data['phase']?.toString() ?? 'write';
    final roundChanged = trackedRound != nextRound;

    setState(() {
      state = data;
      error = null;
      if (nextPhase == 'final') {
        timedStage = _TimedStage.finalStage;
        secondsLeft = 0;
        trackedRound = nextRound;
        return;
      }
      if (roundChanged || trackedRound == null) {
        trackedRound = nextRound;
        timedStage = _TimedStage.prepare;
        secondsLeft = prepareSeconds;
        selectedVote = null;
        lieIndex = 2;
        for (final c in controllers) c.clear();
      }
    });
  }

  Future<void> _tick() async {
    if (!mounted || loading || transitioning || timedStage == _TimedStage.finalStage) return;
    if (secondsLeft > 1) {
      setState(() => secondsLeft--);
      return;
    }
    setState(() => secondsLeft = 0);

    switch (timedStage) {
      case _TimedStage.prepare:
        if (isMyTurn) {
          final values = controllers.map((c) => c.text.trim()).toList();
          if (values.any((v) => v.length < 2)) {
            setState(() => error = 'Süre doldu. Devam etmek için üç ifadeyi de doldur.');
            return;
          }
          await _submitStatements(forceStageAdvance: true);
        } else {
          _startAnswerStage();
        }
        break;
      case _TimedStage.answer:
        if (!isMyTurn && phase != 'result') {
          selectedVote ??= 0;
          await _submitVote(forceStageAdvance: true);
        } else {
          _startResultStage();
        }
        break;
      case _TimedStage.result:
        await _nextTimed();
        break;
      case _TimedStage.finalStage:
        break;
    }
  }

  void _startAnswerStage() {
    if (!mounted) return;
    setState(() {
      timedStage = _TimedStage.answer;
      secondsLeft = answerSeconds;
      error = null;
    });
  }

  void _startResultStage() {
    if (!mounted) return;
    setState(() {
      timedStage = _TimedStage.result;
      secondsLeft = resultSeconds;
      error = null;
    });
  }

  Future<Map<String, dynamic>?> _run(
      Future<Map<String, dynamic>> Function() action) async {
    if (transitioning) return null;
    transitioning = true;
    if (mounted) setState(() => error = null);
    try {
      return await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'İşlem tamamlanamadı.');
    } finally {
      transitioning = false;
    }
    return null;
  }

  Future<void> _submitStatements({bool forceStageAdvance = false}) async {
    final values = controllers.map((c) => c.text.trim()).toList();
    if (values.any((v) => v.length < 2)) {
      setState(() => error = 'Üç ifadeyi de doldur.');
      return;
    }
    final data = await _run(() => MiniGameApiService.submitStatements(
          widget.roomId,
          values,
          lieIndex,
        ));
    if (!mounted || data == null) return;
    setState(() => state = data);
    _startAnswerStage();
  }

  Future<void> _submitVote({bool forceStageAdvance = false}) async {
    if (selectedVote == null) {
      setState(() => error = 'Yalan olduğunu düşündüğün ifadeyi seç.');
      return;
    }
    final data = await _run(() => MiniGameApiService.vote(widget.roomId, selectedVote!));
    if (!mounted || data == null) return;
    setState(() => state = data);
    _startResultStage();
  }

  Future<void> _nextTimed() async {
    final data = await _run(() => MiniGameApiService.next(widget.roomId));
    if (!mounted || data == null) return;
    final nextPhase = data['phase']?.toString() ?? '';
    if (nextPhase == 'final') {
      setState(() {
        state = data;
        timedStage = _TimedStage.finalStage;
        secondsLeft = 0;
      });
      return;
    }
    final nextRound = (data['roundIndex'] as num?)?.toInt() ?? roundIndex;
    setState(() {
      state = data;
      trackedRound = nextRound;
      timedStage = _TimedStage.prepare;
      secondsLeft = prepareSeconds;
      selectedVote = null;
      lieIndex = 2;
      for (final c in controllers) c.clear();
    });
  }

  Future<void> _finalChoice(bool match) async {
    final data = await _run(() => MiniGameApiService.finalChoice(widget.roomId, match: match));
    if (mounted && data != null) setState(() => state = data);
  }

  void _goHome() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
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

  String get _stageLabel {
    switch (timedStage) {
      case _TimedStage.prepare:
        return isMyTurn ? 'İfadelerini hazırla' : '$ownerName hazırlanıyor';
      case _TimedStage.answer:
        return isMyTurn ? 'Diğer oyuncular cevaplıyor' : 'Yalanı işaretle';
      case _TimedStage.result:
        return 'Sonucu incele';
      case _TimedStage.finalStage:
        return 'Oyun tamamlandı';
    }
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
                  : timedStage == _TimedStage.finalStage || phase == 'final'
                      ? _finalScreen(dark)
                      : _gameScreen(dark),
        ),
      ),
    );
  }

  Widget _gameScreen(bool dark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: _goHome,
                style: IconButton.styleFrom(backgroundColor: dark ? Colors.white10 : Colors.white),
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: dark ? Colors.white : AppColors.navy),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('İki Doğru Bir Yalan',
                        style: TextStyle(
                            color: dark ? Colors.white : AppColors.navy,
                            fontSize: 21,
                            fontWeight: FontWeight.w900)),
                    Text('${roundIndex + 1}/6 tur · yaklaşık 10 dk',
                        style: TextStyle(
                            color: dark ? Colors.white60 : const Color(0xFF727B97),
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              _timerPill(),
            ],
          ),
        ),
        _playersRow(dark),
        const SizedBox(height: 8),
        Text(_stageLabel,
            style: TextStyle(
                color: dark ? Colors.white70 : AppColors.navy,
                fontSize: 14,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: _gameCard(dark),
          ),
        ),
      ],
    );
  }

  Widget _timerPill() {
    final max = timedStage == _TimedStage.result ? resultSeconds : 45;
    final urgent = secondsLeft <= 10;
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFFEEF0) : AppColors.lime,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text('${secondsLeft}s',
              style: TextStyle(
                  color: urgent ? const Color(0xFFD92B42) : AppColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          Text('/ $max',
              style: TextStyle(
                  color: urgent ? const Color(0xFFD92B42) : AppColors.navy,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _gameCard(bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111A2D) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 24,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          if (timedStage == _TimedStage.prepare) _prepareArea(dark),
          if (timedStage == _TimedStage.answer) _answerArea(dark),
          if (timedStage == _TimedStage.result) _resultArea(dark),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }

  Widget _prepareArea(bool dark) {
    if (!isMyTurn) {
      return _waiting('$ownerName iki doğru ve bir yalan hazırlıyor…', dark);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('3 ifade yaz',
            style: TextStyle(
                color: AppColors.navy,
                fontSize: 24,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Hazırlamak için 45 saniyen var.',
            style: TextStyle(
                color: Color(0xFF747D98), fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        for (var i = 0; i < 3; i++) ...[
          TextField(
            controller: controllers[i],
            maxLength: 120,
            decoration: InputDecoration(
              counterText: '',
              hintText: '${i + 1}. ifade',
              filled: true,
              fillColor: dark ? Colors.white10 : const Color(0xFFF8FAFD),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          RadioListTile<int>(
            value: i,
            groupValue: lieIndex,
            dense: true,
            activeColor: AppColors.lime,
            onChanged: transitioning ? null : (v) => setState(() => lieIndex = v ?? 2),
            title: Text('Bu ifade yalan',
                style: TextStyle(
                    color: dark ? Colors.white : AppColors.navy,
                    fontWeight: FontWeight.w800)),
          ),
        ],
        _primaryButton('Hazır', Icons.check_rounded, _submitStatements),
      ],
    );
  }

  Widget _answerArea(bool dark) {
    if (isMyTurn) {
      return _waiting('Diğer 5 oyuncu cevaplıyor…', dark);
    }
    if (statements.isEmpty) {
      return _waiting('$ownerName ifadelerini gönderiyor…', dark);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Hangisi yalan?',
            style: TextStyle(
                color: AppColors.navy,
                fontSize: 24,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('İşaretlemek için 45 saniyen var.',
            style: TextStyle(
                color: Color(0xFF747D98), fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        for (var i = 0; i < statements.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: transitioning ? null : () => setState(() => selectedVote = i),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selectedVote == i
                      ? AppColors.lime.withOpacity(.18)
                      : (dark ? Colors.white10 : const Color(0xFFF8FAFD)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selectedVote == i
                        ? AppColors.lime
                        : const Color(0xFFE2E7F0),
                    width: selectedVote == i ? 2 : 1,
                  ),
                ),
                child: Text(statements[i],
                    style: TextStyle(
                        color: dark ? Colors.white : AppColors.navy,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Tur sonucu',
            style: TextStyle(
                color: AppColors.navy,
                fontSize: 24,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Sonucu görmek için 10 saniye.',
            style: TextStyle(
                color: Color(0xFF747D98), fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        for (var i = 0; i < statements.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: i == lie
                  ? AppColors.lime.withOpacity(.20)
                  : (dark ? Colors.white10 : const Color(0xFFF8FAFD)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: i == lie ? AppColors.lime : const Color(0xFFE2E7F0)),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(statements[i],
                        style: TextStyle(
                            color: dark ? Colors.white : AppColors.navy,
                            fontWeight: FontWeight.w800))),
                Text('${i < counts.length ? counts[i] : 0} oy',
                    style: const TextStyle(
                        color: AppColors.navy, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        Text(lie >= 0 ? 'Yalan ${lie + 1}. ifadeydi' : 'Tur tamamlandı',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: dark ? Colors.white : AppColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _playersRow(bool dark) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final p = players[index];
          final active = p['id']?.toString() == ownerUserId;
          final name = p['name']?.toString() ?? 'Oyuncu';
          final photo = p['photoUrl']?.toString() ?? '';
          return SizedBox(
            width: 58,
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: active ? AppColors.lime : const Color(0xFFE1E6EF),
                        width: active ? 3 : 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: photo.isEmpty
                      ? Center(
                          child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w900)))
                      : Image.network(photo, fit: BoxFit.cover),
                ),
                const SizedBox(height: 3),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: dark ? Colors.white70 : const Color(0xFF69738D),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _finalScreen(bool dark) {
    final rec = recommendation;
    final partnerName = rec?['partnerName']?.toString() ?? 'Oyuncu';
    final compatibility = (rec?['compatibility'] as num?)?.toInt() ?? 0;
    final status = finalDecision['status']?.toString() ?? 'pending';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.emoji_events_rounded, color: AppColors.lime, size: 74),
            const SizedBox(height: 12),
            const Text('6 tur tamamlandı',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 32,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Yaklaşık 10 dakikalık oyun bitti.\n$partnerName ile oyun uyumun %$compatibility.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF737A96),
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            if (status == 'matched') ...[
              _primaryButton('Özel mesaja geç', Icons.chat_bubble_rounded, _openPrivateChat),
            ] else if (status == 'waiting') ...[
              const Text('Seçimin kaydedildi. Karşı tarafın seçimi bekleniyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.navy, fontWeight: FontWeight.w800)),
            ] else ...[
              _primaryButton('$partnerName ile eşleş', Icons.favorite_rounded,
                  () => _finalChoice(true)),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: transitioning
                    ? null
                    : () async {
                        await _finalChoice(false);
                        if (mounted) _continueRoom();
                      },
                child: const Text('Odaya devam et'),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(onPressed: _goHome, child: const Text('Ana sayfaya dön')),
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
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.lime),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: dark ? Colors.white70 : AppColors.navy,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback action) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: transitioning ? null : action,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        icon: Icon(icon),
        label: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
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
            FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
