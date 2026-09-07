import 'package:flutter/material.dart';

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

class _MiniGameRoomScreenState extends State<MiniGameRoomScreen> {
  late final Future<String> _gameKeyFuture;

  @override
  void initState() {
    super.initState();
    _gameKeyFuture = _resolveGameKey();
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
        if (gameKey == 'red_flag_green_flag') {
          return RedFlagGreenFlagRoomScreenV2(
            roomId: widget.roomId,
            profileName: widget.profileName,
          );
        }

        return truths.MiniGameRoomScreen(
          roomId: widget.roomId,
          profileName: widget.profileName,
        );
      },
    );
  }
}
