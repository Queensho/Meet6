import 'package:flutter/material.dart';

import '../../services/mini_game_selection_service.dart';
import 'red_flag_green_flag_room_screen_v2.dart';
import 'two_truths_one_lie_room_screen.dart' as truths;

class MiniGameRoomScreen extends StatelessWidget {
  const MiniGameRoomScreen({
    super.key,
    required this.roomId,
    this.profileName = '',
  });

  final String roomId;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    if (MiniGameSelectionService.selectedGameKey == 'red_flag_green_flag') {
      return RedFlagGreenFlagRoomScreenV2(
        roomId: roomId,
        profileName: profileName,
      );
    }
    return truths.MiniGameRoomScreen(
      roomId: roomId,
      profileName: profileName,
    );
  }
}
