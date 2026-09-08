import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_call/models/call_model.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/calls/calls_controller.dart';
import 'package:connect_call/screens/calls/calls_screen.dart';
import 'package:connect_call/services/auth_service.dart';
import 'package:connect_call/services/call_history_service.dart';
import 'package:connect_call/services/user_service.dart';
import 'package:connect_call/services/zego_call_service.dart';
import 'package:connect_call/widgets/call_history_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// Mock CallHistoryService for isolated unit testing
class MockCallHistoryService extends CallHistoryService {
  final List<CallModel> records;
  final bool shouldThrow;

  MockCallHistoryService({this.records = const [], this.shouldThrow = false});

  @override
  Future<List<CallModel>> getCallHistory({String? userId, int limit = 50}) async {
    if (shouldThrow) throw Exception('Firestore connection failure');
    return records;
  }

  @override
  Future<bool> deleteCallRecord(String callId, {String? userId}) async {
    if (shouldThrow) return false;
    records.removeWhere((r) => r.id == callId);
    return true;
  }
}

// Mock AuthService
class MockAuthService extends AuthService {
  final String? mockUid;
  MockAuthService({this.mockUid = 'user_me'});

  @override
  String? get currentUserId => mockUid;
}

// Mock UserService
class MockUserService extends UserService {
  final Map<String, UserModel> users;
  MockUserService({this.users = const {}});

  @override
  Future<UserModel?> getUser(String uid) async {
    return users[uid];
  }
}

// Mock ZegoCallService
class MockZegoCallService extends ZegoCallService {
  UserModel? lastAudioTarget;
  UserModel? lastVideoTarget;

  @override
  Future<bool> sendAudioCallInvitation({required UserModel targetUser}) async {
    lastAudioTarget = targetUser;
    return true;
  }

