import 'package:connect_call/core/database/app_database.dart';
import 'package:connect_call/core/utils/phone_number_util.dart';
import 'package:connect_call/data/datasources/call_history_local_data_source.dart';
import 'package:connect_call/data/repositories/call_history_repository.dart';
import 'package:connect_call/models/call_model.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/contacts/contacts_controller.dart';
import 'package:connect_call/screens/contacts/contacts_screen.dart';
import 'package:connect_call/services/auth_service.dart';
import 'package:connect_call/services/call_history_service.dart';
import 'package:connect_call/services/contact_service.dart';
import 'package:connect_call/services/user_service.dart';
import 'package:connect_call/services/zego_call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:connect_call/routes/app_pages.dart';

// Mock ContactService for device contacts
class MockContactService extends ContactService {
  final PermissionStatus mockPermission;
  final List<DeviceContact> mockContacts;

  MockContactService({
    this.mockPermission = PermissionStatus.granted,
    this.mockContacts = const [],
  });

  @override
  Future<PermissionStatus> checkPermission() async => mockPermission;

  @override
  Future<PermissionStatus> requestPermission() async => mockPermission;

  @override 
  Future<List<DeviceContact>> getContacts() async => mockContacts;
}

// Mock UserService with exact phone number lookup tracking
class MockUserService extends UserService {
  final List<UserModel> registeredUsers;
  final bool shouldThrowNetwork;  
  final bool shouldThrowGeneric;
  List<String> lookupPhoneCalls = [];

  MockUserService({
    this.registeredUsers = const [],
    this.shouldThrowNetwork = false,
    this.shouldThrowGeneric = false,
  });

  @override
  Future<List<UserModel>> matchUsersByPhoneNumbers(List<String> phoneNumbers) async {
    return registeredUsers
        .where((u) =>
            phoneNumbers.contains(u.phoneNumber) ||
            phoneNumbers.contains(u.effectiveNormalizedPhone))
        .toList();
  }

  @override
  Future<UserModel?> getUserByPhoneNumber(String phoneNumber) async {
    lookupPhoneCalls.add(phoneNumber);
    if (shouldThrowNetwork) {
      throw 'Network error. Please check your connection.';
    }
    if (shouldThrowGeneric) {
      throw 'Firestore query failure';
    }

    final normalized = PhoneNumberUtil.normalize(phoneNumber) ?? phoneNumber.trim();
    for (final user in registeredUsers) {
      if (user.effectiveNormalizedPhone == normalized ||
          PhoneNumberUtil.normalize(user.phoneNumber) == normalized ||
          user.phoneNumber == phoneNumber.trim()) {
        return user;
      }
    }
    return null;
  }
}

// Mock AuthService for self-user identification
class MockAuthService extends AuthService {
  final String? mockUid;
  final String? mockPhone;

  MockAuthService({this.mockUid, this.mockPhone});

  @override
  String? get currentUserId => mockUid;
}

// Mock ZegoCallService for tracking calls made from search results
class MockZegoCallService extends ZegoCallService {
  UserModel? lastAudioTarget;
  UserModel? lastVideoTarget;

  @override
  Future<bool> sendAudioCallInvitation({
    required UserModel targetUser,
    BuildContext? context,
  }) async {
    lastAudioTarget = targetUser;
    return true;
  }

