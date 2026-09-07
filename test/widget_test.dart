import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:connect_call/core/constants/app_constants.dart';
import 'package:connect_call/routes/app_pages.dart';
import 'package:connect_call/routes/app_routes.dart';
import 'package:connect_call/screens/auth/forgot_password/forgot_password_screen.dart';
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
    expect(find.text('Forgot Password?'), findsOneWidget);
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

  testWidgets('Forgot password flow navigates from Login and validates email',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.login,
        getPages: AppPages.pages,
      ),
    );

    // Tap Forgot Password
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    // Verify ForgotPasswordScreen is displayed
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Send Reset Link'), findsOneWidget);

    // Submit with empty email to verify validation
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsOneWidget);

    // Tap Back to Login
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();

    // Verify returned to LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
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

  testWidgets(
      'Home screen renders dashboard and switches bottom navigation tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.home,
        getPages: AppPages.pages,
      ),
    );

    // Initial Dashboard Tab
    expect(find.text('Ready to connect?'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Audio Call'), findsOneWidget);
    expect(find.text('Video Call'), findsOneWidget);
    expect(find.text('Recent Calls'), findsOneWidget);
    expect(find.text('No recent calls'), findsOneWidget);

    // Tap Audio Call quick action to verify no crash and friendly feedback
    await tester.tap(find.text('Audio Call'));
    await tester.pump();
    expect(find.text('Audio calling will be available soon in Phase 4.'),
        findsOneWidget);

    // Wait for snackbar to finish
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Verify Bottom Navigation tabs
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Calls'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Tap Contacts Tab
    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'User directory and search will be available soon in Phase 4.'),
        findsOneWidget);

    // Tap Calls Tab
    await tester.tap(find.text('Calls'));
    await tester.pumpAndSettle();
    expect(find.text('Call History'), findsOneWidget);

    // Tap Profile Tab
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Authentication Status'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    // Switch back to Home Tab
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Actions'), findsOneWidget);
  });
}
