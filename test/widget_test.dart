import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:connect_call/core/constants/app_constants.dart';
import 'package:connect_call/routes/app_pages.dart';
import 'package:connect_call/routes/app_routes.dart';
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

    // Verify unauthenticated user is navigated to LoginScreen placeholder
    expect(find.text('Login Screen Placeholder'), findsOneWidget);
  });

  testWidgets(
      'Splash screen navigates to Home when user is authenticated',
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

    // Verify authenticated user is navigated to HomeScreen placeholder
    expect(find.text('Home Screen Placeholder'), findsOneWidget);
  });
}
