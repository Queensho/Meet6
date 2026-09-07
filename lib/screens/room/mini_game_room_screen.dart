import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/mini_game_api_service.dart';
import '../../services/mini_game_selection_service.dart';
import '../../services/red_flag_game_api_service.dart';
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
  int _resumeEpoch = 0;

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
    if (state != AppLifecycleState.resumed || !mounted) return;

    // Browser/Android can throttle or completely pause Dart timers while the app
    // is in the background. Mini-game time belongs to the server, so when the
    // user returns we recreate the active game screen and fetch fresh state.
    // This prevents a stale 00:00 screen from remaining on an old question/round.
    setState(() {
      _resumeEpoch += 1;
      _gameKeyFuture = _resolveGameKey();
    });
  }

  Future<String> _resolveGameKey() async {
    final selected = MiniGameSelectionService.selectedGameKey;
    if (selected == 'red_flag_green_flag') return selected;

    // Active-room recovery can lose the local selected game key after returning
    // to the home screen or reloading the web app. Probe the actual room state
    // so a Red Flag room never falls back to the generic/other game screen.
    try {
      final state = await RedFlagGameApiService.state(widget.roomId);
      if (state['game']?.toString() == 'red_flag_green_flag') {
        MiniGameSelectionService.select('red_flag_green_flag');
        return 'red_flag_green_flag';
      }
    } catch (_) {
      // Not a Red Flag room (or its state is unavailable); keep the selected key.
    }

    return selected;
  }

  Future<void> _goHome() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    FocusManager.instance.primaryFocus?.unfocus();

    // This screen is reached from Home through the room-search flow. Popping the
    // game route restores that existing Home instance, which then refreshes the
    // active room immediately. That keeps the first "Odaya dön" action pointed
    // at the correct game instead of briefly opening the generic chat room.
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
      await MiniGameApiService.forceFinish(widget.roomId, gameKey: gameKey);
      if (!mounted) return;
      // Recreate the child immediately so the force-finished server state is
      // visible without waiting for that game's polling timer.
      setState(() => _resumeEpoch += 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oyun test için bitirildi. Eşleşme sonucu hazırlanıyor.'),
        ),
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

  @override
  Widget build(BuildContext context) {
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
