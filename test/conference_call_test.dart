import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/calling/invite_participant_sheet.dart';
import 'package:connect_call/services/zego_call_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('Conference Call & In-Call Invitation Tests', () {
    test('inviteToOngoingCall executes cleanly in test mode', () async {
      final service = ZegoCallService();
      final targetUser = UserModel(
        uid: 'user_target_456',
        name: 'Conference Friend',
        phoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      );

      final audioInvited = await service.inviteToOngoingCall(
        targetUser: targetUser,
        isVideo: false,
      );
      expect(audioInvited, isTrue);

      final videoInvited = await service.inviteToOngoingCall(
        targetUser: targetUser,
        isVideo: true,
      );
      expect(videoInvited, isTrue);
    });

    testWidgets('InviteParticipantSheet renders header and search field for voice call', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InviteParticipantSheet(isVideo: false),
          ),
        ),
      );

      expect(find.text('Add to Voice Conference'), findsOneWidget);
      expect(find.text('Invite contact to join ongoing call'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('InviteParticipantSheet renders header for video call', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InviteParticipantSheet(isVideo: true),
          ),
        ),
      );

      expect(find.text('Add to Video Conference'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('InviteParticipantSheet show opens modal bottom sheet cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => InviteParticipantSheet.show(ctx, isVideo: false),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Add to Voice Conference'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
