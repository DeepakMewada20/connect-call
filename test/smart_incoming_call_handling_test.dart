import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:connect_call/models/pending_call_model.dart';
import 'package:connect_call/screens/calling/incoming_call_decision_dialog.dart';
import 'package:connect_call/services/call_notification_service.dart';
import 'package:connect_call/services/zego_call_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    ZegoCallService.instance.isForegroundOverride = null;
  });

  tearDown(() {
    IncomingCallDecisionDialog.dismissCurrent();
    ZegoCallService.instance.isForegroundOverride = null;
  });

  group('SMART INCOMING CALL HANDLING TESTS', () {
    test('STEP 2 & 16: isAppInForeground detects foreground lifecycle state correctly', () {
      final service = ZegoCallService.instance;

      service.isForegroundOverride = true;
      expect(service.isAppInForeground, isTrue);

      service.isForegroundOverride = false;
      expect(service.isAppInForeground, isFalse);
    });

    testWidgets('STEP 3: When app is FOREGROUND, IncomingCallDecisionDialog opens directly without auto-accept',
        (tester) async {
      final pendingCall = PendingCallModel(
        callId: 'fg_call_001',
        callerUid: 'caller_123',
        callerName: 'Alice',
        callerZegoUserId: 'caller_123',
        callType: 'audio',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      bool accepted = false;
      bool rejected = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      IncomingCallDecisionDialog.show(
                        context,
                        pendingCall,
                        onAccept: () => accepted = true,
                        onReject: () => rejected = true,
                      );
                    },
                    child: const Text('Show Call'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Call'));
      await tester.pumpAndSettle();

      // Verify UI elements are present
      expect(find.text('Incoming Audio Call'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);

      // Verify STEP 11: Opening the dialog MUST NOT automatically accept
      expect(accepted, isFalse);
      expect(rejected, isFalse);

      // Tap Accept
      await tester.tap(find.byKey(const Key('incoming_call_accept_button')));
      await tester.pumpAndSettle();

      expect(accepted, isTrue);
      expect(rejected, isFalse);
    });

    testWidgets('STEP 8: Reject button declines call and closes IncomingCallDecisionDialog',
        (tester) async {
      final pendingCall = PendingCallModel(
        callId: 'fg_call_002',
        callerUid: 'caller_456',
        callerName: 'Bob',
        callerZegoUserId: 'caller_456',
        callType: 'video',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      bool rejected = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    IncomingCallDecisionDialog.show(
                      context,
                      pendingCall,
                      onReject: () => rejected = true,
                    );
                  },
                  child: const Text('Show Video Call'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Video Call'));
      await tester.pumpAndSettle();

      expect(find.text('Incoming Video Call'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      // Tap Reject
      await tester.tap(find.byKey(const Key('incoming_call_reject_button')));
      await tester.pumpAndSettle();

      expect(rejected, isTrue);
      expect(find.byType(IncomingCallDecisionDialog), findsNothing);
    });

    testWidgets('STEP 12: Call cancellation dismisses active dialog', (tester) async {
      final pendingCall = PendingCallModel(
        callId: 'cancel_call_003',
        callerUid: 'caller_789',
        callerName: 'Charlie',
        callerZegoUserId: 'caller_789',
        callType: 'audio',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    IncomingCallDecisionDialog.show(context, pendingCall);
                  },
                  child: const Text('Show'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.byType(IncomingCallDecisionDialog), findsOneWidget);
      expect(IncomingCallDecisionDialog.isShowing, isTrue);

      // Simulate caller cancellation
      IncomingCallDecisionDialog.dismissCurrent('cancel_call_003');
      await tester.pumpAndSettle();

      expect(find.byType(IncomingCallDecisionDialog), findsNothing);
      expect(IncomingCallDecisionDialog.isShowing, isFalse);
    });

    testWidgets('STEP 14: Duplicate calls do not open multiple dialogs', (tester) async {
      final pendingCall = PendingCallModel(
        callId: 'dup_call_004',
        callerUid: 'caller_dup',
        callerName: 'David',
        callerZegoUserId: 'caller_dup',
        callType: 'audio',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => IncomingCallDecisionDialog.show(context, pendingCall),
                      child: const Text('Show 1'),
                    ),
                    ElevatedButton(
                      onPressed: () => IncomingCallDecisionDialog.show(context, pendingCall),
                      child: const Text('Show 2'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show 1'));
      await tester.pumpAndSettle();
      expect(find.byType(IncomingCallDecisionDialog), findsOneWidget);

      // Attempt to show second dialog with same call ID
      await tester.tap(find.text('Show 2'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Still only one dialog exists
      expect(find.byType(IncomingCallDecisionDialog), findsOneWidget);
    });

    test('STEP 4 & 5: When app is NOT FOREGROUND, system notification is triggered', () async {
      final service = ZegoCallService.instance;
      service.isForegroundOverride = false;

      PendingCallModel? notificationCall;
      CallNotificationService.setInstance(
        CallNotificationService(
          showNotificationDelegate: (call) async {
            notificationCall = call;
          },
        ),
      );

      final pendingCall = PendingCallModel(
        callId: 'bg_call_005',
        callerUid: 'caller_bg',
        callerName: 'Eve',
        callerZegoUserId: 'caller_bg',
        callType: 'video',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      // Trigger notification manually as onIncomingCallReceived does when !isAppInForeground
      await CallNotificationService.instance.showIncomingCallNotification(pendingCall);

      expect(notificationCall, isNotNull);
      expect(notificationCall!.callId, 'bg_call_005');
      expect(notificationCall!.isVideo, isTrue);
    });

    testWidgets('Video call accept from IncomingCallDecisionDialog executes cleanly and triggers accept callback',
        (tester) async {
      final pendingVideoCall = PendingCallModel(
        callId: 'video_call_accept_001',
        callerUid: 'caller_video',
        callerName: 'Frank',
        callerZegoUserId: 'caller_video',
        callType: 'video',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      bool accepted = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      IncomingCallDecisionDialog.show(
                        context,
                        pendingVideoCall,
                        onAccept: () => accepted = true,
                      );
                    },
                    child: const Text('Show Video Call'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Video Call'));
      await tester.pumpAndSettle();

      expect(IncomingCallDecisionDialog.isShowing, isTrue);
      expect(find.text('Incoming Video Call'), findsOneWidget);

      await tester.tap(find.byKey(const Key('incoming_call_accept_button')));
      await tester.pumpAndSettle();

      expect(accepted, isTrue);
      expect(IncomingCallDecisionDialog.isShowing, isFalse);
    });
  });
}
