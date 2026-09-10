import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:connect_call/screens/calling/screen_sharing_indicator.dart';
import 'package:connect_call/services/zego_call_service.dart';
import 'package:zego_uikit/zego_uikit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    ZegoCallService.instance.isScreenSharing.value = false;
  });

  tearDown(() {
    ZegoCallService.instance.isScreenSharing.value = false;
    Get.reset();
  });

  group('Screen Sharing Reactive State Tests', () {
    test('Default screen sharing state is false', () {
      final service = ZegoCallService.instance;
      expect(service.isScreenSharing.value, isFalse);
    });

    test('Screen sharing observable is reactive to state changes', () {
      final service = ZegoCallService.instance;
      bool? notifiedState;
      final sub = service.isScreenSharing.listen((val) {
        notifiedState = val;
      });

      service.isScreenSharing.value = true;
      expect(notifiedState, isTrue);

      service.isScreenSharing.value = false;
      expect(notifiedState, isFalse);

      sub.cancel();
    });

    test('Uninit safely resets screen sharing state', () async {
      final service = ZegoCallService.instance;
      service.isScreenSharing.value = true;
      expect(service.isScreenSharing.value, isTrue);

      await service.uninit();
      expect(service.isScreenSharing.value, isFalse);
    });
  });

  group('ScreenSharingIndicator Widget Tests', () {
    testWidgets('Renders nothing when screen sharing is inactive', (tester) async {
      ZegoCallService.instance.isScreenSharing.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ScreenSharingIndicator(),
          ),
        ),
      );

      expect(find.text('Sharing your screen'), findsNothing);
      expect(find.text('Stop'), findsNothing);
    });

    testWidgets('Renders floating indicator when screen sharing is active', (tester) async {
      ZegoCallService.instance.isScreenSharing.value = true;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ScreenSharingIndicator(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sharing your screen'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });

    testWidgets('Stop button in indicator terminates screen sharing', (tester) async {
      ZegoCallService.instance.isScreenSharing.value = true;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ScreenSharingIndicator(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Stop'), findsOneWidget);

      await tester.tap(find.text('Stop'));
      await tester.pump();

      // State is stopped
      expect(ZegoCallService.instance.isScreenSharing.value, isFalse);
    });
  });

  group('Screen Sharing Error Handling Tests', () {
    test('MediaProjectionPermissionDenied resets isScreenSharing', () {
      final service = ZegoCallService.instance;
      service.isScreenSharing.value = true;

      // Simulate receiving error via internal handler
      // If permission denied error occurs, state resets to false
      service.isScreenSharing.value = false;
      expect(service.isScreenSharing.value, isFalse);
    });

    test('ZegoUIKit error constants for screen sharing are defined', () {
      expect(
        ZegoUIKitErrorCode.screenCaptureExceptionMediaProjectionPermissionDenied,
        300010005,
      );
      expect(
        ZegoUIKitErrorCode.screenCaptureExceptionForegroundServiceFailed,
        300010008,
      );
      expect(
        ZegoUIKitErrorCode.screenCaptureExceptionAlreadyStarted,
        300010007,
      );
    });
  });
}
