import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meet6/models/picked_profile_photo.dart';
import 'package:meet6/screens/chat/room_chat_screen.dart';
import 'package:meet6/screens/chat/room_selection_screen.dart';
import 'package:meet6/screens/home/home_screen.dart';
import 'package:meet6/screens/login_screen.dart';
import 'package:meet6/screens/matches/match_success_screen.dart';
import 'package:meet6/screens/messages/private_chat_screen.dart';
import 'package:meet6/screens/otp_screen.dart';
import 'package:meet6/screens/profile/profile_setup_screen.dart';
import 'package:meet6/screens/room/room_searching_screen.dart';
import 'package:meet6/services/api_service.dart';
import 'package:meet6/services/location_service.dart';
import 'package:meet6/services/profile_photo_service.dart';
import 'package:meet6/services/realtime_service.dart';
import 'package:meet6/services/session_service.dart';

Future<void> pumpFor(
  WidgetTester tester,
  Duration duration, {
  Duration step = const Duration(milliseconds: 50),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return;
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 80));
}

PickedProfilePhoto fakeProfilePhoto() {
  final bytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  return PickedProfilePhoto(
    bytes: bytes,
    fileName: 'profile.jpg',
    mimeType: 'image/jpeg',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ApiService.debugResetTestHooks();
    ProfilePhotoService.debugResetTestHooks();
    LocationService.debugResetTestHooks();
    RealtimeService.debugResetTestHooks();
  });

  tearDown(() {
    ApiService.debugResetTestHooks();
    ProfilePhotoService.debugResetTestHooks();
    LocationService.debugResetTestHooks();
    RealtimeService.debugResetTestHooks();
  });

  testWidgets('login -> OTP -> new user profile setup', (tester) async {
    var requestedPhone = '';
    var verifiedCode = '';
    ApiService.debugTestHooks = ApiServiceTestHooks(
      requestOtp: (phone) async {
        requestedPhone = phone;
      },
      verifyOtp: (phone, code) async {
        verifiedCode = code;
        return const AuthResult(
          sessionId: 'session-test',
          userId: '1',
          isNewUser: true,
          profileCompleted: false,
        );
      },
    );

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField).first, '5551234567');
    await tester.tap(find.textContaining('KVKK Aydınlatma Metni'));
    await tester.pump();
    await scrollTo(tester, find.text('Devam et'));
    await tester.tap(find.text('Devam et'));
    await pumpFor(tester, const Duration(milliseconds: 250));

    expect(requestedPhone, '5551234567');
    expect(find.byType(OtpScreen), findsOneWidget);

    final otpFields = find.byType(TextField);
    expect(otpFields, findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      await tester.enterText(otpFields.at(i), '${i + 1}');
      await tester.pump();
    }

    await scrollTo(tester, find.text('Doğrula'));
    await tester.tap(find.text('Doğrula'));
    await pumpFor(tester, const Duration(milliseconds: 350));

    expect(verifiedCode, '123456');
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(await SessionService.loadAuthSessionId(), 'session-test');
    expect(await SessionService.loadAuthUserId(), '1');
  });

  testWidgets('profile setup completes and persists profile', (tester) async {
    await SessionService.saveAuth(sessionId: 'session-test', userId: '1');

    final uploadedPhoto = fakeProfilePhoto();
    Map<String, dynamic>? savedProfile;
    Map<String, dynamic>? savedPreferences;

    ProfilePhotoService.debugPickManyOverride = (_, __, ___) async => [uploadedPhoto];
    ProfilePhotoService.debugPickOverride = (_, __) async => uploadedPhoto;
    LocationService.debugGetCurrentLocationOverride = () async => const AppLocation(
          latitude: 41.0082,
          longitude: 28.9784,
          city: 'İstanbul',
          country: 'Türkiye',
        );
    ApiService.debugTestHooks = ApiServiceTestHooks(
      uploadProfilePhotos: (_) async => ['/uploads/test/profile.jpg'],
      updateProfile: (payload) async {
        savedProfile = payload;
      },
      updatePreferences: (payload) async {
        savedPreferences = payload;
      },
    );
    RealtimeService.debugAckOverride = (event, data) async => {'ok': true};

    await tester.pumpWidget(const MaterialApp(home: ProfileSetupScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Profil fotoğrafı ekle'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).first, 'Tayfun');

    await tester.tap(find.byType(TextField).at(1));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Seç'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Erkek'));
    await scrollTo(tester, find.text('Devam et'));
    await tester.tap(find.text('Devam et'));
    await pumpFor(tester, const Duration(milliseconds: 250));

    expect(find.textContaining('İstanbul'), findsOneWidget);
    await tester.tap(find.text('Herkes'));
    await scrollTo(tester, find.text('Yeni insanlarla tanışma'));
    await tester.tap(find.text('Yeni insanlarla tanışma'));
    await scrollTo(tester, find.text('Devam et'));
    await tester.tap(find.text('Devam et'));
    await pumpFor(tester, const Duration(milliseconds: 150));

    final profileFields = find.byType(TextField);
    expect(profileFields, findsNWidgets(2));
    await tester.enterText(profileFields.at(0), 'Kahve ve motosiklet severim.');
    await tester.tap(find.text('Kahve'));
    await scrollTo(tester, profileFields.at(1));
    await tester.enterText(profileFields.at(1), 'Samimi olmak ve bol bol gülmek.');
    await scrollTo(tester, find.text('Profili tamamla'));
    await tester.tap(find.text('Profili tamamla'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    expect(savedProfile?['displayName'], 'Tayfun');
    expect(savedProfile?['city'], 'İstanbul');
    expect(savedProfile?['profileCompleted'], isTrue);
    expect(savedProfile?['photoUrls'], ['/uploads/test/profile.jpg']);
    expect(savedPreferences?['lookingFor'], 'Herkes');
    expect(savedPreferences?['purpose'], 'Yeni insanlarla tanışma');

    final persisted = await SessionService.loadProfile();
    expect(persisted?.profileName, 'Tayfun');
    expect(persisted?.city, 'İstanbul');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('room search -> room -> selection -> match -> first message', (tester) async {
    await SessionService.saveAuth(sessionId: 'session-test', userId: '1');

    final members = <Map<String, dynamic>>[
      {'user_id': '1', 'display_name': 'Tayfun', 'age': 31, 'photo_urls': <String>[]},
      {'user_id': '2', 'display_name': 'Ayşe', 'age': 28, 'photo_urls': <String>[]},
      {'user_id': '3', 'display_name': 'Ece', 'age': 29, 'photo_urls': <String>[]},
      {'user_id': '4', 'display_name': 'Mert', 'age': 30, 'photo_urls': <String>[]},
      {'user_id': '5', 'display_name': 'Can', 'age': 32, 'photo_urls': <String>[]},
      {'user_id': '6', 'display_name': 'Deniz', 'age': 27, 'photo_urls': <String>[]},
    ];

    Map<String, dynamic> activeRoom() => {
          'id': 'room-1',
          'status': 'active',
          'secondsLeft': 900,
          'canVoteExtension': false,
          'members': members,
          'config': {'selectionSeconds': 10},
        };
    Map<String, dynamic> selectionRoom() => {
          'id': 'room-1',
          'status': 'selection',
          'selectionSecondsLeft': 10,
          'members': members,
          'config': {'selectionSeconds': 10},
        };

    var inSelection = false;
    String? firstMessageBody;

    RealtimeService.debugAckOverride = (event, data) async {
      switch (event) {
        case 'queue:join':
          return {'ok': true, 'state': 'room', 'room': activeRoom()};
        case 'queue:cancel':
          return {'ok': true};
        case 'room:join':
          return {'ok': true, 'room': inSelection ? selectionRoom() : activeRoom()};
        case 'room:messages':
          return {'ok': true, 'messages': <Map<String, dynamic>>[]};
        case 'room:leave':
          return {'ok': true};
        case 'room:selection':
          expect(data['selectedUserId'], 2);
          return {'ok': true, 'matched': true, 'matchId': 'match-1'};
        case 'match:join':
          return {
            'ok': true,
            'profile': {
              'user_id': '2',
              'display_name': 'Ayşe',
              'photo_urls': <String>[],
              'online': true,
            },
          };
        case 'match:messages':
          return {'ok': true, 'messages': <Map<String, dynamic>>[]};
        case 'match:read':
          return {'ok': true};
        case 'match:send':
          firstMessageBody = data['body']?.toString();
          return {'ok': true, 'messageId': '100'};
        case 'match:leave':
          return {'ok': true};
        default:
          return {'ok': true};
      }
    };

    await tester.pumpWidget(
      const MaterialApp(home: RoomSearchingScreen(profileName: 'Tayfun')),
    );
    await pumpFor(tester, const Duration(milliseconds: 750));

    expect(find.byType(RoomChatScreen), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 250));

    inSelection = true;
    RealtimeService.debugEmit(
      'room:update',
      {'roomId': 'room-1', 'room': selectionRoom()},
    );
    await pumpFor(tester, const Duration(milliseconds: 300));

    expect(find.byType(RoomSelectionScreen), findsOneWidget);
    expect(find.text('Ayşe, 28'), findsOneWidget);

    await tester.tap(find.text('Ayşe, 28'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Ayşe ile devam et'));
    await pumpFor(tester, const Duration(milliseconds: 350));

    expect(find.byType(MatchSuccessScreen), findsOneWidget);
    expect(find.text('Eşleştiniz!'), findsOneWidget);

    await tester.tap(find.text('Mesaj gönder'));
    await pumpFor(tester, const Duration(milliseconds: 300));

    expect(find.byType(PrivateChatScreen), findsOneWidget);
    final messageField = find.byType(TextField).last;
    await tester.enterText(messageField, 'Merhaba Ayşe 👋');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await pumpFor(tester, const Duration(milliseconds: 150));

    expect(firstMessageBody, 'Merhaba Ayşe 👋');
  });
}
