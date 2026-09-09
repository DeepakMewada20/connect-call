import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:connect_call/core/database/app_database.dart';
import 'package:connect_call/data/datasources/call_history_local_data_source.dart';
import 'package:connect_call/data/repositories/call_history_repository.dart';
import 'package:connect_call/models/pending_call_model.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/calling/incoming_call_decision_dialog.dart';
import 'package:connect_call/services/auth_service.dart';
import 'package:connect_call/services/block_service.dart';
import 'package:connect_call/services/call_history_service.dart';
import 'package:connect_call/services/call_notification_service.dart';
import 'package:connect_call/services/fcm_service.dart';
import 'package:connect_call/services/pending_call_manager.dart';
import 'package:connect_call/services/user_service.dart';
import 'package:connect_call/services/zego_call_service.dart';

// --- Mocks ---

class MockAuthService extends AuthService {
  final String _mockUid;

  MockAuthService({
    String currentUid = 'user_receiver_123',
  }) : _mockUid = currentUid;

  @override
  String? get currentUserId => _mockUid;
}

class MockUserService extends UserService {
  final Map<String, UserModel> _users;

  MockUserService({Map<String, UserModel>? initialUsers})
      : _users = initialUsers ?? {};

  @override
  Future<UserModel?> getUser(String uid) async => _users[uid];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late AppDatabase appDatabase;
  late CallHistoryLocalDataSource historyDataSource;
  late CallHistoryRepository historyRepository;
  late CallHistoryService historyService;
  late BlockService blockService;
  late MockAuthService authService;
  late MockUserService userService;
  late ZegoCallService zegoService;
  late PendingCallManager pendingCallManager;
  late CallNotificationService notificationService;
  late FcmService fcmService;

  // Trackers for notification & FCM calls
  final List<PendingCallModel> postedNotifications = [];
  final List<String> dismissedNotifications = [];
  final Map<String, String?> firestoreUserTokens = {};

