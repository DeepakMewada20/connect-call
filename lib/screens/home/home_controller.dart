import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

class HomeController extends GetxController {
  final AuthService _authService;

  HomeController({AuthService? authService})
      : _authService = authService ?? AuthService();

  // Bottom navigation tab state
  final RxInt selectedIndex = 0.obs;

  void changeTab(int index) {
    selectedIndex.value = index;
  }

  // Dynamic greeting based on current local time
  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning 👋';
    } else if (hour < 17) {
      return 'Good Afternoon 👋';
    } else {
      return 'Good Evening 👋';
    }
  }

  // User display name with safe fallback
  String get userName {
    final user = _authService.getCurrentUser();
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    if (user?.email != null && user!.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }
    return 'User';
  }

  String get userInitial => userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

  // Informative placeholder actions for Phase 3
  void onAudioCallTap() {
    Get.snackbar(
      'Audio Call',
      'Audio calling will be available soon in Phase 4.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.primaryColor,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }

  void onVideoCallTap() {
    Get.snackbar(
      'Video Call',
      'Video calling will be available soon in Phase 4.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.primaryColor,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      Get.snackbar(
        'Logout Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }
}
