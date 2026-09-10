import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connect_call/models/pending_call_model.dart';
import 'package:connect_call/services/call_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallNotificationService Configuration & Action Button Tests', () {
    test('Channel ID is updated to v2 and uses call ringtone sound and notificationRingtone usage', () {
      expect(CallNotificationService.channelId, 'incoming_calls_v2');
      expect(CallNotificationService.oldChannelId, 'incoming_calls');
      expect(CallNotificationService.channelName, 'Incoming Calls');

      // Verify ringtone sound resource
      expect(CallNotificationService.callRingtoneSound, isA<RawResourceAndroidNotificationSound>());
      final sound = CallNotificationService.callRingtoneSound as RawResourceAndroidNotificationSound;
      expect(sound.sound, 'call_ringtone');

      // Verify custom call vibration pattern
      expect(CallNotificationService.callVibrationPattern.length, 6);
      expect(CallNotificationService.callVibrationPattern[0], 0);
      expect(CallNotificationService.callVibrationPattern[1], 1000);
    });

    test('Action constants match expected IDs for background routing', () {
      expect(CallNotificationService.actionAccept, 'action_accept');
      expect(CallNotificationService.actionReject, 'action_reject');
    });

    test('showIncomingCallNotification delegates properly when delegate injected', () async {
      PendingCallModel? receivedCall;
      final service = CallNotificationService(
        showNotificationDelegate: (call) async {
          receivedCall = call;
        },
      );

      final call = PendingCallModel(
        callId: 'call_test_ringtone_1',
        callerUid: 'caller_123',
        callerName: 'Priya Sharma',
        callerZegoUserId: 'caller_123',
        callType: 'audio',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      await service.showIncomingCallNotification(call);
      expect(receivedCall, isNotNull);
      expect(receivedCall?.callId, 'call_test_ringtone_1');
      expect(receivedCall?.callerName, 'Priya Sharma');
    });

    test('dismissNotification delegates properly when delegate injected', () async {
      String? dismissedId;
      final service = CallNotificationService(
        dismissNotificationDelegate: (callId) async {
          dismissedId = callId;
        },
      );

      await service.dismissNotification('call_test_ringtone_1');
      expect(dismissedId, 'call_test_ringtone_1');
    });
  });
}
