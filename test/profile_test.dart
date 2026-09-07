import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/profile/edit_profile_controller.dart';
import 'package:connect_call/screens/profile/edit_profile_screen.dart';
import 'package:connect_call/screens/profile/profile_controller.dart';
import 'package:connect_call/screens/profile/profile_screen.dart';
import 'package:connect_call/services/auth_service.dart';
import 'package:connect_call/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

// Mock UserService
class MockProfileUserService extends UserService {
  final UserModel? mockUser;
  final bool shouldThrow;
  String? lastUpdatedName;
  String? lastUpdatedUid;

  MockProfileUserService({this.mockUser, this.shouldThrow = false});

  @override
  Future<UserModel?> getUser(String uid) async {
    if (shouldThrow) throw 'Firestore error';
    return mockUser;
  }

  @override
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    String? profileImage,
  }) async {
    if (shouldThrow) throw 'Update error';
    lastUpdatedUid = uid;
    lastUpdatedName = name;
  }
}

// Mock AuthService
class MockProfileAuthService extends AuthService {
  final String? mockUid;
  final String? mockName;
  final String? mockEmail;
  bool logoutCalled = false;
  String? updatedDisplayName;

  MockProfileAuthService({
    this.mockUid = 'user_123',
    this.mockName = 'Deepak Mewada',
    this.mockEmail = 'deepak@example.com',
  });

  @override
  String? get currentUserId => mockUid;

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<void> updateDisplayName(String name) async {
    updatedDisplayName = name;
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('ProfileController Unit Tests', () {
    test('loadUserProfile successfully populates user from UserService',
        () async {
      final sampleUser = UserModel(
        uid: 'user_123',
        name: 'Deepak Mewada',
        email: 'deepak@example.com',
        profileImage: '',
        isOnline: true,
        createdAt: DateTime.now(),
      );

      final mockUserService = MockProfileUserService(mockUser: sampleUser);
      final mockAuthService = MockProfileAuthService(mockUid: 'user_123');

      final controller = ProfileController(
        userService: mockUserService,
        authService: mockAuthService,
        currentUserIdOverride: 'user_123',
      );

      await controller.loadUserProfile();

      expect(controller.user.value, isNotNull);
      expect(controller.user.value?.name, 'Deepak Mewada');
      expect(controller.user.value?.email, 'deepak@example.com');
      expect(controller.user.value?.isOnline, isTrue);
      expect(controller.errorMessage.value, isEmpty);
      expect(controller.isLoading.value, isFalse);
    });

    test('loadUserProfile sets error message on service failure', () async {
      final mockUserService = MockProfileUserService(shouldThrow: true);
      final mockAuthService = MockProfileAuthService(mockUid: 'user_123');

      final controller = ProfileController(
        userService: mockUserService,
        authService: mockAuthService,
        currentUserIdOverride: 'user_123',
      );

      await controller.loadUserProfile();

      expect(controller.user.value, isNull);
      expect(controller.errorMessage.value,
          'Unable to load profile. Please try again.');
      expect(controller.isLoading.value, isFalse);
    });

    test('logout invokes AuthService.logout', () async {
      final mockUserService = MockProfileUserService();
      final mockAuthService = MockProfileAuthService(mockUid: 'user_123');

      final controller = ProfileController(
        userService: mockUserService,
        authService: mockAuthService,
        currentUserIdOverride: 'user_123',
      );

      await controller.logout();
      expect(mockAuthService.logoutCalled, isTrue);
    });
  });

  group('EditProfileController Unit Tests', () {
    final sampleUser = UserModel(
      uid: 'user_123',
      name: 'Deepak Mewada',
      email: 'deepak@example.com',
      profileImage: '',
      isOnline: true,
      createdAt: DateTime.now(),
    );

    test('Initializes name controller with current user name', () {
      final controller = EditProfileController(
        userService: MockProfileUserService(),
        authService: MockProfileAuthService(),
        initialUser: sampleUser,
      );
      controller.onInit();

      expect(controller.nameController.text, 'Deepak Mewada');
      expect(controller.currentUser.email, 'deepak@example.com');
    });

    test('Rejects empty or whitespace-only name', () {
      final controller = EditProfileController(
        userService: MockProfileUserService(),
        authService: MockProfileAuthService(),
        initialUser: sampleUser,
      );
      controller.onInit();

      controller.nameController.text = '';
      expect(controller.validateName(), isFalse);
      expect(controller.nameError.value, 'Name cannot be empty');

      controller.nameController.text = '   ';
      expect(controller.validateName(), isFalse);
      expect(controller.nameError.value, 'Name cannot be empty');

      controller.nameController.text = 'A';
      expect(controller.validateName(), isFalse);
      expect(controller.nameError.value, 'Name must be at least 2 characters');

      controller.nameController.text = 'Rahul';
      expect(controller.validateName(), isTrue);
      expect(controller.nameError.value, isEmpty);
    });
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('Renders profile details, status, and logout button',
        (WidgetTester tester) async {
      final sampleUser = UserModel(
        uid: 'user_123',
        name: 'Deepak Mewada',
        email: 'deepak@example.com',
        profileImage: '',
        isOnline: true,
        createdAt: DateTime.now(),
      );

      final controller = ProfileController(
        userService: MockProfileUserService(mockUser: sampleUser),
        authService: MockProfileAuthService(mockUid: 'user_123'),
        currentUserIdOverride: 'user_123',
      );

      Get.put<ProfileController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Deepak Mewada'), findsWidgets);
      expect(find.text('deepak@example.com'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Verify Account and Settings sections
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('User ID'), findsOneWidget);
      expect(find.text('user_123'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);

      // Tap Logout to verify confirmation dialog appears
      await tester.ensureVisible(find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to logout?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to logout?'), findsNothing);
      expect(find.text('Deepak Mewada'), findsWidgets);
    });
  });

  group('EditProfileScreen Widget Tests', () {
    testWidgets('Renders fields, rejects empty name, and saves valid name',
        (WidgetTester tester) async {
      final sampleUser = UserModel(
        uid: 'user_123',
        name: 'Deepak Mewada',
        email: 'deepak@example.com',
        profileImage: '',
        isOnline: true,
        createdAt: DateTime.now(),
      );

      final mockUserService = MockProfileUserService();
      final mockAuthService = MockProfileAuthService();

      final controller = EditProfileController(
        userService: mockUserService,
        authService: mockAuthService,
        initialUser: sampleUser,
      );

      Get.put<EditProfileController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/profile',
          getPages: [
            GetPage(
              name: '/profile',
              page: () => const Scaffold(body: Text('Profile Screen')),
            ),
            GetPage(
              name: '/edit',
              page: () => const EditProfileScreen(),
            ),
          ],
        ),
      );
      Get.toNamed('/edit');
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Email cannot be changed directly.'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Clear name and tap Save Changes
      await tester.enterText(find.byType(TextField).first, '');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Name cannot be empty'), findsOneWidget);
      expect(mockUserService.lastUpdatedName, isNull);

      // Enter valid name and tap Save Changes
      await tester.enterText(find.byType(TextField).first, 'Deepak Updated');
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(mockUserService.lastUpdatedName, 'Deepak Updated');
      expect(mockAuthService.updatedDisplayName, 'Deepak Updated');

      // Wait for snackbar timer
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}
