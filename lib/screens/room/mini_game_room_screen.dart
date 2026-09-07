import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/mini_game_api_service.dart';
import '../../services/mini_game_selection_service.dart';
import '../../services/red_flag_game_api_service.dart';
import '../../theme/app_colors.dart';
import '../messages/private_chat_screen.dart';
import 'red_flag_green_flag_room_screen_v2.dart';
import 'two_truths_one_lie_room_screen.dart' as truths;

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

class _MiniGameRoomScreenState extends State<MiniGameRoomScreen>
    with WidgetsBindingObserver {
  late Future<String> _gameKeyFuture;
  bool _leaving = false;
  bool _finishing = false;
  bool _finalChoosing = false;
  int _resumeEpoch = 0;
  Map<String, dynamic>? _forcedResult;
  String? _forcedGameKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameKeyFuture = _resolveGameKey();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted || _forcedResult != null) return;

    // Browser/Android can throttle or completely pause Dart timers while the app
    // is in the background. Mini-game time belongs to the server, so when the
    // user returns we recreate the active game screen and fetch fresh state.
    setState(() {
      _resumeEpoch += 1;
      _gameKeyFuture = _resolveGameKey();
    });
  }

  Future<String> _resolveGameKey() async {
    final selected = MiniGameSelectionService.selectedGameKey;
    if (selected == 'red_flag_green_flag') return selected;

    try {
      final state = await RedFlagGameApiService.state(widget.roomId);
      if (state['game']?.toString() == 'red_flag_green_flag') {
        MiniGameSelectionService.select('red_flag_green_flag');
        return 'red_flag_green_flag';
      }
    } catch (_) {}

    return selected;
  }

  Future<void> _goHome() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    FocusManager.instance.primaryFocus?.unfocus();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _leaving = false;
  }

  Future<void> _forceFinish(String gameKey) async {
    if (_finishing || !mounted) return;
    setState(() => _finishing = true);
    try {
      final result = await MiniGameApiService.forceFinish(
        widget.roomId,
        gameKey: gameKey,
      );
      if (!mounted) return;

      // force-finish already returns the complete final game state. Keep and
      // render that response directly. The room is closed by the backend, so a
      // second state request can legitimately fail and must not replace the
      // final result with an empty 00:00 game screen.
      setState(() {
        _forcedResult = result;
        _forcedGameKey = gameKey;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oyun test için bitirildi.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oyun bitirilemedi.')),
      );
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _forcedFinalChoice(bool match) async {
    final gameKey = _forcedGameKey;
    if (gameKey == null || _finalChoosing || !mounted) return;
    setState(() => _finalChoosing = true);
    try {
      final data = gameKey == 'red_flag_green_flag'
          ? await RedFlagGameApiService.finalChoice(widget.roomId, match: match)
          : await MiniGameApiService.finalChoice(widget.roomId, match: match);
      if (!mounted) return;
      setState(() => _forcedResult = data);
      if (!match) await _goHome();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _finalChoosing = false);
    }
  }

  void _openForcedChat() {
    final result = _forcedResult;
    if (result == null) return;
    final recRaw = result['recommendation'];
    final decisionRaw = result['finalDecision'];
    if (recRaw is! Map || decisionRaw is! Map) return;
    final rec = Map<String, dynamic>.from(recRaw);
    final decision = Map<String, dynamic>.from(decisionRaw);
    final matchId = decision['matchId']?.toString() ?? '';
    if (matchId.isEmpty) return;
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

  Widget _forceFinishedScreen() {
    final result = _forcedResult ?? const <String, dynamic>{};
    final recRaw = result['recommendation'];
    final decisionRaw = result['finalDecision'];
    final rec = recRaw is Map ? Map<String, dynamic>.from(recRaw) : <String, dynamic>{};
    final decision = decisionRaw is Map ? Map<String, dynamic>.from(decisionRaw) : <String, dynamic>{};
    final partnerName = rec['partnerName']?.toString() ?? '';
    final compatibility = (rec['compatibility'] as num?)?.toInt();
    final status = decision['status']?.toString() ?? 'pending';
    final same = rec['sameAnswers'];
    final different = rec['differentAnswers'];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.lime, size: 76),
                const SizedBox(height: 14),
                const Text(
                  'Oyun tamamlandı',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                if (partnerName.isNotEmpty && compatibility != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        Text(
                          partnerName,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '%$compatibility uyum',
                          style: const TextStyle(
                            color: Color(0xFF2454FF),
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (same != null && different != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '$same aynı seçim · $different farklı seçim',
                            style: const TextStyle(
                              color: Color(0xFF7C839D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (status == 'matched')
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _openForcedChat,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
                        icon: const Icon(Icons.chat_bubble_rounded),
                        label: const Text('Eşleştiniz · Özel mesaja geç'),
                      ),
                    )
                  else if (status == 'waiting')
                    const Text(
                      'Seçimin kaydedildi. Karşı tarafın seçimi bekleniyor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800),
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _finalChoosing ? null : () => _forcedFinalChoice(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.navy,
                        ),
                        icon: const Icon(Icons.favorite_rounded),
                        label: Text(
                          '$partnerName ile eşleş',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  const Text(
                    'Eşleşme önerisi oluşturulamadı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF737A96),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _goHome,
                  child: const Text('Ana sayfaya dön'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_forcedResult != null) return _forceFinishedScreen();

    return FutureBuilder<String>(
      future: _gameKeyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final gameKey = snapshot.data ?? MiniGameSelectionService.selectedGameKey;
        final Widget game;
        final childKey = ValueKey('${widget.roomId}:$_resumeEpoch:$gameKey');
        if (gameKey == 'red_flag_green_flag') {
          game = RedFlagGreenFlagRoomScreenV2(
            key: childKey,
            roomId: widget.roomId,
            profileName: widget.profileName,
          );
        } else {
          game = PopScope(
            canPop: false,
            onPopInvokedWithResult: (_, __) => _goHome(),
            child: truths.MiniGameRoomScreen(
              key: childKey,
              roomId: widget.roomId,
              profileName: widget.profileName,
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(child: game),
            Positioned(
              right: 14,
              bottom: 18,
              child: SafeArea(
                child: FilledButton.icon(
                  onPressed: _finishing ? null : () => _forceFinish(gameKey),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111A2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                  icon: _finishing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.fast_forward_rounded, size: 20),
                  label: const Text(
                    'Test: Oyunu bitir',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
