import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:zego_express_engine/zego_express_engine.dart';

import 'package:connect_call/screens/calling/custom_audio_calling_view.dart';
import 'package:connect_call/services/network_quality_service.dart';
import 'package:connect_call/widgets/network_quality_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        return ['wifi'];
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_logs_yoer'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  setUp(() {
    Get.testMode = true;
    NetworkQualityService.instance.stopMonitoring();
  });

  tearDown(() {
    NetworkQualityService.instance.stopMonitoring();
  });

  group('NetworkQualityService Unit Tests', () {
    test('mapQualityLevel correctly normalizes ZegoStreamQualityLevel', () {
      expect(
        NetworkQualityService.mapQualityLevel(ZegoStreamQualityLevel.Excellent),
        equals(NetworkQualityLevel.good),
      );
      expect(
        NetworkQualityService.mapQualityLevel(ZegoStreamQualityLevel.Good),
        equals(NetworkQualityLevel.good),
      );
      expect(
        NetworkQualityService.mapQualityLevel(ZegoStreamQualityLevel.Medium),
        equals(NetworkQualityLevel.fair),
      );
      expect(
        NetworkQualityService.mapQualityLevel(ZegoStreamQualityLevel.Bad),
        equals(NetworkQualityLevel.poor),
      );
      expect(
        NetworkQualityService.mapQualityLevel(ZegoStreamQualityLevel.Die),
        equals(NetworkQualityLevel.poor),
      );
      expect(
        NetworkQualityService.mapQualityLevel(ZegoStreamQualityLevel.Unknown),
        isNull,
      );
    });

    test('combineQuality takes degraded link into account', () {
      // Both good
      expect(
        NetworkQualityService.combineQuality(
          ZegoStreamQualityLevel.Excellent,
          ZegoStreamQualityLevel.Good,
        ),
        equals(NetworkQualityLevel.good),
      );

      // One fair, one good -> fair
      expect(
        NetworkQualityService.combineQuality(
          ZegoStreamQualityLevel.Medium,
          ZegoStreamQualityLevel.Good,
        ),
        equals(NetworkQualityLevel.fair),
      );

      // One poor, one good -> poor
      expect(
        NetworkQualityService.combineQuality(
          ZegoStreamQualityLevel.Good,
          ZegoStreamQualityLevel.Bad,
        ),
        equals(NetworkQualityLevel.poor),
      );

      // One die, one medium -> poor
      expect(
        NetworkQualityService.combineQuality(
          ZegoStreamQualityLevel.Die,
          ZegoStreamQualityLevel.Medium,
        ),
        equals(NetworkQualityLevel.poor),
      );

      // Unknown combined with valid metric returns valid metric
      expect(
        NetworkQualityService.combineQuality(
          ZegoStreamQualityLevel.Unknown,
          ZegoStreamQualityLevel.Good,
        ),
        equals(NetworkQualityLevel.good),
      );

      // Both unknown -> null
      expect(
        NetworkQualityService.combineQuality(
          ZegoStreamQualityLevel.Unknown,
          ZegoStreamQualityLevel.Unknown,
        ),
        isNull,
      );
    });

    test('Lifecycle: startMonitoring and stopMonitoring manage state cleanly', () {
      final service = NetworkQualityService.instance;

      expect(service.isMonitoring.value, isFalse);
      expect(service.currentQuality.value, isNull);

      service.startMonitoring();
      expect(service.isMonitoring.value, isTrue);
      expect(service.currentQuality.value, isNull); // Initial neutral state

      service.stopMonitoring();
      expect(service.isMonitoring.value, isFalse);
      expect(service.currentQuality.value, isNull);
    });

    test('onNetworkQuality updates currentQuality reactively', () {
      final service = NetworkQualityService.instance;
      service.startMonitoring();

      // Simulate good network
      service.onNetworkQuality(
        '',
        ZegoStreamQualityLevel.Good,
        ZegoStreamQualityLevel.Good,
      );
      expect(service.currentQuality.value, equals(NetworkQualityLevel.good));

      // Degrades to fair
      service.onNetworkQuality(
        '',
        ZegoStreamQualityLevel.Good,
        ZegoStreamQualityLevel.Medium,
      );
      expect(service.currentQuality.value, equals(NetworkQualityLevel.fair));

      // Degrades to poor
      service.onNetworkQuality(
        '',
        ZegoStreamQualityLevel.Bad,
        ZegoStreamQualityLevel.Good,
      );
      expect(service.currentQuality.value, equals(NetworkQualityLevel.poor));

      // Recovers to good
      service.onNetworkQuality(
        '',
        ZegoStreamQualityLevel.Excellent,
        ZegoStreamQualityLevel.Good,
      );
      expect(service.currentQuality.value, equals(NetworkQualityLevel.good));
    });

    test('Callbacks ignored when not actively monitoring', () {
      final service = NetworkQualityService.instance;
      service.stopMonitoring();

      service.onNetworkQuality(
        '',
        ZegoStreamQualityLevel.Good,
        ZegoStreamQualityLevel.Good,
      );
      expect(service.currentQuality.value, isNull);
    });
  });

  group('NetworkQualityIndicator Widget Tests', () {
    testWidgets('Renders neutral connecting state initially', (tester) async {
      final service = NetworkQualityService.instance;
      service.startMonitoring();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkQualityIndicator(service: service),
          ),
        ),
      );

      expect(find.text('Checking...'), findsOneWidget);
      expect(find.text('Poor'), findsNothing);
      expect(find.text('Good'), findsNothing);
      expect(find.text('Fair'), findsNothing);
    });

    testWidgets('Renders Good state with green indicator and icon', (tester) async {
      final service = NetworkQualityService.instance;
      service.startMonitoring();
      service.updateQualityForTesting(NetworkQualityLevel.good);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkQualityIndicator(service: service),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Good'), findsOneWidget);
      expect(find.byIcon(Icons.signal_cellular_alt), findsOneWidget);
    });

    testWidgets('Renders Fair state with amber indicator and icon', (tester) async {
      final service = NetworkQualityService.instance;
      service.startMonitoring();
      service.updateQualityForTesting(NetworkQualityLevel.fair);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkQualityIndicator(service: service),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Fair'), findsOneWidget);
      expect(find.byIcon(Icons.signal_cellular_alt_2_bar), findsOneWidget);
    });

    testWidgets('Renders Poor state with red indicator and icon', (tester) async {
      final service = NetworkQualityService.instance;
      service.startMonitoring();
      service.updateQualityForTesting(NetworkQualityLevel.poor);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkQualityIndicator(service: service),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Poor'), findsOneWidget);
      expect(find.byIcon(Icons.signal_cellular_alt_1_bar), findsOneWidget);
    });

    testWidgets('Reacts to real-time transitions: Good -> Fair -> Poor -> Good', (tester) async {
      final service = NetworkQualityService.instance;
      service.startMonitoring();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkQualityIndicator(service: service),
          ),
        ),
      );

      // Transition to Good
      service.updateQualityForTesting(NetworkQualityLevel.good);
      await tester.pumpAndSettle();
      expect(find.text('Good'), findsOneWidget);

      // Transition to Fair
      service.updateQualityForTesting(NetworkQualityLevel.fair);
      await tester.pumpAndSettle();
      expect(find.text('Fair'), findsOneWidget);

      // Transition to Poor
      service.updateQualityForTesting(NetworkQualityLevel.poor);
      await tester.pumpAndSettle();
      expect(find.text('Poor'), findsOneWidget);

      // Recover to Good
      service.updateQualityForTesting(NetworkQualityLevel.good);
      await tester.pumpAndSettle();
      expect(find.text('Good'), findsOneWidget);
    });

    testWidgets('CustomAudioCallingView displays NetworkQualityIndicator in call header', (tester) async {
      final service = NetworkQualityService.instance;
      service.startMonitoring();
      service.updateQualityForTesting(NetworkQualityLevel.good);

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomAudioCallingView(
            isOutgoingRinging: false,
          ),
        ),
      );
      await tester.pump();

      // Verify NetworkQualityIndicator exists in CustomAudioCallingView
      expect(find.byType(NetworkQualityIndicator), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
    });
  });
}
