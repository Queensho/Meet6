import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/mini_game_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';

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

  String get phase => state?['phase']?.toString() ?? 'write';
  String get ownerName => state?['ownerName']?.toString() ?? 'Oyuncu';
  String get ownerUserId => state?['ownerUserId']?.toString() ?? '';
  bool get isMyTurn => state?['isMyTurn'] == true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF071022) : const Color(0xFFF8FAFF),
      body: PhoneFrame(
        child: SafeArea(
          child: Column(
            children: [
              _header(dark),
              _playersRow(dark),
              const SizedBox(height: 8),
              _turnChip(),
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
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: dark ? Colors.white : AppColors.navy),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mini Oyun Odası',
                  style: TextStyle(
                    color: dark ? Colors.white : AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'İki Doğru Bir Yalan',
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
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                Icon(Icons.schedule_rounded, color: AppColors.navy, size: 21),
                SizedBox(width: 7),
                Text(
                  '09:42',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
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
          final id = p['id']?.toString() ?? '';
          final active = id == ownerUserId;
          return SizedBox(
            width: 60,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(active ? 3 : 1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppColors.lime : Colors.transparent,
                    border: Border.all(
                      color: active
                          ? AppColors.lime
                          : (dark ? Colors.white24 : const Color(0xFFE0E5EF)),
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: const Color(0xFFF0F2F8),
                    child: Text(
                      name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
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

  Widget _gameCard(bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
      child: Column(
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
                child: const Icon(Icons.sports_esports_rounded,
                    color: AppColors.lime, size: 33),
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
            Text(error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }

  Widget _writeArea(bool dark) {
    if (!isMyTurn) {
      return _waitingPanel('$ownerName ifadelerini hazırlıyor…', dark);
    }
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE3E8F1)),
              ),
            ),
          ),
          RadioListTile<int>(
            value: i,
            groupValue: lieIndex,
            dense: true,
            activeColor: AppColors.lime,
            onChanged: loading ? null : (v) => setState(() => lieIndex = v ?? 2),
            title: Text('Bu ifade yalan',
                style: TextStyle(
                    color: dark ? Colors.white : AppColors.navy,
                    fontWeight: FontWeight.w800)),
          ),
        ],
        const SizedBox(height: 6),
        _primaryButton('İfadeleri gönder', Icons.send_rounded, _submitStatements),
      ],
    );
  }

  Widget _voteArea(bool dark) {
    if (isMyTurn) {
      return Column(
        children: [
          _waitingPanel('Diğer 5 oyuncu oy kullanıyor…', dark),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Durumu yenile'),
          ),
        ],
      );
    }

    final votes = state?['votes'];
    final voteCount = votes is Map ? votes.length : 0;
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: selectedVote == i
                      ? AppColors.lime.withOpacity(.15)
                      : (dark ? Colors.white10 : const Color(0xFFFDFEFF)),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selectedVote == i ? AppColors.lime : const Color(0xFFE2E7F0),
                    width: selectedVote == i ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        statements[i],
                        style: TextStyle(
                          color: dark ? Colors.white : AppColors.navy,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedVote == i ? AppColors.lime : const Color(0xFF9FA8BE),
                          width: 2,
                        ),
                        color: selectedVote == i ? AppColors.navy : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Divider(height: 26),
        Row(
          children: [
            const Icon(Icons.groups_rounded, color: AppColors.navy),
            const SizedBox(width: 8),
            Text('$voteCount/5 oy kullanıldı',
                style: TextStyle(
                    color: dark ? Colors.white70 : AppColors.navy,
                    fontWeight: FontWeight.w900)),
            const Spacer(),
            const Icon(Icons.timer_outlined, color: AppColors.navy),
            const SizedBox(width: 6),
            Text('Sonuç birazdan',
                style: TextStyle(
                    color: dark ? Colors.white60 : const Color(0xFF667089),
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.lime.withOpacity(.18),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.lime,
                child: Icon(Icons.star_rounded, color: AppColors.navy),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Doğru tahmin +20 XP',
                        style: TextStyle(
                            color: AppColors.navy, fontWeight: FontWeight.w900)),
                    Text('İyi düşün, sen yaparsın!',
                        style: TextStyle(
                            color: Color(0xFF667089), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Icon(Icons.emoji_events_outlined, color: AppColors.navy),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _primaryButton('Seçimini gönder', Icons.send_rounded, _submitVote),
        TextButton(onPressed: loading ? null : _load, child: const Text('Oyunu geç')),
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
                  child: Text(statements[i],
                      style: TextStyle(
                          color: dark ? Colors.white : AppColors.navy,
                          fontWeight: FontWeight.w800)),
                ),
                Text('${i < counts.length ? counts[i] : 0} oy',
                    style: const TextStyle(
                        color: AppColors.navy, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          lie >= 0 ? 'Yalan ${lie + 1}. ifadeydi' : 'Tur tamamlandı',
          style: TextStyle(
            color: dark ? Colors.white : AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        _primaryButton('Sonraki oyuncu', Icons.arrow_forward_rounded, _next),
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
        onPressed: loading ? null : action,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: Icon(icon),
        label: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
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
