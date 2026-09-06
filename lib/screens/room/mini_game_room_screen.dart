import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/mini_game_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await MiniGameApiService.state(widget.roomId);
      if (!mounted) return;
      setState(() => state = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'Mini oyun yüklenemedi.');
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

  Future<void> _vote(int index) async {
    await _act(() => MiniGameApiService.vote(widget.roomId, index));
  }

  Future<void> _next() async {
    for (final controller in controllers) controller.clear();
    setState(() => lieIndex = 2);
    await _act(() => MiniGameApiService.next(widget.roomId));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final phase = state?['phase']?.toString() ?? 'write';
    final ownerName = state?['ownerName']?.toString() ?? 'Oyuncu';
    final isMyTurn = state?['isMyTurn'] == true;
    final roundIndex = (state?['roundIndex'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [Color(0xFF101D16), Color(0xFF071022)]
                  : const [Color(0xFFD8FF32), Color(0xFFAECB18)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Row(
                    children: [
                      const Meet6MiniBrand(height: 28),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'TUR ${roundIndex + 1}',
                          style: const TextStyle(
                            color: AppColors.lime,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: dark ? Colors.white : AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                _playersStrip(dark),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.psychology_alt_rounded, color: AppColors.lime, size: 40),
                              SizedBox(height: 8),
                              Text(
                                'İki Doğru Bir Yalan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '3 ifadeden hangisinin yalan olduğunu bul.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (loading && state == null)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(color: AppColors.navy),
                          )
                        else if (error != null && state == null)
                          _errorCard()
                        else ...[
                          Text(
                            isMyTurn ? 'Sıra sende' : '$ownerName oynuyor',
                            style: TextStyle(
                              color: dark ? Colors.white : AppColors.navy,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (phase == 'write' && isMyTurn) _writeCard(dark),
                          if (phase == 'vote') _voteCard(dark, isMyTurn),
                          if (phase == 'result') _resultCard(dark),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playersStrip(bool dark) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final player = players[index];
          final name = player['name']?.toString() ?? 'Oyuncu';
          return Column(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.navy,
                child: Text(
                  name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.lime,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 64,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark ? Colors.white70 : AppColors.navy,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _writeCard(bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(dark),
      child: Column(
        children: [
          Text(
            '2 doğru + 1 yalan yaz',
            style: TextStyle(
              color: dark ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++) ...[
            TextField(
              controller: controllers[i],
              maxLength: 120,
              decoration: InputDecoration(
                labelText: '${i + 1}. ifade',
                filled: true,
                fillColor: dark ? Colors.white10 : Colors.white70,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            RadioListTile<int>(
              value: i,
              groupValue: lieIndex,
              onChanged: loading ? null : (value) => setState(() => lieIndex = value ?? 2),
              title: Text(
                'Bu ifade yalan',
                style: TextStyle(
                  color: dark ? Colors.white : AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : _submitStatements,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.send_rounded),
              label: const Text('İfadeleri gönder'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _voteCard(bool dark, bool isMyTurn) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(dark),
      child: Column(
        children: [
          Text(
            isMyTurn ? 'Diğer 5 oyuncu oy kullanıyor…' : 'Sence hangisi yalan?',
            style: TextStyle(
              color: dark ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < statements.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: loading || isMyTurn ? null : () => _vote(i),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: dark ? Colors.white : AppColors.navy,
                    side: const BorderSide(color: AppColors.navy, width: 2),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${i + 1}. ${statements[i]}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
          if (isMyTurn && !loading)
            FilledButton(
              onPressed: _load,
              child: const Text('Sonucu yenile'),
            ),
        ],
      ),
    );
  }

  Widget _resultCard(bool dark) {
    final result = state?['result'];
    final map = result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
    final correctIndex = (map['lieIndex'] as num?)?.toInt() ?? -1;
    final countsRaw = map['voteCounts'];
    final counts = countsRaw is List ? countsRaw.map((e) => (e as num?)?.toInt() ?? 0).toList() : <int>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(dark),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.navy, size: 42),
          const SizedBox(height: 8),
          Text(
            'Yalan ${correctIndex + 1}. ifadeydi',
            style: TextStyle(
              color: dark ? Colors.white : AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < statements.length; i++)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: i == correctIndex ? AppColors.lime : (dark ? Colors.white10 : Colors.white70),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${i + 1}. ${statements[i]}',
                      style: TextStyle(
                        color: AppColors.navy,
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : _next,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Sonraki oyuncu'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 44),
        const SizedBox(height: 8),
        Text(
          error ?? 'Mini oyun yüklenemedi.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tekrar dene'),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration(bool dark) {
    return BoxDecoration(
      color: dark ? const Color(0xFF10192A) : Colors.white.withOpacity(.86),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.navy.withOpacity(.16)),
    );
  }
}
