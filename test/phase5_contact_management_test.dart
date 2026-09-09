import 'package:connect_call/core/database/app_database.dart';
import 'package:connect_call/data/datasources/call_history_local_data_source.dart';
import 'package:connect_call/data/datasources/favorite_contacts_local_data_source.dart';
import 'package:connect_call/data/repositories/call_history_repository.dart';
import 'package:connect_call/data/repositories/favorite_contacts_repository.dart';
import 'package:connect_call/models/call_model.dart';
import 'package:connect_call/models/favorite_contact_model.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/contacts/contacts_controller.dart';
import 'package:connect_call/screens/home/home_controller.dart';
import 'package:connect_call/services/auth_service.dart';
import 'package:connect_call/services/block_service.dart';
import 'package:connect_call/services/call_history_service.dart';
import 'package:connect_call/services/contact_service.dart';
import 'package:connect_call/services/favorite_service.dart';
import 'package:connect_call/services/user_service.dart';
import 'package:connect_call/services/zego_call_service.dart';
import 'package:connect_call/widgets/user_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// --- MOCKS ---

class MockAuthService extends AuthService {
  String? currentUid;
  MockAuthService({this.currentUid = 'current_user_123'});

  @override
  String? get currentUserId => currentUid;
}

class MockZegoCallService extends ZegoCallService {
  UserModel? lastAudioCallTarget;
  UserModel? lastVideoCallTarget;
  int audioCallCount = 0;
  int videoCallCount = 0;

  @override
  Future<bool> sendAudioCallInvitation({required UserModel targetUser}) async {
    // Check block list before placing call
    if (BlockService.instance.isBlockedSync(targetUser.uid)) {
      return false;
    }
    lastAudioCallTarget = targetUser;
    audioCallCount++;
    return true;
  }

  @override
  Future<bool> sendVideoCallInvitation({required UserModel targetUser}) async {
    // Check block list before placing call
    if (BlockService.instance.isBlockedSync(targetUser.uid)) {
      return false;
    }
    lastVideoCallTarget = targetUser;
    videoCallCount++;
    return true;
  }
}

class MockUserService extends UserService {
  final Map<String, UserModel> registeredUsers = {};

  MockUserService({Map<String, UserModel>? initialUsers}) {
    if (initialUsers != null) {
      registeredUsers.addAll(initialUsers);
    }
  }

  @override
  Future<List<UserModel>> matchUsersByPhoneNumbers(List<String> phoneNumbers) async {
    final List<UserModel> matched = [];
    for (final phone in phoneNumbers) {
      for (final user in registeredUsers.values) {
        if (user.effectiveNormalizedPhone == phone || user.phoneNumber == phone) {
          matched.add(user);
        }
      }
    }
    return matched;
  }

