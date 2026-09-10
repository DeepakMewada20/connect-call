import 'package:connect_call/core/utils/phone_number_util.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/contacts/contacts_controller.dart';
import 'package:connect_call/screens/contacts/contacts_screen.dart';
import 'package:connect_call/services/auth_service.dart';
import 'package:connect_call/services/contact_service.dart';
import 'package:connect_call/services/user_service.dart';
import 'package:connect_call/services/zego_call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connect_call/routes/app_pages.dart';
import 'package:connect_call/routes/app_routes.dart';

// Mock ContactService for testing device contacts and permissions
class MockContactService extends ContactService {
  PermissionStatus mockPermissionStatus;
  PermissionStatus mockRequestResultStatus;
  List<DeviceContact> mockContacts;
  bool openSettingsCalled = false;

  MockContactService({
    this.mockPermissionStatus = PermissionStatus.granted,
    this.mockRequestResultStatus = PermissionStatus.granted,
    this.mockContacts = const [],
  });

  @override
  Future<PermissionStatus> checkPermission() async => mockPermissionStatus;

  @override
  Future<PermissionStatus> requestPermission() async => mockRequestResultStatus;

  @override
  Future<bool> openAppSettings() async {
    openSettingsCalled = true;
    return true;
  }

  @override
  Future<List<DeviceContact>> getContacts() async => mockContacts;
}

// Mock UserService that doesn't need Firebase initialized
class MockUserService extends UserService {
  final List<UserModel> registeredUsers;
  final bool shouldThrow;
  final bool throwNetwork;
  List<String> lastQueriedNumbers = [];

  MockUserService({
    this.registeredUsers = const [],
    this.shouldThrow = false,
    this.throwNetwork = false,
  });

  @override
  Future<List<UserModel>> matchUsersByPhoneNumbers(List<String> phoneNumbers) async {
    lastQueriedNumbers = List.from(phoneNumbers);
    if (throwNetwork) throw 'Network error. Please check your connection.';
    if (shouldThrow) throw 'Firestore connection error';

    return registeredUsers
        .where((u) =>
            phoneNumbers.contains(u.phoneNumber) ||
            phoneNumbers.contains(u.effectiveNormalizedPhone))
        .toList();
  }

  @override
  Future<List<UserModel>> getUsers() async {
    if (shouldThrow) throw 'Firestore connection error';
    return registeredUsers;
  }
}

// Mock AuthService for testing currentUser filtering
class MockAuthService extends AuthService {
  final String? mockUid;

  MockAuthService({this.mockUid});

  @override
  String? get currentUserId => mockUid;
}

