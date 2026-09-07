import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:connect_call/core/constants/app_constants.dart';
import 'package:connect_call/routes/app_pages.dart';
import 'package:connect_call/routes/app_routes.dart';
import 'package:connect_call/screens/auth/login/login_screen.dart';
import 'package:connect_call/screens/auth/register/register_screen.dart';
import 'package:connect_call/screens/home/home_screen.dart';
import 'package:connect_call/screens/splash/splash_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
      'Splash screen displays logo, app name, and navigates to Login when unauthenticated',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
      ),
    );

    // Initial frame verify
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text(AppConstants.appTagline), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Advance time past the splash delay to complete all timers
    await tester.pump(
        const Duration(milliseconds: AppConstants.splashMinDurationMs + 500));
    await tester.pumpAndSettle();

    // Verify unauthenticated user is navigated to LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back! Sign in to connect.'), findsOneWidget);
  });

  testWidgets('Login screen renders fields, buttons, and navigation to Register',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.login,
        getPages: AppPages.pages,
      ),
    );

    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    // Ensure Create Account button is scrolled into view and tap
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    // Verify RegisterScreen is pushed
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Create Account'), findsOneWidget);
  });

  testWidgets('Login validation triggers on empty fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.login,
        getPages: AppPages.pages,
      ),
    );

    // Tap Login with empty fields
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    // Verify validation errors appear
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('Register validation triggers on empty/mismatched fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.register,
        getPages: AppPages.pages,
      ),
    );

    // Tap Create Account with empty fields
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('Splash screen navigates to Home when user is authenticated',
      (WidgetTester tester) async {
    // Override SplashController with an authenticated state mock
    Get.put<SplashController>(
      SplashController(authStateChecker: () async => true),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
      ),
    );

    // Advance time past the splash delay
    await tester.pump(
        const Duration(milliseconds: AppConstants.splashMinDurationMs + 500));
    await tester.pumpAndSettle();

    // Verify authenticated user is navigated to HomeScreen
    expect(Get.currentRoute, AppRoutes.home);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
