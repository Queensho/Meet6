import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meet6/screens/home/home_screen.dart';
import 'package:meet6/services/active_room_service.dart';
import 'package:meet6/services/realtime_service.dart';
import 'package:meet6/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RealtimeService.debugResetTestHooks();
    ActiveRoomService.debugResetTestHooks();
    await SessionService.saveAuth(sessionId: 'session-test', userId: '1');
    RealtimeService.debugAckOverride = (event, data) async => {'ok': true};
  });

  tearDown(() {
    RealtimeService.debugResetTestHooks();
    ActiveRoomService.debugResetTestHooks();
  });

  testWidgets('home shows active voice room and explicit leave removes card', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var leftRoomId = '';
    ActiveRoomService.debugCurrentOverride = () async => {
          'ok': true,
          'room': {
            'id': '278',
            'status': 'active',
            'roomMode': 'voice',
            'secondsLeft': 1080,
            'selectionSecondsLeft': 0,
            'members': List.generate(6, (index) => {'user_id': '${index + 1}'}),
          },
        };
    ActiveRoomService.debugLeaveOverride = (roomId) async {
      leftRoomId = roomId;
      return {'ok': true, 'roomId': roomId, 'left': true};
    };

    await tester.pumpWidget(const MaterialApp(home: HomeScreen(profileName: 'Tayfun')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('AKTİF ODAN'), findsOneWidget);
    expect(find.text('Premium sesli odan devam ediyor'), findsOneWidget);
    expect(find.textContaining('Sesli oda · 6 kişi'), findsOneWidget);

    await tester.tap(find.text('Ayrıl'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Odadan ayrıl?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Odadan ayrıl'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(leftRoomId, '278');
    expect(find.text('AKTİF ODAN'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
