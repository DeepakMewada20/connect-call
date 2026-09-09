import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect_call/core/theme/app_theme.dart';
import 'package:connect_call/models/user_model.dart';
import 'package:connect_call/screens/profile/profile_controller.dart';
import 'package:connect_call/screens/profile/profile_screen.dart';
import 'package:connect_call/services/auth_service.dart';
import 'package:connect_call/services/theme_service.dart';
import 'package:connect_call/services/user_service.dart';

// Mock UserService to supply test user without Firebase
class MockUserService extends UserService {
  final UserModel? mockUser;
  MockUserService({this.mockUser});

  @override
  Future<UserModel?> getUser(String uid) async {
    return mockUser ??
        UserModel(
          uid: uid,
          name: 'Deepak Test',
          phoneNumber: '+919876543210',
          profileImage: '',
          isOnline: true,
          createdAt: DateTime(2025, 1, 1),
        );
  }
}

// Mock AuthService to supply test user ID without Firebase
class MockAuthService extends AuthService {
  @override
  String? get currentUserId => 'test_uid_123';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  group('ThemeService Unit Tests', () {
    test('Defaults to ThemeMode.system when no preference is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ThemeService();
      await service.init(preferences: prefs);

      expect(service.themeMode.value, equals(ThemeMode.system));
      expect(service.currentThemeName, equals('System Default'));
    });

    test('Restores ThemeMode.dark when stored in preferences', () async {
      SharedPreferences.setMockInitialValues({
        ThemeService.themePreferenceKey: ThemeService.themeModeDark,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ThemeService();
      await service.init(preferences: prefs);

      expect(service.themeMode.value, equals(ThemeMode.dark));
      expect(service.currentThemeName, equals('Dark'));
    });

    test('Restores ThemeMode.light when stored in preferences', () async {
      SharedPreferences.setMockInitialValues({
        ThemeService.themePreferenceKey: ThemeService.themeModeLight,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ThemeService();
      await service.init(preferences: prefs);

      expect(service.themeMode.value, equals(ThemeMode.light));
      expect(service.currentThemeName, equals('Light'));
    });

    test('setThemeMode updates reactive state, currentThemeName, and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ThemeService();
      await service.init(preferences: prefs);

      // Switch to Dark
      await service.setThemeMode(ThemeMode.dark);
      expect(service.themeMode.value, equals(ThemeMode.dark));
      expect(service.currentThemeName, equals('Dark'));
      expect(prefs.getString(ThemeService.themePreferenceKey), equals('dark'));

      // Switch to Light
      await service.setThemeMode(ThemeMode.light);
      expect(service.themeMode.value, equals(ThemeMode.light));
      expect(service.currentThemeName, equals('Light'));
      expect(prefs.getString(ThemeService.themePreferenceKey), equals('light'));

      // Switch to System
      await service.setThemeMode(ThemeMode.system);
      expect(service.themeMode.value, equals(ThemeMode.system));
      expect(service.currentThemeName, equals('System Default'));
      expect(prefs.getString(ThemeService.themePreferenceKey), equals('system'));
    });
  });

  group('AppTheme Palette & Mode Tests', () {
    test('lightTheme has Brightness.light and correct base colors', () {
      final light = AppTheme.lightTheme;
      expect(light.brightness, equals(Brightness.light));
      expect(light.scaffoldBackgroundColor, equals(AppTheme.backgroundColor));
      expect(light.primaryColor, equals(AppTheme.primaryColor));
      expect(light.cardColor, equals(AppTheme.cardColor));
    });

    test('darkTheme has Brightness.dark and dark slate colors', () {
      final dark = AppTheme.darkTheme;
      expect(dark.brightness, equals(Brightness.dark));
      expect(dark.scaffoldBackgroundColor, equals(AppTheme.darkBackgroundColor));
      expect(dark.cardColor, equals(AppTheme.darkCardColor));
      expect(dark.dividerColor, equals(AppTheme.darkDividerColor));
    });

    testWidgets('AppTheme context helpers dynamically resolve light and dark colors', (tester) async {
      Color? lightBg;
      Color? darkBg;
      Color? lightCard;
      Color? darkCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.lightTheme,
            child: Builder(
              builder: (context) {
                lightBg = AppTheme.backgroundColorOf(context);
                lightCard = AppTheme.cardColorOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(lightBg, equals(AppTheme.backgroundColor));
      expect(lightCard, equals(AppTheme.cardColor));

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.darkTheme,
            child: Builder(
              builder: (context) {
                darkBg = AppTheme.backgroundColorOf(context);
                darkCard = AppTheme.cardColorOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(darkBg, equals(AppTheme.darkBackgroundColor));
      expect(darkCard, equals(AppTheme.darkCardColor));
    });
  });

  group('Profile Screen Theme Selector Widget Tests', () {
    testWidgets('Profile Screen renders Theme tile with active theme label', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final themeService = ThemeService();
      await themeService.init(preferences: prefs);
      ThemeService.setInstance(themeService);

      final controller = ProfileController(
        userService: MockUserService(),
        authService: MockAuthService(),
        themeService: themeService,
        currentUserIdOverride: 'test_uid_123',
      );
      Get.put<ProfileController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode.value,
          home: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Theme Tile
      await tester.scrollUntilVisible(find.byKey(const Key('profile_theme_tile')), 100);
      await tester.pumpAndSettle();

      // Check that Theme tile is rendered in Settings section
      expect(find.byKey(const Key('profile_theme_tile')), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('System Default'), findsWidgets);
    });

    testWidgets('Tapping Theme tile opens Choose Theme dialog with 3 options', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final themeService = ThemeService();
      await themeService.init(preferences: prefs);
      ThemeService.setInstance(themeService);

      final controller = ProfileController(
        userService: MockUserService(),
        authService: MockAuthService(),
        themeService: themeService,
        currentUserIdOverride: 'test_uid_123',
      );
      Get.put<ProfileController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode.value,
          home: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Theme Tile and Tap
      await tester.scrollUntilVisible(find.byKey(const Key('profile_theme_tile')), 100);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_theme_tile')));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Choose Theme'), findsOneWidget);
      expect(find.byKey(const Key('theme_option_system')), findsOneWidget);
      expect(find.byKey(const Key('theme_option_light')), findsOneWidget);
      expect(find.byKey(const Key('theme_option_dark')), findsOneWidget);

      // Tap Dark Theme option
      await tester.tap(find.byKey(const Key('theme_option_dark')));
      await tester.pumpAndSettle();

      // Verify dialog is closed and themeMode changed to dark
      expect(find.text('Choose Theme'), findsNothing);
      expect(themeService.themeMode.value, equals(ThemeMode.dark));
      expect(themeService.currentThemeName, equals('Dark'));
      expect(prefs.getString(ThemeService.themePreferenceKey), equals('dark'));

      // Tap Theme Tile again
      await tester.tap(find.byKey(const Key('profile_theme_tile')));
      await tester.pumpAndSettle();

      // Tap Light Theme option
      await tester.tap(find.byKey(const Key('theme_option_light')));
      await tester.pumpAndSettle();

      // Verify changed to light
      expect(themeService.themeMode.value, equals(ThemeMode.light));
      expect(themeService.currentThemeName, equals('Light'));
      expect(prefs.getString(ThemeService.themePreferenceKey), equals('light'));
    });
  });
}