// Mock ZegoCallService for tracking call invitations
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
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  // Test data models
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

  final userSelf = UserModel(
    uid: 'u_self',
    name: 'Deepak Mewada',
    phoneNumber: '+919999900000',
    isOnline: true,
    createdAt: DateTime.now(),
  );

  group('UserModel Null-Safety & Normalization Tests', () {
    test('fromMap gracefully handles empty map with null values', () {
      final user = UserModel.fromMap(const {});

      expect(user.uid, '');
      expect(user.name, '');
      expect(user.phoneNumber, '');
      expect(user.profileImage, '');
      expect(user.isOnline, false);
      expect(user.createdAt, isA<DateTime>());
      expect(user.effectiveNormalizedPhone, '');
    });

    test('fromMap correctly parses documentId and normalizedPhoneNumber', () {
      final user = UserModel.fromMap(
        {
          'name': 'Alex',
          'phoneNumber': '9876543210',
          'normalizedPhoneNumber': '+919876543210',
        },
        documentId: 'doc_123',
      );

      expect(user.uid, 'doc_123');
      expect(user.name, 'Alex');
      expect(user.phoneNumber, '9876543210');
      expect(user.normalizedPhoneNumber, '+919876543210');
      expect(user.effectiveNormalizedPhone, '+919876543210');
    });

    test('toMap saves normalizedPhoneNumber automatically', () {
      final user = UserModel(
        uid: 'u1',
        name: 'User One',
        phoneNumber: '09876543210',
        createdAt: DateTime.now(),
      );

      final map = user.toMap();
      expect(map['phoneNumber'], '09876543210');
      expect(map['normalizedPhoneNumber'], '+919876543210');
    });
  });

  group('Phase 2 Required Scenarios (Step 21)', () {
    // 1. Permission granted flow
    test('Scenario 1: Permission granted flow fetches and matches contacts', () async {
      final contactService = MockContactService(
        mockPermissionStatus: PermissionStatus.granted,
        mockContacts: [
          const DeviceContact(
            displayName: 'Rahul Local',
            phoneNumbers: ['+91 98765 43210'],
          ),
        ],
      );
      final userService = MockUserService(registeredUsers: [userRahul]);
      final authService = MockAuthService(mockUid: 'u_self');

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        currentUserIdOverride: 'u_self',
      );

      await controller.initContacts();

      expect(controller.permissionState.value, ContactsPermissionState.granted);
      expect(controller.users.length, 1);
      expect(controller.users.first.name, 'Rahul Sharma'); // Profile name used
      expect(controller.isLoading.value, isFalse);
    });

    // 2. Permission denied flow
    test('Scenario 2: Permission denied flow transitions state properly', () async {
      final contactService = MockContactService(
        mockPermissionStatus: PermissionStatus.denied,
        mockRequestResultStatus: PermissionStatus.denied,
      );
      final userService = MockUserService();
      final authService = MockAuthService(mockUid: 'u_self');

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
      );

      await controller.initContacts();

      expect(controller.permissionState.value, ContactsPermissionState.denied);
      expect(controller.users, isEmpty);
    });

    // 3. Permission permanently denied flow
    test('Scenario 3: Permanently denied flow transitions state and opens settings', () async {
      final contactService = MockContactService(
        mockPermissionStatus: PermissionStatus.permanentlyDenied,
      );
      final userService = MockUserService();
      final authService = MockAuthService(mockUid: 'u_self');

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
      );

      await controller.initContacts();

      expect(controller.permissionState.value, ContactsPermissionState.permanentlyDenied);

      await controller.openSettings();
      expect(contactService.openSettingsCalled, isTrue);
    });

    // 4. Normalization of various phone formats
    test('Scenario 4: Normalizes +91, spaces, dashes, 0-prefix, and 91-prefix correctly', () {
      expect(PhoneNumberUtil.normalize('+91 98765 43210'), '+919876543210');
      expect(PhoneNumberUtil.normalize('+91-9876543210'), '+919876543210');
      expect(PhoneNumberUtil.normalize('09876543210'), '+919876543210');
      expect(PhoneNumberUtil.normalize('9876543210'), '+919876543210');
      expect(PhoneNumberUtil.normalize('919876543210'), '+919876543210');
      expect(PhoneNumberUtil.normalize('00919876543210'), '+919876543210');
    });

    // 5. Exclude non-registered contacts
    test('Scenario 5: Only registered contacts are matched and returned', () async {
      final contactService = MockContactService(
        mockPermissionStatus: PermissionStatus.granted,
        mockContacts: [
          const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
          const DeviceContact(displayName: 'Amit', phoneNumbers: ['+91 91234 56789']),
          const DeviceContact(displayName: 'Unregistered 1', phoneNumbers: ['+91 88888 88888']),
          const DeviceContact(displayName: 'Unregistered 2', phoneNumbers: ['+91 77777 77777']),
        ],
      );
      final userService = MockUserService(
        registeredUsers: [userRahul, userAmit],
      );
      final authService = MockAuthService(mockUid: 'u_self');

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        currentUserIdOverride: 'u_self',
      );

      await controller.loadContacts();

      expect(controller.users.length, 2);
      expect(controller.users.any((u) => u.uid == 'u_rahul'), isTrue);
      expect(controller.users.any((u) => u.uid == 'u_amit'), isTrue);
    });

    // 6. Exclude current logged in user
    test('Scenario 6: Current logged-in user is strictly excluded from list', () async {
      final contactService = MockContactService(
        mockPermissionStatus: PermissionStatus.granted,
        mockContacts: [
          const DeviceContact(displayName: 'My Own Number', phoneNumbers: ['+91 99999 00000']),
          const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
        ],
      );
      final userService = MockUserService(
        registeredUsers: [userSelf, userRahul],
      );
      final authService = MockAuthService(mockUid: 'u_self');

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        currentUserIdOverride: 'u_self',
        currentUserPhoneOverride: '+919999900000',
      );

      await controller.loadContacts();

      expect(controller.users.length, 1);
      expect(controller.users.first.uid, 'u_rahul');
      expect(controller.users.any((u) => u.uid == 'u_self'), isFalse);
    });

    // 7. Deduplication of contacts
    test('Scenario 7: Duplicate numbers in device contacts produce deduplicated query and list', () async {
      final contactService = MockContactService(
        mockPermissionStatus: PermissionStatus.granted,
        mockContacts: [
          const DeviceContact(displayName: 'Rahul Home', phoneNumbers: ['09876543210']),
          const DeviceContact(displayName: 'Rahul Work', phoneNumbers: ['+91 98765 43210']),
          const DeviceContact(displayName: 'Rahul Mobile', phoneNumbers: ['9876543210']),
        ],
      );
      final userService = MockUserService(registeredUsers: [userRahul]);
      final authService = MockAuthService(mockUid: 'u_self');

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        currentUserIdOverride: 'u_self',
      );

      await controller.loadContacts();

      expect(controller.users.length, 1);
      expect(controller.users.first.uid, 'u_rahul');
      expect(userService.lastQueriedNumbers.length, 1);
      expect(userService.lastQueriedNumbers.first, '+919876543210');
    });

    // 8. Empty contacts list on device
    test('Scenario 8: Empty device contacts produces empty list without errors', () async {
      final contactService = MockContactService(
        mockPermissionStatus: PermissionStatus.granted,
        mockContacts: [],
      );
      final userService = MockUserService(registeredUsers: [userRahul, userAmit]);
      final authService = MockAuthService(mockUid: 'u_self');

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
      );

      await controller.loadContacts();

      expect(controller.users, isEmpty);
      expect(controller.errorMessage.value, isEmpty);
    });

    // 9. Empty registered match (contacts exist on phone, but 0 registered in app)
    test('Scenario 9: Contacts exist on phone but none registered', () async {
      final contactService = MockContactService(
        mockPermissionStatus: PermissionStatus.granted,
        mockContacts: [
          const DeviceContact(displayName: 'Unregistered 1', phoneNumbers: ['+91 88888 88888']),
          const DeviceContact(displayName: 'Unregistered 2', phoneNumbers: ['+91 77777 77777']),
        ],
      );
      final userService = MockUserService(registeredUsers: []);
      final authService = MockAuthService(mockUid: 'u_self');

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
      );

      await controller.loadContacts();

      expect(controller.users, isEmpty);
      expect(controller.errorMessage.value, isEmpty);
    });

    // 10. Search filtering by name
    test('Scenario 10: Search filtering matches users by name case-insensitively', () async {
      final contactService = MockContactService(
        mockPermissionStatus: PermissionStatus.granted,
        mockContacts: [
          const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
          const DeviceContact(displayName: 'Amit', phoneNumbers: ['+91 91234 56789']),
        ],
      );
      final userService = MockUserService(registeredUsers: [userRahul, userAmit]);
      final authService = MockAuthService(mockUid: 'u_self');

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        currentUserIdOverride: 'u_self',
      );

      await controller.loadContacts();
      expect(controller.users.length, 2);

      controller.onSearchChanged('rahul');
      expect(controller.filteredUsers.length, 1);
      expect(controller.filteredUsers.first.name, 'Rahul Sharma');

      controller.onSearchChanged('AMIT');
      expect(controller.filteredUsers.length, 1);
      expect(controller.filteredUsers.first.name, 'Amit Patel');
    });

    // 11. Search filtering by phone
    test('Scenario 11: Search filtering matches users by phone number', () async {
      final contactService = MockContactService(
        mockPermissionStatus: PermissionStatus.granted,
        mockContacts: [
          const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
          const DeviceContact(displayName: 'Amit', phoneNumbers: ['+91 91234 56789']),
        ],
      );
      final userService = MockUserService(registeredUsers: [userRahul, userAmit]);
      final authService = MockAuthService(mockUid: 'u_self');

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        currentUserIdOverride: 'u_self',
      );

      await controller.loadContacts();

      controller.onSearchChanged('91234');
      expect(controller.filteredUsers.length, 1);
      expect(controller.filteredUsers.first.name, 'Amit Patel');
    });

    // 12. Audio call button triggers audio call
    test('Scenario 12: Audio call triggers ZegoCallService audio invitation', () async {
      final callService = MockZegoCallService();
      final controller = ContactsController(
        zegoCallService: callService,
        contactService: MockContactService(),
        userService: MockUserService(),
        authService: MockAuthService(),
      );

      await controller.onAudioCallTap(userRahul);
      expect(callService.lastAudioTarget?.uid, 'u_rahul');
    });

    // 13. Video call button triggers video call
    test('Scenario 13: Video call triggers ZegoCallService video invitation', () async {
      final callService = MockZegoCallService();
      final controller = ContactsController(
        zegoCallService: callService,
        contactService: MockContactService(),
        userService: MockUserService(),
        authService: MockAuthService(),
      );

      await controller.onVideoCallTap(userAmit);
      expect(callService.lastVideoTarget?.uid, 'u_amit');
    });

    // 14. Pull to refresh triggers reload
    test('Scenario 14: Refresh contacts re-runs matching pipeline', () async {
      final contactService = MockContactService(
        mockPermissionStatus: PermissionStatus.granted,
        mockContacts: [
          const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
        ],
      );
      final userService = MockUserService(registeredUsers: [userRahul]);
      final authService = MockAuthService(mockUid: 'u_self');

      final controller = ContactsController(
        contactService: contactService,
        userService: userService,
        authService: authService,
        currentUserIdOverride: 'u_self',
      );

      await controller.loadContacts();
      expect(controller.users.length, 1);

      // Now add Amit to contacts and refresh
      contactService.mockContacts = [
        const DeviceContact(displayName: 'Rahul', phoneNumbers: ['+91 98765 43210']),
        const DeviceContact(displayName: 'Amit', phoneNumbers: ['+91 91234 56789']),
      ];
      userService.registeredUsers.add(userAmit);

      await controller.refreshContacts();
      expect(controller.users.length, 2);
    });

    // 15. Batch query chunking
    test('Scenario 15: UserService.chunkList chunks 75 numbers into [30, 30, 15]', () {
      final numbers = List.generate(75, (i) => '+9190000000${i.toString().padLeft(2, '0')}');
      final chunks = UserService.chunkList(numbers, 30);

      expect(chunks.length, 3);
      expect(chunks[0].length, 30);
      expect(chunks[1].length, 30);
      expect(chunks[2].length, 15);
      expect(chunks[0].first, '+919000000000');
      expect(chunks[2].last, '+919000000074');
    });
  });

  group('ContactsScreen Widget State Tests', () {
    testWidgets('Renders Permission Denied state with Grant button', (tester) async {
      final controller = ContactsController(
        contactService: MockContactService(
          mockPermissionStatus: PermissionStatus.denied,
          mockRequestResultStatus: PermissionStatus.denied,
        ),
        userService: MockUserService(),
        authService: MockAuthService(mockUid: 'self'),
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(home: ContactsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Permission Required'), findsOneWidget);
      expect(
        find.text('Contacts permission is required to find your friends on ConnectCall.'),
        findsOneWidget,
      );
      expect(find.text('Grant Permission'), findsOneWidget);
    });

    testWidgets('Renders Permission Permanently Denied state with Open Settings button',
        (tester) async {
      final controller = ContactsController(
        contactService: MockContactService(
          mockPermissionStatus: PermissionStatus.permanentlyDenied,
        ),
        userService: MockUserService(),
        authService: MockAuthService(mockUid: 'self'),
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(home: ContactsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Permission Needed'), findsOneWidget);
      expect(
        find.text('Contacts permission is permanently denied. Please enable it from Settings.'),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('Renders Empty state when no registered contacts found', (tester) async {
      final controller = ContactsController(
        contactService: MockContactService(
          mockPermissionStatus: PermissionStatus.granted,
          mockContacts: [],
        ),
        userService: MockUserService(registeredUsers: []),
        authService: MockAuthService(mockUid: 'self'),
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(home: ContactsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No registered contacts found.'), findsOneWidget);
      expect(
        find.text('None of your phone contacts are registered on ConnectCall yet.'),
        findsOneWidget,
      );
      expect(find.text('Refresh Contacts'), findsOneWidget);
    });

    testWidgets('Renders Network Error state with Retry button', (tester) async {
      final controller = ContactsController(
        contactService: MockContactService(
          mockPermissionStatus: PermissionStatus.granted,
          mockContacts: [
            const DeviceContact(displayName: 'Test', phoneNumbers: ['+91 98765 43210']),
          ],
        ),
        userService: MockUserService(throwNetwork: true),
        authService: MockAuthService(mockUid: 'self'),
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(home: ContactsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network Error'), findsOneWidget);
      expect(find.text('Network error. Please check your connection.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Renders matched users and handles call button taps', (tester) async {
      final callService = MockZegoCallService();
      final controller = ContactsController(
        zegoCallService: callService,
        contactService: MockContactService(
          mockPermissionStatus: PermissionStatus.granted,
          mockContacts: [
            const DeviceContact(displayName: 'Rahul Contact', phoneNumbers: ['09876543210']),
          ],
        ),
        userService: MockUserService(registeredUsers: [userRahul]),
        authService: MockAuthService(mockUid: 'self'),
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          home: const ContactsScreen(),
          getPages: AppPages.pages,
        ),
      );
      await tester.pumpAndSettle();

      // Displays saved device contact name as title and registered name in subtitle
      expect(find.text('Rahul Contact'), findsOneWidget);
      expect(find.textContaining('Rahul Sharma'), findsOneWidget);

      // Contact card displays Audio and Video call buttons, but 3-dots menu is removed
      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);

      // Tap audio call
      await tester.tap(find.byIcon(Icons.call_rounded));
      await tester.pumpAndSettle();
      expect(callService.lastAudioTarget?.uid, 'u_rahul');

      // Tap video call
      await tester.tap(find.byIcon(Icons.videocam_rounded));
      await tester.pumpAndSettle();
      expect(callService.lastVideoTarget?.uid, 'u_rahul');

      // Tap contact name opens Contact Details screen
      await tester.tap(find.text('Rahul Contact'));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.contactDetails);
    });
  });
}