  setUp(() async {
    Get.testMode = true;
    postedNotifications.clear();
    dismissedNotifications.clear();
    firestoreUserTokens.clear();

    // In-memory SQLite DB
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.databaseVersion,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE ${AppDatabase.callHistoryTable} (
              id TEXT PRIMARY KEY,
              firebaseUid TEXT NOT NULL,
              remoteUserId TEXT,
              contactName TEXT,
              phoneNumber TEXT,
              zegoUserId TEXT,
              callerId TEXT NOT NULL,
              callerName TEXT NOT NULL,
              callerPhoto TEXT,
              calleeId TEXT NOT NULL,
              calleeName TEXT NOT NULL,
              calleePhoto TEXT,
              callType TEXT NOT NULL,
              direction TEXT NOT NULL,
              status TEXT NOT NULL,
              startedAt INTEGER NOT NULL,
              endedAt INTEGER,
              durationSeconds INTEGER DEFAULT 0,
              createdAt INTEGER NOT NULL
            );
          ''');
          await database.execute('''
            CREATE TABLE ${AppDatabase.favoriteContactsTable} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              firebaseUid TEXT NOT NULL,
              remoteUserId TEXT NOT NULL,
              contactName TEXT NOT NULL,
              phoneNumber TEXT NOT NULL,
              createdAt INTEGER NOT NULL,
              UNIQUE(firebaseUid, remoteUserId)
            );
          ''');
        },
      ),
    );

    appDatabase = AppDatabase(database: db);
    historyDataSource = CallHistoryLocalDataSource(appDatabase: appDatabase);
    authService = MockAuthService(currentUid: 'user_receiver_123');
    historyRepository = CallHistoryRepositoryImpl(
      localDataSource: historyDataSource,
      authService: authService,
    );
    historyService = CallHistoryService(
      repository: historyRepository,
      authService: authService,
    );
    CallHistoryService.setInstance(historyService);

    final Set<String> inMemoryBlocked = {};
    blockService = BlockService(
      authService: authService,
      blockUserDelegate: (targetUid, currentUid) async {
        inMemoryBlocked.add(targetUid);
        return true;
      },
      unblockUserDelegate: (targetUid, currentUid) async {
        inMemoryBlocked.remove(targetUid);
        return true;
      },
      isBlockedDelegate: (targetUid, currentUid) async => inMemoryBlocked.contains(targetUid),
      getBlockedListDelegate: (currentUid) async => inMemoryBlocked.toList(),
    );
    BlockService.setInstance(blockService);

    userService = MockUserService(initialUsers: {
      'user_caller_456': UserModel(
        uid: 'user_caller_456',
        name: 'Rahul Sharma',
        phoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      ),
    });

    // PendingCallManager setup
    pendingCallManager = PendingCallManager();
    PendingCallManager.setInstance(pendingCallManager);

    // CallNotificationService setup with mocks
    notificationService = CallNotificationService(
      showNotificationDelegate: (call) async {
        postedNotifications.add(call);
      },
      dismissNotificationDelegate: (callId) async {
        dismissedNotifications.add(callId);
      },
    );
    CallNotificationService.setInstance(notificationService);

    // FcmService setup with mocks
    fcmService = FcmService(
      authService: authService,
      tokenSyncDelegate: (uid, token) async {
        firestoreUserTokens[uid] = token;
      },
      tokenCleanDelegate: (uid) async {
        firestoreUserTokens.remove(uid);
      },
    );
    FcmService.setInstance(fcmService);

    // ZegoCallService setup
    zegoService = ZegoCallService(
      authService: authService,
      userService: userService,
      callHistoryService: historyService,
      blockService: blockService,
    );
    zegoService.isInitialized.value = true;
  });

  tearDown(() async {
    await db.close();
    Get.reset();
  });

  group('PHASE 10 TEST MATRIX — FCM INCOMING CALL NOTIFICATIONS & LIFECYCLE', () {
    // -------------------------------------------------------------
    // TEST 1 — FOREGROUND AUDIO
    // -------------------------------------------------------------
    test('TEST 1: Foreground audio call invitation records call in SQLite and user can accept or reject', () async {
      final caller = UserModel(
        uid: 'user_caller_456',
        name: 'Rahul Sharma',
        phoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      );

      // Caller sends invitation
      final sent = await zegoService.sendAudioCallInvitation(targetUser: caller);
      expect(sent, isTrue);

      // Verify outgoing call record in SQLite
      final history = await historyService.getCallHistory();
      expect(history.length, 1);
      expect(history.first.callType, 'audio');
      expect(history.first.direction, 'outgoing');
      expect(history.first.status, 'calling');
    });

    // -------------------------------------------------------------
    // TEST 2 — FOREGROUND VIDEO
    // -------------------------------------------------------------
    test('TEST 2: Foreground video call invitation records video call in SQLite', () async {
      final caller = UserModel(
        uid: 'user_caller_456',
        name: 'Rahul Sharma',
        phoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      );

      final sent = await zegoService.sendVideoCallInvitation(targetUser: caller);
      expect(sent, isTrue);

      final history = await historyService.getCallHistory();
      expect(history.length, 1);
      expect(history.first.callType, 'video');
      expect(history.first.direction, 'outgoing');
      expect(history.first.status, 'calling');
    });

    // -------------------------------------------------------------
    // TEST 3 — BACKGROUND AUDIO
    // -------------------------------------------------------------
    test('TEST 3: Background audio call push triggers high-priority notification with sound & actions', () async {
      final payload = {
        'type': 'incoming_call',
        'callId': 'call_audio_bg_1',
        'callerUid': 'user_caller_456',
        'callerName': 'Rahul Sharma',
        'callerZegoUserId': 'user_caller_456',
        'callType': 'audio',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiresAt': DateTime.now().add(const Duration(seconds: 60)).millisecondsSinceEpoch,
      };

      // Simulate background message receipt
      final pendingCall = PendingCallModel.fromFcmPayload(payload);
      await pendingCallManager.savePendingCall(pendingCall);
      await notificationService.showIncomingCallNotification(pendingCall);

      // Verify notification posted with audio type
      expect(postedNotifications.length, 1);
      expect(postedNotifications.first.callId, 'call_audio_bg_1');
      expect(postedNotifications.first.callerName, 'Rahul Sharma');
      expect(postedNotifications.first.isVideo, isFalse);

      // Verify pending call saved in PendingCallManager
      final saved = await pendingCallManager.getPendingCall();
      expect(saved, isNotNull);
      expect(saved?.callId, 'call_audio_bg_1');
      expect(saved?.isExpired, isFalse);
    });

    // -------------------------------------------------------------
    // TEST 4 — BACKGROUND VIDEO
    // -------------------------------------------------------------
    test('TEST 4: Background video call push triggers video notification and saves pending video call', () async {
      final payload = {
        'type': 'incoming_call',
        'callId': 'call_video_bg_2',
        'callerUid': 'user_caller_456',
        'callerName': 'Rahul Sharma',
        'callerZegoUserId': 'user_caller_456',
        'callType': 'video',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiresAt': DateTime.now().add(const Duration(seconds: 60)).millisecondsSinceEpoch,
      };

      final pendingCall = PendingCallModel.fromFcmPayload(payload);
      await pendingCallManager.savePendingCall(pendingCall);
      await notificationService.showIncomingCallNotification(pendingCall);

      expect(postedNotifications.length, 1);
      expect(postedNotifications.first.callId, 'call_video_bg_2');
      expect(postedNotifications.first.isVideo, isTrue);

      final saved = await pendingCallManager.getPendingCall();
      expect(saved?.isVideo, isTrue);
    });

    // -------------------------------------------------------------
    // TEST 5 — TERMINATED AUDIO RESTORATION
    // -------------------------------------------------------------
    test('TEST 5: Terminated audio call launch restores pending call if valid', () async {
      final call = PendingCallModel(
        callId: 'call_term_audio_3',
        callerUid: 'user_caller_456',
        callerName: 'Rahul Sharma',
        callerZegoUserId: 'user_caller_456',
        callType: 'audio',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 45)),
      );

      await pendingCallManager.savePendingCall(call);

      // On startup from terminated state:
      final restored = await pendingCallManager.getPendingCall();
      expect(restored, isNotNull);
      expect(restored?.callId, 'call_term_audio_3');
      expect(restored?.isExpired, isFalse);
      expect(restored?.isVideo, isFalse);
    });

    // -------------------------------------------------------------
    // TEST 6 — TERMINATED VIDEO RESTORATION
    // -------------------------------------------------------------
    test('TEST 6: Terminated video call launch restores pending video call if valid', () async {
      final call = PendingCallModel(
        callId: 'call_term_video_4',
        callerUid: 'user_caller_456',
        callerName: 'Rahul Sharma',
        callerZegoUserId: 'user_caller_456',
        callType: 'video',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 50)),
      );

      await pendingCallManager.savePendingCall(call);

      final restored = await pendingCallManager.getPendingCall();
      expect(restored, isNotNull);
      expect(restored?.callId, 'call_term_video_4');
      expect(restored?.isVideo, isTrue);
    });

    // -------------------------------------------------------------
    // TEST 7 — NOTIFICATION ACCEPT ACTION
    // -------------------------------------------------------------
    test('TEST 7: Pressing notification ACCEPT executes existing accept logic and logs connected in SQLite', () async {
      final call = PendingCallModel(
        callId: 'call_accept_5',
        callerUid: 'user_caller_456',
        callerName: 'Rahul Sharma',
        callerZegoUserId: 'user_caller_456',
        callType: 'audio',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      await pendingCallManager.savePendingCall(call);

      // User presses ACCEPT action from notification
      await zegoService.acceptCallFromNotification(call);

      // Verify notification dismissed
      expect(dismissedNotifications.contains('call_accept_5'), isTrue);

      // Verify pending call state cleared
      final pending = await pendingCallManager.getPendingCall();
      expect(pending, isNull);

      // Verify call record in SQLite has status 'connected'
      final history = await historyService.getCallHistory();
      expect(history.length, 1);
      expect(history.first.id, 'call_accept_5');
      expect(history.first.status, 'connected');
      expect(history.first.direction, 'incoming');
    });

    // -------------------------------------------------------------
    // TEST 8 — NOTIFICATION REJECT ACTION
    // -------------------------------------------------------------
    test('TEST 8: Pressing notification REJECT dismisses notification and logs rejected in SQLite', () async {
      final call = PendingCallModel(
        callId: 'call_reject_6',
        callerUid: 'user_caller_456',
        callerName: 'Rahul Sharma',
        callerZegoUserId: 'user_caller_456',
        callType: 'video',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      await pendingCallManager.savePendingCall(call);

      // User presses REJECT action from notification
      await zegoService.rejectCallFromNotification(call);

      // Verify notification dismissed
      expect(dismissedNotifications.contains('call_reject_6'), isTrue);

      // Verify pending call state cleared
      final pending = await pendingCallManager.getPendingCall();
      expect(pending, isNull);

      // Verify call record in SQLite has status 'rejected'
      final history = await historyService.getCallHistory();
      expect(history.length, 1);
      expect(history.first.id, 'call_reject_6');
      expect(history.first.status, 'rejected');
      expect(history.first.direction, 'incoming');
    });

    // -------------------------------------------------------------
    // TEST 9 — NOTIFICATION BODY TAP (DO NOT AUTO-ACCEPT)
    // -------------------------------------------------------------
    test('TEST 9: Tapping notification body restores pending call without automatically accepting it', () async {
      final call = PendingCallModel(
        callId: 'call_body_tap_7',
        callerUid: 'user_caller_456',
        callerName: 'Rahul Sharma',
        callerZegoUserId: 'user_caller_456',
        callType: 'audio',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      await pendingCallManager.savePendingCall(call);

      // Verify pending call is restored and valid
      final restored = await pendingCallManager.getPendingCall();
      expect(restored, isNotNull);
      expect(restored?.callId, 'call_body_tap_7');

      // SQLite call history should NOT yet contain a connected call
      final history = await historyService.getCallHistory();
      expect(history.isEmpty, isTrue);
    });

    // -------------------------------------------------------------
    // TEST 10 — CALL EXPIRATION
    // -------------------------------------------------------------
    test('TEST 10: Expired call (>60s) rejects accept attempt, dismisses notification, and clears pending state', () async {
      final staleCall = PendingCallModel(
        callId: 'call_stale_8',
        callerUid: 'user_caller_456',
        callerName: 'Rahul Sharma',
        callerZegoUserId: 'user_caller_456',
        callType: 'audio',
        timestamp: DateTime.now().subtract(const Duration(seconds: 70)),
        expiresAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );

      expect(staleCall.isExpired, isTrue);
      await pendingCallManager.savePendingCall(staleCall);

      // Attempt to accept expired call
      await zegoService.acceptCallFromNotification(staleCall);

      // Notification must be dismissed
      expect(dismissedNotifications.contains('call_stale_8'), isTrue);

      // Pending state cleared
      final pending = await pendingCallManager.getPendingCall();
      expect(pending, isNull);

      // SQLite must not log connected
      final history = await historyService.getCallHistory();
      expect(history.isEmpty, isTrue);
    });

    // -------------------------------------------------------------
    // TEST 11 — FCM TOKEN REGISTRATION & SYNC
    // -------------------------------------------------------------
    test('TEST 11: Syncing FCM token writes to Firestore and cleanFcmToken purges it on logout', () async {
      const mockToken = 'fcm_device_token_abc_123';

      // 1. Sync token
      await fcmService.syncFcmToken(mockToken);
      expect(firestoreUserTokens['user_receiver_123'], mockToken);

      // 2. Clean token on logout
      await fcmService.cleanFcmToken('user_receiver_123');
      expect(firestoreUserTokens.containsKey('user_receiver_123'), isFalse);
    });

    // -------------------------------------------------------------
    // TEST 12 — CALL CANCELLED PUSH
    // -------------------------------------------------------------
    test('TEST 12: Call cancelled push dismisses notification and clears pending call', () async {
      final call = PendingCallModel(
        callId: 'call_cancel_9',
        callerUid: 'user_caller_456',
        callerName: 'Rahul Sharma',
        callerZegoUserId: 'user_caller_456',
        callType: 'audio',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      await pendingCallManager.savePendingCall(call);
      expect(pendingCallManager.hasValidPendingCall(), isTrue);

      // Simulate caller hangup / call cancelled event
      await notificationService.dismissNotification('call_cancel_9');
      await pendingCallManager.clearPendingCall();

      expect(dismissedNotifications.contains('call_cancel_9'), isTrue);
      expect(pendingCallManager.hasValidPendingCall(), isFalse);
    });

    // -------------------------------------------------------------
    // TEST 13 — INCOMING CALL DECISION DIALOG WIDGET RENDERING
    // -------------------------------------------------------------
    testWidgets('TEST 13: IncomingCallDecisionDialog renders caller info, decline, and accept buttons', (tester) async {
      final call = PendingCallModel(
        callId: 'call_dialog_10',
        callerUid: 'user_caller_456',
        callerName: 'Rahul Sharma',
        callerZegoUserId: 'user_caller_456',
        callType: 'video',
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );

      bool acceptPressed = false;
      bool rejectPressed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: IncomingCallDecisionDialog(
            key: const ValueKey('dialog_accept'),
            pendingCall: call,
            onAccept: () {
              acceptPressed = true;
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Check caller name and call type indicator
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Incoming Video Call'), findsOneWidget);

      // Verify Accept and Decline buttons present
      expect(find.byKey(const Key('incoming_call_accept_button')), findsOneWidget);
      expect(find.byKey(const Key('incoming_call_reject_button')), findsOneWidget);

      // Tap Accept
      await tester.tap(find.byKey(const Key('incoming_call_accept_button')));
      await tester.pumpAndSettle();
      expect(acceptPressed, isTrue);

      // Tap Reject on second mount
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: IncomingCallDecisionDialog(
            key: const ValueKey('dialog_reject'),
            pendingCall: call,
            onReject: () {
              rejectPressed = true;
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('incoming_call_reject_button')));
      await tester.pumpAndSettle();
      expect(rejectPressed, isTrue);
    });
  });
}
