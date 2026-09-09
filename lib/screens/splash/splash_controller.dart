import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../routes/app_routes.dart';
import '../../services/user_service.dart';

class SplashController extends GetxController {
  // Optional authStateChecker for unit testing / mocking
  final Future<bool> Function()? authStateChecker;
  final UserService _userService;

  SplashController({
    this.authStateChecker,
    UserService? userService,
  }) : _userService = userService ?? UserService();

  // Status message for splash screen loading state
  final RxString statusMessage = 'Initializing...'.obs;

  @override
  void onReady() {
    super.onReady();
    _initializeAppAndNavigate();
  }

  Future<void> _initializeAppAndNavigate() async {
    try {
      statusMessage.value = 'Connecting...';

      // Ensure minimal splash display duration for smooth UX transition
      // while performing the auth check concurrently.
      final results = await Future.wait([
        _checkAuthenticationState(),
        Future.delayed(
            const Duration(milliseconds: AppConstants.splashMinDurationMs)),
      ]);

      final bool isAuthenticated = results[0] as bool;

      if (isAuthenticated) {
        // If authStateChecker is injected (e.g. for unit tests), bypass Firestore lookup
        if (authStateChecker != null) {
          Get.offAllNamed(AppRoutes.home);
          return;
        }

        // Verify that authenticated user has a complete Firestore profile
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final profile = await _userService.getUser(user.uid);
          if (profile != null && profile.name.trim().isNotEmpty) {
            Get.offAllNamed(AppRoutes.home);
          } else {
            Get.offAllNamed(
              AppRoutes.name,
              arguments: {
                'uid': user.uid,
                'phoneNumber': user.phoneNumber,
              },
            );
          }
        } else {
          Get.offAllNamed(AppRoutes.login);
        }
      } else {
        Get.offAllNamed(AppRoutes.login);
      }
    } catch (e, stackTrace) {
      debugPrint('Error during splash initialization: $e');
      debugPrint('$stackTrace');
      // Graceful fallback: Navigate to login rather than getting stuck indefinitely
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<bool> _checkAuthenticationState() async {
    if (authStateChecker != null) {
      return authStateChecker!();
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      return user != null;
    } catch (e) {
      debugPrint('FirebaseAuth check error: $e');
      return false;
    }
  }
}