  @override
  Future<bool> sendVideoCallInvitation({
    required UserModel targetUser,
    BuildContext? context,
  }) async {
    lastVideoTarget = targetUser;
    return true;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  final userRahul = UserModel(
    uid: 'u_rahul',
    name: 'Rahul Sharma',
    phoneNumber: '+919876543210',
    isOnline: true,
    createdAt: DateTime.now(),
  );

  final userAmit = UserModel(
    uid: 'u_amit',
    name: 'Amit Patel',
    phoneNumber: '+919123456789',
    isOnline: false,
    createdAt: DateTime.now(),
  );

  final userExternalPriya = UserModel(
    uid: 'u_priya',
    name: 'Priya Verma',
    phoneNumber: '+919988776655',
    isOnline: true,
    createdAt: DateTime.now(),
  );

  group('Phase 4: Smart Contacts Search Test Suite (11 Core Test Cases)', () {
    // TEST 1 — Normal contact search
    test('Test 1: Normal text search ("Rahul") filters locally loaded contacts without Firestore lookup', () async {
      final contactService = MockContactService(
        mockContacts: [
          const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
          const DeviceContact(displayName: 'Amit', phoneNumbers: ['+91 91234 56789']),
        ],
      );
      final userService = MockUserService(registeredUsers: [userRahul, userAmit]);
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        currentUserIdOverride: 'u_self',
      );

      await controller.initContacts();
      expect(controller.users.length, 2);

      // Search normal text
      controller.onSearchChanged('Rahul');

      expect(controller.filteredUsers.length, 1);
      expect(controller.filteredUsers.first.name, 'Rahul Sharma');
      // Verify no Firestore exact phone lookup was triggered
      expect(userService.lookupPhoneCalls, isEmpty);
      expect(controller.isSearchingRemote.value, isFalse);
    });

    // TEST 2 — Partial number search
    test('Test 2: Partial number ("987654") filters locally loaded contacts and does NOT query Firestore', () async {
      final contactService = MockContactService(
        mockContacts: [
          const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
          const DeviceContact(displayName: 'Amit', phoneNumbers: ['+91 91234 56789']),
        ],
      );
      final userService = MockUserService(registeredUsers: [userRahul, userAmit]);
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        currentUserIdOverride: 'u_self',
      );

      await controller.initContacts();
      expect(controller.users.length, 2);

      // Partial 6 digits
      controller.onSearchChanged('987654');

      expect(controller.filteredUsers.length, 1);
      expect(controller.filteredUsers.first.name, 'Rahul Sharma');
      // No Firestore lookup for < 10 digits
      expect(userService.lookupPhoneCalls, isEmpty);
      expect(controller.isSearchingRemote.value, isFalse);
    });

    // TEST 3 — Complete number + saved contact
    test('Test 3: Complete 10-digit number already saved in contacts uses local match without Firestore lookup', () async {
      final contactService = MockContactService(
        mockContacts: [
          const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
        ],
      );
      final userService = MockUserService(registeredUsers: [userRahul]);
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        currentUserIdOverride: 'u_self',
      );

      await controller.initContacts();
      expect(controller.users.length, 1);

      // Enter full 10-digit number of saved contact
      controller.onSearchChanged('9876543210');

      // Local filter immediately displays Rahul
      expect(controller.filteredUsers.length, 1);
      expect(controller.filteredUsers.first.name, 'Rahul Sharma');
      // Zero Firestore lookups because contact was already authoritative locally
      expect(userService.lookupPhoneCalls, isEmpty);
      expect(controller.remoteSearchedUser.value, isNull);
    });

