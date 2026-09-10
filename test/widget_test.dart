import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:connect_call/core/constants/app_constants.dart';
import 'package:connect_call/routes/app_pages.dart';
import 'package:connect_call/routes/app_routes.dart';
import 'package:connect_call/screens/auth/login/login_screen.dart';
import 'package:connect_call/screens/auth/name/name_screen.dart';
import 'package:connect_call/screens/auth/otp/otp_screen.dart';
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
    expect(find.text('Enter your phone number to sign in or create an account.'),
        findsOneWidget);
  });

  testWidgets('Phone Login screen renders fields, country code, and Send OTP button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.login,
        getPages: AppPages.pages,
      ),
    );

    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('🇮🇳'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Send OTP'), findsOneWidget);
  });

  testWidgets('Phone Login validation triggers on empty or invalid phone number',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.login,
        getPages: AppPages.pages,
      ),
    );

    // Tap Send OTP with empty field
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Phone number is required'), findsOneWidget);

    // Enter short phone number
    await tester.enterText(find.byType(TextFormField), '98765');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid 10-digit mobile number'), findsOneWidget);
  });

  testWidgets('OTP screen renders verification input and Verify button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.otp,
        getPages: AppPages.pages,
      ),
    );

    expect(find.byType(OtpScreen), findsOneWidget);
    expect(find.text('Verify Phone Number'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Verify & Continue'), findsOneWidget);
  });

  testWidgets('Name screen renders input and validates empty name',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.name,
        getPages: AppPages.pages,
      ),
    );

    expect(find.byType(NameScreen), findsOneWidget);
    expect(find.text("What's your name?"), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);

    // Tap Continue with empty name
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your name'), findsOneWidget);
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
    expect(find.text('Favorite Contacts'), findsOneWidget);
    expect(find.text('No Favorite Contacts'), findsOneWidget);
    expect(find.text('Recent Calls'), findsOneWidget);
    expect(find.text('No recent calls'), findsOneWidget);

    // Verify Bottom Navigation tabs (Home, Contacts, Profile)
    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Contacts'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsOneWidget);

    // Tap Contacts Tab
    await tester.tap(find.widgetWithText(NavigationDestination, 'Contacts'));
    await tester.pumpAndSettle();
    expect(find.text('Connect with people'), findsOneWidget);
    expect(find.text('Search contacts or phone number'), findsOneWidget);

    // Tap Profile Tab
    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    // Switch back to Home Tab
    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    expect(find.text('Favorite Contacts'), findsOneWidget);
  });
}