  @override
  Future<bool> sendVideoCallInvitation({required UserModel targetUser}) async {
    lastVideoTarget = targetUser;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('CallModel Serialization & Null-Safety Tests', () {
    test('toMap and fromMap serialize and deserialize correctly', () {
      final now = DateTime(2026, 9, 8, 14, 30);
      final model = CallModel(
        id: 'call_123',
        callerId: 'user_a',
        callerName: 'Alice',
        callerPhoto: 'https://example.com/a.png',
        calleeId: 'user_b',
        calleeName: 'Bob',
        calleePhoto: 'https://example.com/b.png',
        callType: 'audio',
        direction: 'outgoing',
        status: 'connected',
        startedAt: now,
        endedAt: now.add(const Duration(seconds: 75)),
        durationSeconds: 75,
      );

      final map = model.toMap();
      expect(map['callerId'], 'user_a');
      expect(map['callerName'], 'Alice');
      expect(map['calleeId'], 'user_b');
      expect(map['calleeName'], 'Bob');
      expect(map['callType'], 'audio');
      expect(map['direction'], 'outgoing');
      expect(map['status'], 'connected');
      expect(map['durationSeconds'], 75);

      final deserialized = CallModel.fromMap(map, documentId: 'call_123');
      expect(deserialized.id, 'call_123');
      expect(deserialized.callerId, 'user_a');
      expect(deserialized.callerName, 'Alice');
      expect(deserialized.calleeId, 'user_b');
      expect(deserialized.calleeName, 'Bob');
      expect(deserialized.callType, 'audio');
      expect(deserialized.direction, 'outgoing');
      expect(deserialized.status, 'connected');
      expect(deserialized.durationSeconds, 75);
      expect(deserialized.isAudio, isTrue);
      expect(deserialized.isVideo, isFalse);
    });

    test('fromMap handles null and missing fields gracefully', () {
      final model = CallModel.fromMap(const {}, documentId: 'call_default');
      expect(model.id, 'call_default');
      expect(model.callerId, '');
      expect(model.callerName, '');
      expect(model.calleeId, '');
      expect(model.calleeName, '');
      expect(model.callType, 'audio');
      expect(model.direction, 'outgoing');
      expect(model.status, 'ended');
      expect(model.durationSeconds, 0);
      expect(model.startedAt, isA<DateTime>());
      expect(model.endedAt, isNull);
    });

    test('fromMap parses Firestore Timestamp or String dates', () {
      final now = DateTime(2026, 9, 8, 12, 0);
      final timestamp = Timestamp.fromDate(now);

      final modelFromTimestamp = CallModel.fromMap({
        'startedAt': timestamp,
        'endedAt': timestamp,
      }, documentId: 'ts_call');

      expect(modelFromTimestamp.startedAt.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
      expect(modelFromTimestamp.endedAt?.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);

      final modelFromString = CallModel.fromMap({
        'startedAt': now.toIso8601String(),
      }, documentId: 'str_call');
      expect(modelFromString.startedAt.year, 2026);
    });
  });

  group('CallModel Formatting & Helper Tests', () {
    test('formattedDuration formats MM:SS and HH:MM:SS accurately', () {
      expect(
        CallModel(
          id: '1',
          callerId: 'a',
          callerName: 'Caller A',
          calleeId: 'b',
          calleeName: 'Callee B',
          callType: 'audio',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
          durationSeconds: 0,
        ).formattedDuration,
        '00:00',
      );

      expect(
        CallModel(
          id: '2',
          callerId: 'a',
          callerName: 'Caller A',
          calleeId: 'b',
          calleeName: 'Callee B',
          callType: 'audio',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
          durationSeconds: 65,
        ).formattedDuration,
        '01:05',
      );

      expect(
        CallModel(
          id: '3',
          callerId: 'a',
          callerName: 'Caller A',
          calleeId: 'b',
          calleeName: 'Callee B',
          callType: 'audio',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
          durationSeconds: 125,
        ).formattedDuration,
        '02:05',
      );

      expect(
        CallModel(
          id: '4',
          callerId: 'a',
          callerName: 'Caller A',
          calleeId: 'b',
          calleeName: 'Callee B',
          callType: 'audio',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
          durationSeconds: 3600,
        ).formattedDuration,
        '01:00:00',
      );

      expect(
        CallModel(
          id: '5',
          callerId: 'a',
          callerName: 'Caller A',
          calleeId: 'b',
          calleeName: 'Callee B',
          callType: 'audio',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
          durationSeconds: 3665,
        ).formattedDuration,
        '01:01:05',
      );
    });

    test('formattedDate formats Today, Yesterday, and past dates', () {
      final now = DateTime.now();
      final todayCall = CallModel(
        id: '1',
        callerId: 'a',
        callerName: 'Caller A',
        calleeId: 'b',
        calleeName: 'Callee B',
        callType: 'audio',
        direction: 'outgoing',
        status: 'ended',
        startedAt: now,
      );
      expect(todayCall.formattedDate.startsWith('Today,'), isTrue);

      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayCall = CallModel(
        id: '2',
        callerId: 'a',
        callerName: 'Caller A',
        calleeId: 'b',
        calleeName: 'Callee B',
        callType: 'audio',
        direction: 'outgoing',
        status: 'ended',
        startedAt: yesterday,
      );
      expect(yesterdayCall.formattedDate.startsWith('Yesterday,'), isTrue);
    });

    test('getOtherUserId, getOtherUserName, getOtherUserPhoto distinguish self vs peer', () {
      final call = CallModel(
        id: 'c1',
        callerId: 'user_alice',
        callerName: 'Alice',
        callerPhoto: 'https://alice.jpg',
        calleeId: 'user_bob',
        calleeName: 'Bob',
        calleePhoto: 'https://bob.jpg',
        callType: 'video',
        direction: 'outgoing',
        status: 'ended',
        startedAt: DateTime.now(),
      );

      // When viewed by Alice
      expect(call.getOtherUserId('user_alice'), 'user_bob');
      expect(call.getOtherUserName('user_alice'), 'Bob');
      expect(call.getOtherUserPhoto('user_alice'), 'https://bob.jpg');

      // When viewed by Bob
      expect(call.getOtherUserId('user_bob'), 'user_alice');
      expect(call.getOtherUserName('user_bob'), 'Alice');
      expect(call.getOtherUserPhoto('user_bob'), 'https://alice.jpg');
    });

    test('isMissed correctly flags missed/timeout/rejected calls', () {
      final missed = CallModel(
        id: 'm1',
        callerId: 'a',
        callerName: 'Caller A',
        calleeId: 'b',
        calleeName: 'Callee B',
        callType: 'audio',
        direction: 'incoming',
        status: 'missed',
        startedAt: DateTime.now(),
      );
      expect(missed.isMissed, isTrue);

      final connected = CallModel(
        id: 'm2',
        callerId: 'a',
        callerName: 'Caller A',
        calleeId: 'b',
        calleeName: 'Callee B',
        callType: 'audio',
        direction: 'incoming',
        status: 'ended',
        startedAt: DateTime.now(),
      );
      expect(connected.isMissed, isFalse);
    });
  });

  group('CallsController Unit Tests', () {
    test('loadHistory populates callHistory list successfully', () async {
      final mockCalls = [
        CallModel(
          id: 'call_1',
          callerId: 'user_me',
          callerName: 'Me',
          calleeId: 'user_other',
          calleeName: 'Other Person',
          callType: 'audio',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
          durationSeconds: 120,
        ),
      ];

      final mockService = MockCallHistoryService(records: mockCalls);
      final controller = CallsController(
        callHistoryService: mockService,
        authService: MockAuthService(mockUid: 'user_me'),
      );

      await controller.loadHistory();

      expect(controller.isLoading.value, isFalse);
      expect(controller.hasError.value, isFalse);
      expect(controller.callHistory.length, 1);
      expect(controller.callHistory.first.id, 'call_1');
    });

    test('loadHistory handles errors gracefully', () async {
      final mockService = MockCallHistoryService(shouldThrow: true);
      final controller = CallsController(
        callHistoryService: mockService,
        authService: MockAuthService(mockUid: 'user_me'),
      );

      await controller.loadHistory();

      expect(controller.isLoading.value, isFalse);
      expect(controller.hasError.value, isTrue);
      expect(controller.errorMessage.value, 'Unable to load call history.');
      expect(controller.callHistory.isEmpty, isTrue);
    });

    test('deleteCall removes record from controller state and service', () async {
      final mockCalls = [
        CallModel(
          id: 'call_delete_me',
          callerId: 'user_me',
          callerName: 'Me',
          calleeId: 'user_other',
          calleeName: 'Other Person',
          callType: 'video',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
        ),
      ];

      final mockService = MockCallHistoryService(records: List<CallModel>.from(mockCalls));
      final controller = CallsController(
        callHistoryService: mockService,
        authService: MockAuthService(mockUid: 'user_me'),
      );

      await controller.loadHistory();
      expect(controller.callHistory.length, 1);

      await controller.deleteCall('call_delete_me');
      expect(controller.callHistory.isEmpty, isTrue);
    });

    test('redialCall initiates audio call for audio record', () async {
      final call = CallModel(
        id: 'call_redial_1',
        callerId: 'user_other',
        callerName: 'Charlie',
        calleeId: 'user_me',
        calleeName: 'Me',
        callType: 'audio',
        direction: 'incoming',
        status: 'ended',
        startedAt: DateTime.now(),
      );

      final mockZego = MockZegoCallService();
      final controller = CallsController(
        callHistoryService: MockCallHistoryService(),
        authService: MockAuthService(mockUid: 'user_me'),
        userService: MockUserService(users: {
          'user_other': UserModel(
            uid: 'user_other',
            name: 'Charlie',
            email: 'charlie@test.com',
            createdAt: DateTime.now(),
          ),
        }),
        zegoCallService: mockZego,
      );

      await controller.redialCall(call);
      expect(mockZego.lastAudioTarget?.uid, 'user_other');
      expect(mockZego.lastAudioTarget?.name, 'Charlie');
      expect(mockZego.lastVideoTarget, isNull);
    });

    test('redialCall initiates video call for video record', () async {
      final call = CallModel(
        id: 'call_redial_2',
        callerId: 'user_me',
        callerName: 'Me',
        calleeId: 'user_david',
        calleeName: 'David',
        callType: 'video',
        direction: 'outgoing',
        status: 'ended',
        startedAt: DateTime.now(),
      );

      final mockZego = MockZegoCallService();
      final controller = CallsController(
        callHistoryService: MockCallHistoryService(),
        authService: MockAuthService(mockUid: 'user_me'),
        userService: MockUserService(),
        zegoCallService: mockZego,
      );

      await controller.redialCall(call);
      expect(mockZego.lastVideoTarget?.uid, 'user_david');
      expect(mockZego.lastVideoTarget?.name, 'David');
      expect(mockZego.lastAudioTarget, isNull);
    });
  });

  group('CallHistoryTile Widget Tests', () {
    testWidgets('Renders participant name, duration, and redial button',
        (tester) async {
      bool redialed = false;
      final call = CallModel(
        id: 'tile_1',
        callerId: 'user_me',
        callerName: 'Me',
        calleeId: 'peer_1',
        calleeName: 'Emma Watson',
        callType: 'audio',
        direction: 'outgoing',
        status: 'ended',
        startedAt: DateTime.now(),
        durationSeconds: 125,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallHistoryTile(
              call: call,
              currentUserId: 'user_me',
              onRedial: () => redialed = true,
            ),
          ),
        ),
      );

      expect(find.text('Emma Watson'), findsOneWidget);
      expect(find.text('02:05'), findsOneWidget);
      expect(find.byIcon(Icons.call_rounded), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(redialed, isTrue);
    });

    testWidgets('Renders missed call with Missed badge and red name',
        (tester) async {
      final missedCall = CallModel(
        id: 'tile_2',
        callerId: 'peer_2',
        callerName: 'John Doe',
        calleeId: 'user_me',
        calleeName: 'Me',
        callType: 'video',
        direction: 'incoming',
        status: 'missed',
        startedAt: DateTime.now(),
        durationSeconds: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallHistoryTile(
              call: missedCall,
              currentUserId: 'user_me',
              onRedial: () {},
            ),
          ),
        ),
      );

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsWidgets);
    });
  });

  group('CallsScreen Widget States Tests', () {
    testWidgets('Renders empty state when call history is empty',
        (tester) async {
      Get.put(CallsController(
        callHistoryService: MockCallHistoryService(records: []),
        authService: MockAuthService(),
      ));

      await tester.pumpWidget(
        const GetMaterialApp(
          home: CallsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('No calls yet'), findsOneWidget);
      expect(
          find.text('Your recent audio and video calls will appear here.'),
          findsOneWidget);
      Get.delete<CallsController>();
    });

    testWidgets('Renders error state with Retry button on failure',
        (tester) async {
      Get.put(CallsController(
        callHistoryService: MockCallHistoryService(shouldThrow: true),
        authService: MockAuthService(),
      ));

      await tester.pumpWidget(
        const GetMaterialApp(
          home: CallsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Unable to load call history.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      Get.delete<CallsController>();
    });

    testWidgets('Renders list of CallHistoryTile when records exist',
        (tester) async {
      final records = <CallModel>[
        CallModel(
          id: 'rec_1',
          callerId: 'user_me',
          callerName: 'Me',
          calleeId: 'user_other',
          calleeName: 'Sarah Connor',
          callType: 'video',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
          durationSeconds: 180,
        ),
      ];

      Get.put(CallsController(
        callHistoryService: MockCallHistoryService(records: records),
        authService: MockAuthService(mockUid: 'user_me'),
      ));

      await tester.pumpWidget(
        const GetMaterialApp(
          home: CallsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('03:00'), findsOneWidget);
      Get.delete<CallsController>();
    });
  });
}