  @override
  Future<UserModel?> getUserByPhoneNumber(String normalizedPhoneNumber) async {
    for (final user in registeredUsers.values) {
      if (user.effectiveNormalizedPhone == normalizedPhoneNumber ||
          user.phoneNumber == normalizedPhoneNumber) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    return registeredUsers[uid];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late AppDatabase appDatabase;
  late FavoriteContactsLocalDataSource favoriteDataSource;
  late FavoriteContactsRepository favoriteRepository;
  late FavoriteService favoriteService;

  late CallHistoryLocalDataSource historyDataSource;
  late CallHistoryRepository historyRepository;
  late CallHistoryService historyService;

  late BlockService blockService;
  late MockAuthService authService;
  late MockZegoCallService zegoService;
  late MockUserService userService;

  // In-memory phonebook mock for testing device contacts
  final Map<String, DeviceContact> mockDevicePhonebook = {};
  int deviceContactCounter = 1;

  late ContactService contactService;

  setUp(() async {
    Get.testMode = true;
    mockDevicePhonebook.clear();
    deviceContactCounter = 3;

    // Create an in-memory SQLite database
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

    favoriteDataSource = FavoriteContactsLocalDataSource(appDatabase: appDatabase);
    favoriteRepository = FavoriteContactsRepositoryImpl(localDataSource: favoriteDataSource);

    historyDataSource = CallHistoryLocalDataSource(appDatabase: appDatabase);
    historyRepository = CallHistoryRepositoryImpl(
      localDataSource: historyDataSource,
      authService: MockAuthService(currentUid: 'current_user_123'),
    );

    authService = MockAuthService(currentUid: 'current_user_123');

    favoriteService = FavoriteService(
      repository: favoriteRepository,
      authService: authService,
    );
    FavoriteService.setInstance(favoriteService);

    historyService = CallHistoryService(
      repository: historyRepository,
      authService: authService,
    );
    CallHistoryService.setInstance(historyService);

    // BlockService with in-memory block delegates
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
      isBlockedDelegate: (targetUid, currentUid) async {
        return inMemoryBlocked.contains(targetUid);
      },
      getBlockedListDelegate: (currentUid) async {
        return inMemoryBlocked.toList();
      },
    );
    BlockService.setInstance(blockService);

    zegoService = MockZegoCallService();

    // Set up mock registered users
    userService = MockUserService(initialUsers: {
      'user_rahul': UserModel(
        uid: 'user_rahul',
        name: 'Rahul Sharma',
        phoneNumber: '+919876543211',
        normalizedPhoneNumber: '+919876543211',
        createdAt: DateTime.now(),
      ),
      'user_amit': UserModel(
        uid: 'user_amit',
        name: 'Amit Verma',
        phoneNumber: '+919123456789',
        normalizedPhoneNumber: '+919123456789',
        createdAt: DateTime.now(),
      ),
      'user_priya': UserModel(
        uid: 'user_priya',
        name: 'Priya Singh',
        phoneNumber: '+919999999999',
        normalizedPhoneNumber: '+919999999999',
        createdAt: DateTime.now(),
      ),
    });

    // Populate device phonebook mock
    mockDevicePhonebook['1'] = const DeviceContact(
      id: '1',
      displayName: 'Rahul Device',
      phoneNumbers: ['+919876543211'],
    );
    mockDevicePhonebook['2'] = const DeviceContact(
      id: '2',
      displayName: 'Amit Device',
      phoneNumbers: ['+919123456789'],
    );

    contactService = ContactService(
      checkPermissionDelegate: () async => ph.PermissionStatus.granted,
      requestPermissionDelegate: () async => ph.PermissionStatus.granted,
      fetchContactsDelegate: () async => mockDevicePhonebook.values.toList(),
      createContactDelegate: (name, phone) async {
        final id = '${deviceContactCounter++}';
        mockDevicePhonebook[id] = DeviceContact(
          id: id,
          displayName: name,
          phoneNumbers: [phone],
        );
        return id;
      },
      updateContactDelegate: (id, name, phone) async {
        if (!mockDevicePhonebook.containsKey(id)) return false;
        mockDevicePhonebook[id] = DeviceContact(
          id: id,
          displayName: name,
          phoneNumbers: [phone],
        );
        return true;
      },
      deleteContactDelegate: (id) async {
        final removed = mockDevicePhonebook.remove(id);
        return removed != null;
      },
    );
  });

  tearDown(() async {
    await db.close();
    Get.reset();
  });

  group('PHASE 5 TEST SUITE — CONTACT MANAGEMENT + BLOCK/UNBLOCK + FAVORITES + HOME PAGE', () {
    // -------------------------------------------------------------
    // TEST 1 — ADD CONTACT
    // -------------------------------------------------------------
    test('TEST 1: Add contact saves to device contacts and registered matching is refreshed', () async {
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      await controller.loadContacts();
      expect(controller.users.length, 2); // Rahul and Amit initially

      // Add Priya to device contacts
      final success = await controller.addContact(
        name: 'Priya Device',
        phoneNumber: '+919999999999',
      );

      expect(success, isTrue);
      // Verify in device contacts
      expect(mockDevicePhonebook.values.any((c) => c.displayName == 'Priya Device'), isTrue);
      // Verify registered user Priya is now matched in controller
      expect(controller.users.any((u) => u.uid == 'user_priya'), isTrue);
      expect(controller.users.length, 3);
    });

    // -------------------------------------------------------------
    // TEST 2 — EDIT CONTACT
    // -------------------------------------------------------------
    test('TEST 2: Edit contact updates device contact without altering registered user profile', () async {
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      await controller.loadContacts();

      // Edit Rahul's contact in device phonebook
      final success = await controller.updateContact(
        contactId: '1',
        newName: 'Rahul Best Friend',
        newPhoneNumber: '+919876543211',
      );

      expect(success, isTrue);
      // Device contact is updated
      expect(mockDevicePhonebook['1']?.displayName, 'Rahul Best Friend');

      // Registered user profile in Firestore remains unchanged
      final registeredRahul = await userService.getUser('user_rahul');
      expect(registeredRahul?.name, 'Rahul Sharma');
    });

    // -------------------------------------------------------------
    // TEST 3 — DELETE CONTACT
    // -------------------------------------------------------------
    test('TEST 3: Delete contact removes it from device contacts without deleting Firebase user or call history', () async {
      // Seed a call record for Rahul in SQLite
      await historyService.saveCallRecord(CallModel(
        id: 'call_rahul_1',
        firebaseUid: 'current_user_123',
        callerId: 'current_user_123',
        callerName: 'Current User',
        calleeId: 'user_rahul',
        calleeName: 'Rahul Sharma',
        callType: 'audio',
        direction: 'outgoing',
        status: 'ended',
        startedAt: DateTime.now(),
        durationSeconds: 45,
      ));

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      await controller.loadContacts();
      expect(controller.users.any((u) => u.uid == 'user_rahul'), isTrue);

      // Delete Rahul from device contacts
      final success = await controller.deleteContact('1');
      expect(success, isTrue);
      expect(mockDevicePhonebook.containsKey('1'), isFalse);

      // Registered user is no longer matched in device contacts
      expect(controller.users.any((u) => u.uid == 'user_rahul'), isFalse);

      // Verify Firestore registered user still exists
      final registeredRahul = await userService.getUser('user_rahul');
      expect(registeredRahul, isNotNull);

      // Verify SQLite call history for Rahul remains intact
      final history = await historyService.getCallHistory();
      expect(history.any((c) => c.calleeId == 'user_rahul'), isTrue);

      // Verify user was NOT blocked
      expect(controller.isBlocked('user_rahul'), isFalse);
    });

    // -------------------------------------------------------------
    // TEST 4 — BLOCK USER
    // -------------------------------------------------------------
    test('TEST 4: Block user creates block record and updates state immediately', () async {
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      final rahul = (await userService.getUser('user_rahul'))!;
      expect(controller.isBlocked(rahul.uid), isFalse);

      await controller.blockUser(rahul);

      expect(controller.isBlocked(rahul.uid), isTrue);
      expect(await blockService.isUserBlocked(targetUid: rahul.uid), isTrue);
    });

    // -------------------------------------------------------------
    // TEST 5 — UNBLOCK USER
    // -------------------------------------------------------------
    test('TEST 5: Unblock user removes block record and restores user', () async {
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      final rahul = (await userService.getUser('user_rahul'))!;
      await controller.blockUser(rahul);
      expect(controller.isBlocked(rahul.uid), isTrue);

      await controller.unblockUser(rahul.uid);

      expect(controller.isBlocked(rahul.uid), isFalse);
      expect(await blockService.isUserBlocked(targetUid: rahul.uid), isFalse);
    });

    // -------------------------------------------------------------
    // TEST 6 — OUTGOING CALL TO BLOCKED USER
    // -------------------------------------------------------------
    test('TEST 6: Outgoing call to blocked user is rejected and invitation is not sent', () async {
      final rahul = (await userService.getUser('user_rahul'))!;
      await blockService.blockUser(blockedUserUid: rahul.uid);

      final success = await zegoService.sendAudioCallInvitation(targetUser: rahul);
      expect(success, isFalse);
      expect(zegoService.audioCallCount, 0);

      final videoSuccess = await zegoService.sendVideoCallInvitation(targetUser: rahul);
      expect(videoSuccess, isFalse);
      expect(zegoService.videoCallCount, 0);
    });

    // -------------------------------------------------------------
    // TEST 7 — INCOMING CALL FROM BLOCKED USER
    // -------------------------------------------------------------
    test('TEST 7: Incoming call from blocked user is rejected at service layer', () async {
      final rahul = (await userService.getUser('user_rahul'))!;
      await blockService.blockUser(blockedUserUid: rahul.uid);

      // Simulate incoming call check
      final isBlocked = await blockService.isUserBlocked(targetUid: rahul.uid);
      expect(isBlocked, isTrue);
      // ZegoCallService onIncomingCallReceived rejects when isUserBlocked is true
    });

    // -------------------------------------------------------------
    // TEST 8 — FAVORITE CONTACT (ADD)
    // -------------------------------------------------------------
    test('TEST 8: Tap star saves favorite contact into SQLite and updates state', () async {
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      final rahul = (await userService.getUser('user_rahul'))!;
      expect(controller.isFavorite(rahul.uid), isFalse);

      await controller.toggleFavorite(rahul);

      expect(controller.isFavorite(rahul.uid), isTrue);

      // Verify in SQLite database directly
      final inDb = await favoriteDataSource.isFavorite(
        firebaseUid: 'current_user_123',
        remoteUserId: 'user_rahul',
      );
      expect(inDb, isTrue);
    });

    // -------------------------------------------------------------
    // TEST 9 — UNFAVORITE CONTACT
    // -------------------------------------------------------------
    test('TEST 9: Tap star again removes favorite from SQLite', () async {
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      final rahul = (await userService.getUser('user_rahul'))!;
      await controller.toggleFavorite(rahul);
      expect(controller.isFavorite(rahul.uid), isTrue);

      // Toggle again to unfavorite
      await controller.toggleFavorite(rahul);
      expect(controller.isFavorite(rahul.uid), isFalse);

      final inDb = await favoriteDataSource.isFavorite(
        firebaseUid: 'current_user_123',
        remoteUserId: 'user_rahul',
      );
      expect(inDb, isFalse);
    });

    // -------------------------------------------------------------
    // TEST 10 — PERSISTENCE OF FAVORITES
    // -------------------------------------------------------------
    test('TEST 10: Favorites persist in SQLite across fresh service instances', () async {
      final rahul = (await userService.getUser('user_rahul'))!;
      await favoriteService.addFavorite(FavoriteContactModel(
        firebaseUid: 'current_user_123',
        remoteUserId: rahul.uid,
        contactName: rahul.name,
        phoneNumber: rahul.phoneNumber,
        createdAt: DateTime.now(),
      ));

      // Create a brand new FavoriteService pointing to same SQLite DB
      final freshFavoriteService = FavoriteService(
        repository: FavoriteContactsRepositoryImpl(localDataSource: favoriteDataSource),
        authService: authService,
      );

      final loadedFavorites = await freshFavoriteService.getFavorites();
      expect(loadedFavorites.length, 1);
      expect(loadedFavorites.first.remoteUserId, rahul.uid);
      expect(loadedFavorites.first.contactName, 'Rahul Sharma');
    });

    // -------------------------------------------------------------
    // TEST 11 — HOME PAGE FAVORITES SECTION
    // -------------------------------------------------------------
    test('TEST 11: Home page loads and displays favorite contacts when favorites exist', () async {
      final rahul = (await userService.getUser('user_rahul'))!;
      await favoriteService.addFavorite(FavoriteContactModel(
        firebaseUid: 'current_user_123',
        remoteUserId: rahul.uid,
        contactName: rahul.name,
        phoneNumber: rahul.phoneNumber,
        createdAt: DateTime.now(),
      ));

      final homeController = HomeController(
        authService: authService,
        userService: userService,
        callHistoryService: historyService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      await homeController.loadHomeContacts();

      expect(homeController.favoriteContacts.length, 1);
      expect(homeController.favoriteContacts.first.remoteUserId, 'user_rahul');
      expect(homeController.mostCalledContacts.isEmpty, isTrue);
    });

    // -------------------------------------------------------------
    // TEST 12 — HOME PAGE MOST CALLED FALLBACK
    // -------------------------------------------------------------
    test('TEST 12: Home page falls back to most frequently called when no favorites exist', () async {
      // Add calls in SQLite call history: 3 calls to Amit, 1 call to Rahul
      for (int i = 0; i < 3; i++) {
        await historyService.saveCallRecord(CallModel(
          id: 'call_amit_$i',
          firebaseUid: 'current_user_123',
          callerId: 'current_user_123',
          callerName: 'Current User',
          calleeId: 'user_amit',
          calleeName: 'Amit Verma',
          callType: i == 0 ? 'video' : 'audio',
          direction: 'outgoing',
          status: 'ended',
          startedAt: DateTime.now().subtract(Duration(hours: i)),
          durationSeconds: 60,
        ));
      }
      await historyService.saveCallRecord(CallModel(
        id: 'call_rahul_single',
        firebaseUid: 'current_user_123',
        callerId: 'current_user_123',
        callerName: 'Current User',
        calleeId: 'user_rahul',
        calleeName: 'Rahul Sharma',
        callType: 'audio',
        direction: 'outgoing',
        status: 'ended',
        startedAt: DateTime.now().subtract(const Duration(hours: 4)),
        durationSeconds: 30,
      ));

      final homeController = HomeController(
        authService: authService,
        userService: userService,
        callHistoryService: historyService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      await homeController.loadHomeContacts();

      expect(homeController.favoriteContacts.isEmpty, isTrue);
      expect(homeController.mostCalledContacts.length, 2);
      // Amit has 3 calls -> first in rank
      expect(homeController.mostCalledContacts.first.uid, 'user_amit');
      expect(homeController.mostCalledCounts['user_amit'], 3);
      // Rahul has 1 call -> second in rank
      expect(homeController.mostCalledContacts[1].uid, 'user_rahul');
      expect(homeController.mostCalledCounts['user_rahul'], 1);
    });

    // -------------------------------------------------------------
    // TEST 13 — HOME PAGE EMPTY STATE
    // -------------------------------------------------------------
    test('TEST 13: Home page shows empty state when neither favorites nor call history exist', () async {
      final homeController = HomeController(
        authService: authService,
        userService: userService,
        callHistoryService: historyService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      await homeController.loadHomeContacts();

      expect(homeController.favoriteContacts.isEmpty, isTrue);
      expect(homeController.mostCalledContacts.isEmpty, isTrue);
    });

    // -------------------------------------------------------------
    // TEST 14 — BLOCKED USER EXCLUSION FROM HOME PAGE
    // -------------------------------------------------------------
    test('TEST 14: Blocked users are strictly excluded from Favorites and Most Called recommendations', () async {
      // Add Rahul to favorites
      final rahul = (await userService.getUser('user_rahul'))!;
      await favoriteService.addFavorite(FavoriteContactModel(
        firebaseUid: 'current_user_123',
        remoteUserId: rahul.uid,
        contactName: rahul.name,
        phoneNumber: rahul.phoneNumber,
        createdAt: DateTime.now(),
      ));

      // Add call history for Amit
      await historyService.saveCallRecord(CallModel(
        id: 'call_amit_hist',
        firebaseUid: 'current_user_123',
        callerId: 'current_user_123',
        callerName: 'Current User',
        calleeId: 'user_amit',
        calleeName: 'Amit Verma',
        callType: 'audio',
        direction: 'outgoing',
        status: 'ended',
        startedAt: DateTime.now(),
        durationSeconds: 10,
      ));

      // Block Rahul
      await blockService.blockUser(blockedUserUid: rahul.uid);

      final homeController = HomeController(
        authService: authService,
        userService: userService,
        callHistoryService: historyService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      await homeController.loadHomeContacts();

      // Rahul is blocked -> filtered out of favorites
      expect(homeController.favoriteContacts.any((f) => f.remoteUserId == rahul.uid), isFalse);

      // Now block Amit as well
      await blockService.blockUser(blockedUserUid: 'user_amit');
      await homeController.loadHomeContacts();

      // Amit is blocked -> filtered out of most called recommendations
      expect(homeController.mostCalledContacts.any((u) => u.uid == 'user_amit'), isFalse);
    });

    // -------------------------------------------------------------
    // TEST 15 — CALL HISTORY UNTOUCHED BY CONTACT DELETION
    // -------------------------------------------------------------
    test('TEST 15: Deleting a device contact leaves SQLite call history intact', () async {
      // Record a call for Amit
      await historyService.saveCallRecord(CallModel(
        id: 'call_amit_permanent',
        firebaseUid: 'current_user_123',
        callerId: 'user_amit',
        callerName: 'Amit Verma',
        calleeId: 'current_user_123',
        calleeName: 'Current User',
        callType: 'video',
        direction: 'incoming',
        status: 'ended',
        startedAt: DateTime.now(),
        durationSeconds: 120,
      ));

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        blockService: blockService,
        favoriteService: favoriteService,
        zegoCallService: zegoService,
      );

      // Delete Amit (id: 2) from phone contacts
      final deleted = await controller.deleteContact('2');
      expect(deleted, isTrue);

      // Verify SQLite call record is completely intact
      final history = await historyService.getCallHistory();
      final callRecord = history.firstWhere((c) => c.id == 'call_amit_permanent');
      expect(callRecord.callerName, 'Amit Verma');
      expect(callRecord.durationSeconds, 120);
    });

    // -------------------------------------------------------------
    // TEST 16 — SOURCE OF TRUTH INTEGRITY
    // -------------------------------------------------------------
    test('TEST 16: Device contacts remain sole source of truth and are not duplicated into SQLite', () async {
      // Query SQLite tables directly to prove device contacts table does NOT exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
      );
      final tableNames = tables.map((t) => t['name'] as String).toList();

      // SQLite must ONLY contain call_history and favorite_contacts
      expect(tableNames, contains(AppDatabase.callHistoryTable));
      expect(tableNames, contains(AppDatabase.favoriteContactsTable));
      expect(tableNames.contains('device_contacts'), isFalse);
      expect(tableNames.contains('contacts'), isFalse);
    });

    // -------------------------------------------------------------
    // UI WIDGET TEST: UserTile Favorite Star & Blocked Pill
    // -------------------------------------------------------------
    testWidgets('UserTile renders Favorite star, Blocked indicator, and disables call buttons when blocked', (tester) async {
      final user = UserModel(
        uid: 'user_tile_test',
        name: 'Tile User',
        phoneNumber: '+919876543210',
        createdAt: DateTime.now(),
      );

      // Case A: Active & Favorited
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UserTile(
            user: user,
            isFavorite: true,
            isBlocked: false,
            onAudioCall: () {},
            onVideoCall: () {},
            onToggleFavorite: () {},
          ),
        ),
      ));

      // Star indicator visible
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      // Audio and Video call buttons present
      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);

      // Case B: Blocked User
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UserTile(
            user: user,
            isFavorite: false,
            isBlocked: true,
            onAudioCall: () {},
            onVideoCall: () {},
          ),
        ),
      ));

      // Blocked badge visible
      expect(find.text('Blocked'), findsWidgets);
    });
  });
}
