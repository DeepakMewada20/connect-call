import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/models/zego_token_response.dart';
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
  });
}