    // TEST 4 — Complete number + NOT saved contact + REGISTERED
    test('Test 4: Complete 10-digit number NOT saved in contacts triggers exact Firestore lookup and finds user', () async {
      final contactService = MockContactService(
        mockContacts: [
          const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
        ],
      );
      // Priya is in Firestore but NOT in device contacts
      final userService = MockUserService(registeredUsers: [userRahul, userExternalPriya]);
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        currentUserIdOverride: 'u_self',
      );

      await controller.initContacts();
      expect(controller.users.length, 1);

      // Enter Priya's 10-digit number
      controller.onSearchChanged('9988776655');

      // Execute remote search directly
      await controller.performRemoteSearch('+919988776655');

      expect(userService.lookupPhoneCalls.length, 1);
      expect(userService.lookupPhoneCalls.first, '+919988776655');
      expect(controller.remoteSearchedUser.value, isNotNull);
      expect(controller.remoteSearchedUser.value!.name, 'Priya Verma');
      expect(controller.remoteSearchNotFound.value, isFalse);
      expect(controller.isSelfNumberSearched.value, isFalse);
    });

    // TEST 5 — Complete number + NOT registered
    test('Test 5: Complete 10-digit number NOT registered shows remoteSearchNotFound state', () async {
      final contactService = MockContactService(
        mockContacts: [
          const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
        ],
      );
      final userService = MockUserService(registeredUsers: [userRahul]);
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        currentUserIdOverride: 'u_self',
      );

      await controller.initContacts();

      // Enter non-registered 10-digit number
      controller.onSearchChanged('9999999999');
      await controller.performRemoteSearch('+919999999999');

      expect(userService.lookupPhoneCalls.contains('+919999999999'), isTrue);
      expect(controller.remoteSearchedUser.value, isNull);
      expect(controller.remoteSearchNotFound.value, isTrue);
    });

    // TEST 6 — Current user's number
    test('Test 6: Current logged-in user number sets isSelfNumberSearched and prevents calling', () async {
      final contactService = MockContactService(
        mockContacts: [
          const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
        ],
      );
      final userService = MockUserService(registeredUsers: [userRahul]);
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        currentUserIdOverride: 'u_self',
        currentUserPhoneOverride: '+919888877777',
      );

      await controller.initContacts();

      // Enter logged-in user's own number
      controller.onSearchChanged('9888877777');

      expect(controller.isSelfNumberSearched.value, isTrue);
      expect(controller.remoteSearchedUser.value, isNotNull);
      // No Firestore call needed since current user is detected locally
      expect(userService.lookupPhoneCalls, isEmpty);
    });

    // TEST 7 — Different phone formats normalize consistently
    test('Test 7: Different phone formats all normalize consistently to +919876543210', () {
      final formats = [
        '9876543210',
        '+919876543210',
        '919876543210',
        '09876543210',
        '+91 98765 43210',
        '+91-9876543210',
      ];

      for (final format in formats) {
        expect(PhoneNumberUtil.normalize(format), '+919876543210',
            reason: 'Failed to normalize format: $format');
      }
    });

    // TEST 8 — Firestore unavailable
    test('Test 8: Network or Firestore failure handles gracefully without crashing', () async {
      final contactService = MockContactService(mockContacts: []);
      final userService = MockUserService(shouldThrowNetwork: true);
      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        currentUserIdOverride: 'u_self',
      );

      controller.onSearchChanged('9876543210');
      await controller.performRemoteSearch('+919876543210');

      expect(controller.isSearchingRemote.value, isFalse);
      expect(controller.remoteSearchError.value.isNotEmpty, isTrue);
      expect(controller.remoteSearchError.value, contains('Network error'));
    });

    // TEST 9 — ZEGOCLOUD Audio Call
    test('Test 9: Audio call button triggers ZegoCallService audio invitation for searched user', () async {
      final zegoService = MockZegoCallService();
      final controller = ContactsController(
        zegoCallService: zegoService,
        contactService: MockContactService(),
        userService: MockUserService(),
        currentUserIdOverride: 'u_self',
      );

      await controller.onAudioCallTap(userExternalPriya);

      expect(zegoService.lastAudioTarget, isNotNull);
      expect(zegoService.lastAudioTarget!.uid, 'u_priya');
      expect(zegoService.lastAudioTarget!.name, 'Priya Verma');
    });

    // TEST 10 — ZEGOCLOUD Video Call
    test('Test 10: Video call button triggers ZegoCallService video invitation for searched user', () async {
      final zegoService = MockZegoCallService();
      final controller = ContactsController(
        zegoCallService: zegoService,
        contactService: MockContactService(),
        userService: MockUserService(),
        currentUserIdOverride: 'u_self',
      );

      await controller.onVideoCallTap(userExternalPriya);

      expect(zegoService.lastVideoTarget, isNotNull);
      expect(zegoService.lastVideoTarget!.uid, 'u_priya');
      expect(zegoService.lastVideoTarget!.name, 'Priya Verma');
    });

    // TEST 11 — Call History SQLite integration remains intact
    test('Test 11: Call history stores call with searched user in SQLite correctly', () async {
      final inMemoryDb = await databaseFactoryFfi.openDatabase(
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
          },
        ),
      );
      final appDb = AppDatabase(database: inMemoryDb);
      final localDataSource = CallHistoryLocalDataSource(appDatabase: appDb);
      final authService = MockAuthService(mockUid: 'u_self');
      final repository = CallHistoryRepositoryImpl(
        localDataSource: localDataSource,
        authService: authService,
      );
      final callHistoryService = CallHistoryService(
        repository: repository,
        authService: authService,
      );

      final call = CallModel(
        id: 'call_searched_user_1',
        callerId: 'u_self',
        callerName: 'Deepak Mewada',
        calleeId: userExternalPriya.uid,
        calleeName: userExternalPriya.name,
        callType: 'audio',
        direction: 'outgoing',
        status: 'ended',
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        endedAt: DateTime.now(),
        durationSeconds: 300,
        createdAt: DateTime.now(),
      );

      final saved = await callHistoryService.saveCallRecord(call, userId: 'u_self');
      expect(saved, isTrue);

      final history = await callHistoryService.getCallHistory(userId: 'u_self');
      expect(history.length, 1);
      expect(history.first.calleeName, 'Priya Verma');
      expect(history.first.durationSeconds, 300);

      await inMemoryDb.close();
    });
  });

  group('ContactsScreen Smart Search Widget Rendering Tests', () {
    testWidgets('Renders Registered User profile with Audio & Video call buttons', (tester) async {
      final zegoService = MockZegoCallService();
      final controller = ContactsController(
        zegoCallService: zegoService,
        contactService: MockContactService(mockContacts: []),
        userService: MockUserService(registeredUsers: [userExternalPriya]),
        currentUserIdOverride: 'u_self',
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(GetMaterialApp(
        home: const ContactsScreen(),
        getPages: AppPages.pages,
      ));
      await tester.pumpAndSettle();

      // Trigger searched user state
      controller.remoteSearchedUser.value = userExternalPriya;
      await tester.pumpAndSettle();

      expect(find.text('Registered User'), findsWidgets);
      expect(find.text('Priya Verma'), findsOneWidget);
      expect(find.text('+919988776655'), findsOneWidget);

      // Verify Audio and Video call buttons are rendered, and 3-dots menu is removed
      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);

      // Tap Audio Call
      await tester.tap(find.byIcon(Icons.call_rounded));
      await tester.pumpAndSettle();
      expect(zegoService.lastAudioTarget?.uid, 'u_priya');

      // Tap Video Call
      await tester.tap(find.byIcon(Icons.videocam_rounded));
      await tester.pumpAndSettle();
      expect(zegoService.lastVideoTarget?.uid, 'u_priya');
    });

    testWidgets('Renders self account protection badge and hides call buttons', (tester) async {
      final controller = ContactsController(
        contactService: MockContactService(mockContacts: []),
        userService: MockUserService(),
        currentUserIdOverride: 'u_self',
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(const GetMaterialApp(home: ContactsScreen()));
      await tester.pumpAndSettle();

      // Trigger self user state
      controller.isSelfNumberSearched.value = true;
      controller.remoteSearchedUser.value = UserModel(
        uid: 'u_self',
        name: 'Deepak Mewada',
        phoneNumber: '+919999900000',
        createdAt: DateTime.now(),
      );
      await tester.pumpAndSettle();

      expect(find.text('This is your account'), findsOneWidget);
      expect(find.byIcon(Icons.call_rounded), findsNothing);
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);
    });

    testWidgets('Renders "No registered user found" empty state when search returns null', (tester) async {
      final controller = ContactsController(
        contactService: MockContactService(mockContacts: []),
        userService: MockUserService(),
        currentUserIdOverride: 'u_self',
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(const GetMaterialApp(home: ContactsScreen()));
      await tester.pumpAndSettle();

      // Trigger not found state
      controller.remoteSearchNotFound.value = true;
      await tester.pumpAndSettle();

      expect(find.text('No registered user found'), findsOneWidget);
      expect(find.text('This number is not registered in the app.'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);
    });

    testWidgets('Renders "Checking registered users..." loading state', (tester) async {
      final controller = ContactsController(
        contactService: MockContactService(mockContacts: []),
        userService: MockUserService(),
        currentUserIdOverride: 'u_self',
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(const GetMaterialApp(home: ContactsScreen()));
      await tester.pumpAndSettle();

      // Trigger remote searching state
      controller.isSearchingRemote.value = true;
      await tester.pump();

      expect(find.text('Checking registered users...'), findsOneWidget);
      expect(find.text('Looking up phone number on ConnectCall'), findsOneWidget);
    });
  });
}
