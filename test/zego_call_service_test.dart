import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/models/zego_token_response.dart';
import 'package:connect_call/screens/calling/custom_audio_calling_view.dart';
import 'package:connect_call/services/zego_call_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('ZegoTokenResponse Model Tests', () {
    test('Correctly parses valid token map', () {
      final map = {
        'appId': 123456789,
        'userId': 'user_abc',
        'token': '04sampletokenbase64==',
        'expiresIn': 3600,
      };

      final response = ZegoTokenResponse.fromMap(map);
      expect(response.appId, 123456789);
      expect(response.userId, 'user_abc');
      expect(response.token, '04sampletokenbase64==');
      expect(response.expiresIn, 3600);
      expect(response.isValid, isTrue);

      final outMap = response.toMap();
      expect(outMap['appId'], 123456789);
      expect(outMap['userId'], 'user_abc');
      expect(outMap['token'], '04sampletokenbase64==');
      expect(outMap['expiresIn'], 3600);
    });

    test('Marks empty or invalid tokens as invalid', () {
      final invalidMap = {
        'appId': 0,
        'userId': '',
        'token': '',
        'expiresIn': 0,
      };

      final response = ZegoTokenResponse.fromMap(invalidMap);
      expect(response.isValid, isFalse);
    });
  });

  group('ZegoCallService Unit Tests', () {
    test('Initializes and deinitializes cleanly in test mode', () async {
      final service = ZegoCallService();
      expect(service.isInitialized.value, isFalse);
      expect(service.isCalling.value, isFalse);

      final initSuccess = await service.initZegoCallService();
      expect(initSuccess, isTrue);
      expect(service.isInitialized.value, isTrue);

      await service.uninit();
      expect(service.isInitialized.value, isFalse);
      expect(service.isCalling.value, isFalse);
    });

    test('Bypasses native hardware in test mode for audio call invitations', () async {
      final service = ZegoCallService();
      final targetUser = UserModel(
        uid: 'user_target_123',
        name: 'Jane Doe',
        email: 'jane@example.com',
        createdAt: DateTime.now(),
      );

      final callSent = await service.sendAudioCallInvitation(targetUser: targetUser);
      expect(callSent, isTrue);
    });

    test('Bypasses native hardware in test mode for video call invitations', () async {
      final service = ZegoCallService();
      final targetUser = UserModel(
        uid: 'user_target_123',
        name: 'Jane Doe',
        email: 'jane@example.com',
        createdAt: DateTime.now(),
      );

      final callSent = await service.sendVideoCallInvitation(targetUser: targetUser);
      expect(callSent, isTrue);
    });
  });

  group('CustomAudioCallingView Widget Tests', () {
    testWidgets('Renders header, duration, avatar, and modular action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomAudioCallingView(),
        ),
      );

      // Verify header and timer
      expect(find.text('End-to-end Encrypted'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);

      // Verify modular action buttons
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Keypad'), findsOneWidget);
      expect(find.text('Speaker'), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Add call'), findsOneWidget);
      expect(find.text('Hold'), findsOneWidget);

      // Verify Hang Up icon exists
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
    });

    testWidgets('Tapping Record toggles recording status banner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomAudioCallingView(),
        ),
      );

      // Tap Record
      await tester.tap(find.text('Record'));
      await tester.pump();

      // Verify REC banner appears and button switches to Stop Rec
      expect(find.textContaining('REC'), findsOneWidget);
      expect(find.text('Stop Rec'), findsOneWidget);

      // Tap Stop Rec
      await tester.tap(find.text('Stop Rec'));
      await tester.pump();

      expect(find.text('Record'), findsOneWidget);
    });

    testWidgets('Tapping Hold toggles call hold status banner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomAudioCallingView(),
        ),
      );

      // Tap Hold
      await tester.tap(find.text('Hold'));
      await tester.pump();

      // Verify ON HOLD badge appears
      expect(find.text('ON HOLD'), findsOneWidget);
      expect(find.text('Unhold'), findsOneWidget);
      expect(find.text('Call on hold'), findsOneWidget);

      // Tap Unhold
      await tester.tap(find.text('Unhold'));
      await tester.pump();

      expect(find.text('Hold'), findsOneWidget);
      expect(find.text('Voice Call in progress'), findsOneWidget);
    });

    testWidgets('Tapping Keypad opens dialpad and handles key presses', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomAudioCallingView(),
        ),
      );

      // Tap Keypad to open bottom sheet
      await tester.tap(find.text('Keypad'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify dialpad modal opened
      expect(find.text('Type numbers...'), findsOneWidget);

      // Tap digits '1', '2', '3'
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();

      expect(find.text('123'), findsOneWidget);
    });
  });
}
