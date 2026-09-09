import 'package:connect_call/core/database/app_database.dart';
import 'package:connect_call/data/datasources/call_history_local_data_source.dart';
import 'package:connect_call/data/repositories/call_history_repository.dart';
import 'package:connect_call/models/call_model.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/calls/calls_controller.dart';
import 'package:connect_call/services/auth_service.dart';
import 'package:connect_call/services/call_history_service.dart';
import 'package:connect_call/services/zego_call_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Mock AuthService for testing user scoping
class MockAuthServiceForHistory extends AuthService {
  String? currentUid;
  MockAuthServiceForHistory({this.currentUid = 'user_alice'});

  @override
  String? get currentUserId => currentUid;
}

// Mock ZegoCallService for tracking calls
class MockZegoServiceForHistory extends ZegoCallService {
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
  sqfliteFfiInit();

  late Database db;
  late AppDatabase appDatabase;
  late CallHistoryLocalDataSource localDataSource;
  late MockAuthServiceForHistory authService;
  late CallHistoryRepository repository;
  late CallHistoryService callHistoryService;

  setUp(() async {
    Get.testMode = true;
    // Create an in-memory SQLite database using sqflite_common_ffi
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
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
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_call_history_user_created 
            ON ${AppDatabase.callHistoryTable} (firebaseUid, createdAt DESC);
          ''');
        },
      ),
    );

    appDatabase = AppDatabase(database: db);
    localDataSource = CallHistoryLocalDataSource(appDatabase: appDatabase);
    authService = MockAuthServiceForHistory(currentUid: 'user_alice');
    repository = CallHistoryRepositoryImpl(
      localDataSource: localDataSource,
      authService: authService,
    );
    callHistoryService = CallHistoryService(
      repository: repository,
      authService: authService,
    );
    CallHistoryService.setInstance(callHistoryService);
  });

  tearDown(() async {
    await db.close();
    Get.reset();
  });

  group('Phase 3 SQLite Call History Tests (Step 27 Requirements)', () {
    // TEST 1: Outgoing audio call answered -> Call ends -> SQLite record created -> History screen shows it.
    test('TEST 1: Outgoing audio call answered records correctly in SQLite', () async {
      final now = DateTime.now();
      final call = CallModel(
        id: 'call_out_audio_1',
        firebaseUid: 'user_alice',
        callerId: 'user_alice',
        callerName: 'Alice',
        calleeId: 'user_bob',
        calleeName: 'Bob',
        callType: 'audio',
        direction: 'outgoing',
        status: 'calling',
        startedAt: now,
      );

      // Save on call start
      final saved = await callHistoryService.saveCallRecord(call);
      expect(saved, isTrue);

      // Update on call answer & completion
      final updated = await callHistoryService.updateCallStatus(
        callId: 'call_out_audio_1',
        status: 'ended',
        endedAt: now.add(const Duration(seconds: 125)),
        durationSeconds: 125,
      );
      expect(updated, isTrue);

      // Fetch history for Alice
      final history = await callHistoryService.getCallHistory();
      expect(history.length, 1);
      expect(history.first.id, 'call_out_audio_1');
      expect(history.first.status, 'ended');
      expect(history.first.durationSeconds, 125);
      expect(history.first.formattedDuration, '02:05');
      expect(history.first.isAudio, isTrue);
      expect(history.first.isOutgoing, isTrue);
    });

    // TEST 2: Outgoing video call answered -> SQLite record created -> Correct duration shown.
    test('TEST 2: Outgoing video call answered with accurate duration in SQLite', () async {
      final now = DateTime.now();
      final call = CallModel(
        id: 'call_out_video_1',
        firebaseUid: 'user_alice',
        callerId: 'user_alice',
        callerName: 'Alice',
        calleeId: 'user_charlie',
        calleeName: 'Charlie',
        callType: 'video',
        direction: 'outgoing',
        status: 'connected',
        startedAt: now,
        endedAt: now.add(const Duration(seconds: 245)),
        durationSeconds: 245,
      );

      await callHistoryService.saveCallRecord(call);

      final history = await callHistoryService.getCallHistory();
      expect(history.length, 1);
      expect(history.first.isVideo, isTrue);
      expect(history.first.durationSeconds, 245);
      expect(history.first.formattedDuration, '04:05');
    });

    // TEST 3: Incoming audio call answered -> SQLite record created -> Direction = incoming.
    test('TEST 3: Incoming audio call answered stored with incoming direction', () async {
      final now = DateTime.now();
      final call = CallModel(
        id: 'call_in_audio_1',
        firebaseUid: 'user_alice',
        callerId: 'user_bob',
        callerName: 'Bob',
        calleeId: 'user_alice',
        calleeName: 'Alice',
        callType: 'audio',
        direction: 'incoming',
        status: 'ended',
        startedAt: now,
        endedAt: now.add(const Duration(seconds: 45)),
        durationSeconds: 45,
      );

      await callHistoryService.saveCallRecord(call);

      final history = await callHistoryService.getCallHistory();
      expect(history.length, 1);
      expect(history.first.isIncoming, isTrue);
      expect(history.first.isAudio, isTrue);
      expect(history.first.durationSeconds, 45);
    });

    // TEST 4: Incoming video call not answered -> SQLite record created -> Status = missed.
    test('TEST 4: Incoming video call not answered stored as missed with 0 duration', () async {
      final now = DateTime.now();
      final call = CallModel(
        id: 'call_in_video_missed',
        firebaseUid: 'user_alice',
        callerId: 'user_david',
        callerName: 'David',
        calleeId: 'user_alice',
        calleeName: 'Alice',
        callType: 'video',
        direction: 'incoming',
        status: 'calling',
        startedAt: now,
      );

      await callHistoryService.saveCallRecord(call);

      // Missed timeout occurs
      await callHistoryService.updateCallStatus(
        callId: 'call_in_video_missed',
        status: 'missed',
        endedAt: DateTime.now(),
        durationSeconds: 0,
      );

      final history = await callHistoryService.getCallHistory();
      expect(history.length, 1);
      expect(history.first.isMissed, isTrue);
      expect(history.first.isVideo, isTrue);
      expect(history.first.durationSeconds, 0);
    });

    // TEST 5: Rejected incoming call -> Status = rejected.
    test('TEST 5: Rejected incoming call stored as rejected', () async {
      final now = DateTime.now();
      final call = CallModel(
        id: 'call_in_rejected',
        firebaseUid: 'user_alice',
        callerId: 'user_bob',
        callerName: 'Bob',
        calleeId: 'user_alice',
        calleeName: 'Alice',
        callType: 'audio',
        direction: 'incoming',
        status: 'rejected',
        startedAt: now,
        endedAt: now,
        durationSeconds: 0,
      );

      await callHistoryService.saveCallRecord(call);

      final history = await callHistoryService.getCallHistory();
      expect(history.length, 1);
      expect(history.first.isRejected, isTrue);
      expect(history.first.durationSeconds, 0);
    });

    // TEST 6: Failed call -> Status = failed.
    test('TEST 6: Failed call stored as failed', () async {
      final now = DateTime.now();
      final call = CallModel(
        id: 'call_failed_1',
        firebaseUid: 'user_alice',
        callerId: 'user_alice',
        callerName: 'Alice',
        calleeId: 'user_bob',
        calleeName: 'Bob',
        callType: 'audio',
        direction: 'outgoing',
        status: 'failed',
        startedAt: now,
        endedAt: now,
        durationSeconds: 0,
      );

      await callHistoryService.saveCallRecord(call);

      final history = await callHistoryService.getCallHistory();
      expect(history.length, 1);
      expect(history.first.isFailed, isTrue);
    });

    // TEST 7: App restarted -> Call history still exists (persistence across instances).
    test('TEST 7: Database persistence retains records across new repository instances', () async {
      final call = CallModel(
        id: 'call_persist_1',
        firebaseUid: 'user_alice',
        callerId: 'user_alice',
        callerName: 'Alice',
        calleeId: 'user_bob',
        calleeName: 'Bob',
        callType: 'video',
        direction: 'outgoing',
        status: 'ended',
        startedAt: DateTime.now(),
        durationSeconds: 60,
      );

      await callHistoryService.saveCallRecord(call);

      // Simulate app restart by creating fresh DataSource and Repository using the same database
      final freshDataSource = CallHistoryLocalDataSource(appDatabase: appDatabase);
      final freshRepo = CallHistoryRepositoryImpl(
        localDataSource: freshDataSource,
        authService: authService,
      );
      final freshHistoryService = CallHistoryService(
        repository: freshRepo,
        authService: authService,
      );

      final records = await freshHistoryService.getCallHistory();
      expect(records.length, 1);
      expect(records.first.id, 'call_persist_1');
      expect(records.first.durationSeconds, 60);
    });

    // TEST 8: Firestore unavailable -> New call history should still be saved locally.
    test('TEST 8: SQLite saves call records locally completely offline without Firestore', () async {
      // No Firebase app or Firestore instance is initialized; verify save succeeds
      final call = CallModel(
        id: 'call_offline_1',
        firebaseUid: 'user_alice',
        callerId: 'user_alice',
        callerName: 'Alice',
        calleeId: 'user_charlie',
        calleeName: 'Charlie',
        callType: 'audio',
        direction: 'outgoing',
        status: 'ended',
        startedAt: DateTime.now(),
        durationSeconds: 15,
      );

      final success = await callHistoryService.saveCallRecord(call);
      expect(success, isTrue);

      final list = await callHistoryService.getCallHistory();
      expect(list.length, 1);
      expect(list.first.id, 'call_offline_1');
    });

    // TEST 9: User logs out and another user logs in -> Previous user's history must not appear.
    test('TEST 9: Multi-user scoping isolates call history between users on same device', () async {
      // 1. Alice makes a call
      await callHistoryService.saveCallRecord(
        CallModel(
          id: 'call_alice_1',
          firebaseUid: 'user_alice',
          callerId: 'user_alice',
          callerName: 'Alice',
          calleeId: 'user_charlie',
          calleeName: 'Charlie',
          callType: 'audio',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
        ),
      );

      // 2. Bob logs in on the same device
      authService.currentUid = 'user_bob';

      // Verify Bob cannot see Alice's call
      final bobHistory = await callHistoryService.getCallHistory();
      expect(bobHistory, isEmpty);

      // 3. Bob makes a call
      await callHistoryService.saveCallRecord(
        CallModel(
          id: 'call_bob_1',
          firebaseUid: 'user_bob',
          callerId: 'user_bob',
          callerName: 'Bob',
          calleeId: 'user_david',
          calleeName: 'David',
          callType: 'video',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
        ),
      );

      final bobHistoryUpdated = await callHistoryService.getCallHistory();
      expect(bobHistoryUpdated.length, 1);
      expect(bobHistoryUpdated.first.id, 'call_bob_1');

      // 4. Switch back to Alice
      authService.currentUid = 'user_alice';
      final aliceHistory = await callHistoryService.getCallHistory();
      expect(aliceHistory.length, 1);
      expect(aliceHistory.first.id, 'call_alice_1');
    });

    // TEST 10: Delete one call -> SQLite record removed -> UI updates.
    test('TEST 10: Deleting a single call removes it from SQLite and controller', () async {
      await callHistoryService.saveCallRecord(
        CallModel(
          id: 'call_to_delete',
          firebaseUid: 'user_alice',
          callerId: 'user_alice',
          callerName: 'Alice',
          calleeId: 'user_bob',
          calleeName: 'Bob',
          callType: 'audio',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
        ),
      );

      await callHistoryService.saveCallRecord(
        CallModel(
          id: 'call_to_keep',
          firebaseUid: 'user_alice',
          callerId: 'user_alice',
          callerName: 'Alice',
          calleeId: 'user_charlie',
          calleeName: 'Charlie',
          callType: 'video',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
        ),
      );

      final controller = CallsController(
        callHistoryService: callHistoryService,
        authService: authService,
      );
      await controller.loadHistory();
      expect(controller.callHistory.length, 2);

      // Delete one call
      await controller.deleteCall('call_to_delete');
      expect(controller.callHistory.length, 1);
      expect(controller.callHistory.first.id, 'call_to_keep');

      // Verify directly from SQLite
      final fromDb = await callHistoryService.getCallHistory();
      expect(fromDb.length, 1);
      expect(fromDb.first.id, 'call_to_keep');
    });

    // TEST 11: Clear all -> Local call history removed.
    test('TEST 11: Clear all history deletes all records for current user', () async {
      await callHistoryService.saveCallRecord(
        CallModel(
          id: 'call_1',
          firebaseUid: 'user_alice',
          callerId: 'user_alice',
          callerName: 'Alice',
          calleeId: 'user_bob',
          calleeName: 'Bob',
          callType: 'audio',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
        ),
      );
      await callHistoryService.saveCallRecord(
        CallModel(
          id: 'call_2',
          firebaseUid: 'user_alice',
          callerId: 'user_alice',
          callerName: 'Alice',
          calleeId: 'user_charlie',
          calleeName: 'Charlie',
          callType: 'video',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now(),
        ),
      );

      final controller = CallsController(
        callHistoryService: callHistoryService,
        authService: authService,
      );
      await controller.loadHistory();
      expect(controller.callHistory.length, 2);

      await controller.clearAllHistory();
      expect(controller.callHistory, isEmpty);

      final fromDb = await callHistoryService.getCallHistory();
      expect(fromDb, isEmpty);
    });

    // TEST 12: Existing ZEGOCLOUD audio call -> Still works.
    test('TEST 12: Audio call redial from history delegates to ZegoCallService', () async {
      final mockZego = MockZegoServiceForHistory();
      final controller = CallsController(
        callHistoryService: callHistoryService,
        authService: authService,
        zegoCallService: mockZego,
      );

      final audioCall = CallModel(
        id: 'call_audio_test',
        firebaseUid: 'user_alice',
        callerId: 'user_alice',
        callerName: 'Alice',
        calleeId: 'user_bob',
        calleeName: 'Bob',
        callType: 'audio',
        direction: 'outgoing',
        status: 'ended',
        startedAt: DateTime.now(),
      );

      await controller.redialCall(audioCall);
      expect(mockZego.lastAudioTarget?.uid, 'user_bob');
    });

    // TEST 13: Existing ZEGOCLOUD video call -> Still works.
    test('TEST 13: Video call redial from history delegates to ZegoCallService', () async {
      final mockZego = MockZegoServiceForHistory();
      final controller = CallsController(
        callHistoryService: callHistoryService,
        authService: authService,
        zegoCallService: mockZego,
      );

      final videoCall = CallModel(
        id: 'call_video_test',
        firebaseUid: 'user_alice',
        callerId: 'user_bob',
        callerName: 'Bob',
        calleeId: 'user_alice',
        calleeName: 'Alice',
        callType: 'video',
        direction: 'incoming',
        status: 'ended',
        startedAt: DateTime.now(),
      );

      await controller.redialCall(videoCall);
      expect(mockZego.lastVideoTarget?.uid, 'user_bob');
    });
  });
}
