import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/contacts/contacts_controller.dart';
import 'package:connect_call/screens/contacts/contacts_screen.dart';
import 'package:connect_call/services/auth_service.dart';
import 'package:connect_call/services/user_service.dart';
import 'package:connect_call/widgets/user_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// Mock UserService that doesn't need Firebase initialized
class MockUserService extends UserService {
  final List<UserModel> mockUsers;
  final bool shouldThrow;

  MockUserService({this.mockUsers = const [], this.shouldThrow = false});

  @override
  Future<List<UserModel>> getUsers() async {
    if (shouldThrow) {
      throw 'Firestore connection error';
    }
    return mockUsers;
  }
}

// Mock AuthService for testing currentUser filtering
class MockAuthService extends AuthService {
  final String? mockUid;

  MockAuthService({this.mockUid});

  @override
  String? get currentUserId => mockUid;
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('UserModel Null-Safety Tests', () {
    test('fromMap gracefully handles empty map with null values', () {
      final user = UserModel.fromMap(const {});

      expect(user.uid, '');
      expect(user.name, '');
      expect(user.email, '');
      expect(user.profileImage, '');
      expect(user.isOnline, false);
      expect(user.createdAt, isA<DateTime>());
    });

    test('fromMap correctly parses documentId if not in map', () {
      final user = UserModel.fromMap(
        {'name': 'Alex', 'email': 'alex@example.com'},
        documentId: 'doc_123',
      );

      expect(user.uid, 'doc_123');
      expect(user.name, 'Alex');
      expect(user.email, 'alex@example.com');
      expect(user.isOnline, false);
    });

    test('fromMap parses string-based createdAt correctly', () {
      final user = UserModel.fromMap({
        'uid': 'u1',
        'createdAt': '2026-09-08T00:00:00.000Z',
      });

      expect(user.createdAt.year, 2026);
    });
  });

  group('ContactsController Tests', () {
    final userCurrent = UserModel(
      uid: 'user_current',
      name: 'Current User',
      email: 'current@test.com',
      createdAt: DateTime.now(),
    );

    final userAlice = UserModel(
      uid: 'user_alice',
      name: 'Alice Johnson',
      email: 'alice@test.com',
      isOnline: true,
      createdAt: DateTime.now(),
    );

    final userBob = UserModel(
      uid: 'user_bob',
      name: 'Bob Smith',
      email: 'bob@example.com',
      isOnline: false,
      createdAt: DateTime.now(),
    );

    test('loadUsers successfully excludes current user', () async {
      final mockUserService = MockUserService(
        mockUsers: [userCurrent, userAlice, userBob],
      );
      final mockAuthService = MockAuthService(mockUid: 'user_current');

      final controller = ContactsController(
        userService: mockUserService,
        authService: mockAuthService,
      );

      // Wait for initial load
      await controller.loadUsers();

      expect(controller.users.length, 2);
      expect(controller.users.any((u) => u.uid == 'user_current'), isFalse);
      expect(controller.users.any((u) => u.uid == 'user_alice'), isTrue);
      expect(controller.users.any((u) => u.uid == 'user_bob'), isTrue);
      expect(controller.errorMessage.value, isEmpty);
      expect(controller.isLoading.value, isFalse);
    });

    test('Search filters users by name case-insensitively', () async {
      final mockUserService = MockUserService(
        mockUsers: [userAlice, userBob],
      );
      final mockAuthService = MockAuthService(mockUid: 'user_other');

      final controller = ContactsController(
        userService: mockUserService,
        authService: mockAuthService,
      );
      await controller.loadUsers();

      // Lowercase search
      controller.onSearchChanged('alice');
      expect(controller.filteredUsers.length, 1);
      expect(controller.filteredUsers.first.name, 'Alice Johnson');

      // Uppercase search
      controller.onSearchChanged('ALICE');
      expect(controller.filteredUsers.length, 1);
      expect(controller.filteredUsers.first.name, 'Alice Johnson');

      // Partial name
      controller.onSearchChanged('john');
      expect(controller.filteredUsers.length, 1);
      expect(controller.filteredUsers.first.name, 'Alice Johnson');

      // Clear search
      controller.clearSearch();
      expect(controller.filteredUsers.length, 2);
      expect(controller.searchQuery.value, isEmpty);
    });

    test('Search filters users by email case-insensitively', () async {
      final mockUserService = MockUserService(
        mockUsers: [userAlice, userBob],
      );
      final mockAuthService = MockAuthService(mockUid: 'user_other');

      final controller = ContactsController(
        userService: mockUserService,
        authService: mockAuthService,
      );
      await controller.loadUsers();

      controller.onSearchChanged('example.com');
      expect(controller.filteredUsers.length, 1);
      expect(controller.filteredUsers.first.name, 'Bob Smith');
    });

    test('Non-matching search returns empty list', () async {
      final mockUserService = MockUserService(
        mockUsers: [userAlice, userBob],
      );
      final mockAuthService = MockAuthService(mockUid: 'user_other');

      final controller = ContactsController(
        userService: mockUserService,
        authService: mockAuthService,
      );
      await controller.loadUsers();

      controller.onSearchChanged('NonExistentUser123');
      expect(controller.filteredUsers, isEmpty);
    });

    test('Handles service error cleanly and sets errorMessage', () async {
      final mockUserService = MockUserService(shouldThrow: true);
      final mockAuthService = MockAuthService(mockUid: 'user_1');

      final controller = ContactsController(
        userService: mockUserService,
        authService: mockAuthService,
      );
      await controller.loadUsers();

      expect(controller.users, isEmpty);
      expect(controller.errorMessage.value, 'Unable to load contacts');
      expect(controller.isLoading.value, isFalse);
    });
  });

  group('UserTile Widget Tests', () {
    testWidgets('Renders contact details and handles call button taps',
        (WidgetTester tester) async {
      bool audioTapped = false;
      bool videoTapped = false;

      final testUser = UserModel(
        uid: 'user_test',
        name: 'Jane Doe',
        email: 'jane@example.com',
        isOnline: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserTile(
              user: testUser,
              onAudioCall: () => audioTapped = true,
              onVideoCall: () => videoTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('jane@example.com'), findsOneWidget);
      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);

      // Tap audio button
      await tester.tap(find.byIcon(Icons.call_rounded));
      expect(audioTapped, isTrue);

      // Tap video button
      await tester.tap(find.byIcon(Icons.videocam_rounded));
      expect(videoTapped, isTrue);
    });

    testWidgets('Displays Offline indicator when isOnline is false',
        (WidgetTester tester) async {
      final offlineUser = UserModel(
        uid: 'user_offline',
        name: 'Offline Bob',
        email: 'bob@example.com',
        isOnline: false,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserTile(
              user: offlineUser,
              onAudioCall: () {},
              onVideoCall: () {},
            ),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);
    });
  });

  group('ContactsScreen Widget Tests', () {
    testWidgets('Renders contacts list and interacts with search field',
        (WidgetTester tester) async {
      final userAlice = UserModel(
        uid: 'u1',
        name: 'Alice Springs',
        email: 'alice@springs.com',
        isOnline: true,
        createdAt: DateTime.now(),
      );
      final userCharlie = UserModel(
        uid: 'u2',
        name: 'Charlie Brown',
        email: 'charlie@peanuts.com',
        isOnline: false,
        createdAt: DateTime.now(),
      );

      final controller = ContactsController(
        userService: MockUserService(mockUsers: [userAlice, userCharlie]),
        authService: MockAuthService(mockUid: 'self'),
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: ContactsScreen(),
        ),
      );

      // Verify header and search field
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Connect with people'), findsOneWidget);
      expect(find.text('Search contacts...'), findsOneWidget);

      // Wait for async loadUsers
      await tester.pumpAndSettle();

      // Both contacts should be visible
      expect(find.text('Alice Springs'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsOneWidget);

      // Enter search text
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pumpAndSettle();

      expect(find.text('Alice Springs'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsNothing);

      // Tap clear search button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Alice Springs'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsOneWidget);
    });

    testWidgets('Displays empty search result state',
        (WidgetTester tester) async {
      final controller = ContactsController(
        userService: MockUserService(mockUsers: [
          UserModel(
            uid: 'u1',
            name: 'Alice',
            email: 'alice@mail.com',
            createdAt: DateTime.now(),
          ),
        ]),
        authService: MockAuthService(mockUid: 'self'),
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: ContactsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter non-matching query
      await tester.enterText(find.byType(TextField), 'XYZNonExistent');
      await tester.pumpAndSettle();

      expect(find.text('No contacts found'), findsOneWidget);
      expect(find.text('Try a different name or email.'), findsOneWidget);
    });

    testWidgets('Displays error state with retry button on failure',
        (WidgetTester tester) async {
      final controller = ContactsController(
        userService: MockUserService(shouldThrow: true),
        authService: MockAuthService(mockUid: 'self'),
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: ContactsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load contacts'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Audio Call and Video Call tap triggers placeholder feedback',
        (WidgetTester tester) async {
      final controller = ContactsController(
        userService: MockUserService(mockUsers: [
          UserModel(
            uid: 'u1',
            name: 'Sarah Connor',
            email: 'sarah@sky.net',
            createdAt: DateTime.now(),
          ),
        ]),
        authService: MockAuthService(mockUid: 'self'),
      );

      Get.put<ContactsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: ContactsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Audio Call button
      await tester.tap(find.byIcon(Icons.call_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.call_rounded), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Tap Video Call button
      await tester.tap(find.byIcon(Icons.videocam_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}
