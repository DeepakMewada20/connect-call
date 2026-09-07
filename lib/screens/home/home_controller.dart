import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/zego_call_service.dart';

class HomeController extends GetxController {
  final AuthService _authService;
  final ZegoCallService? zegoCallService;

  HomeController({
    AuthService? authService,
    this.zegoCallService,
  })  : _authService = authService ?? AuthService();

  ZegoCallService get activeCallService =>
      zegoCallService ?? ZegoCallService.instance;

  @override
  void onReady() {
    super.onReady();
    // Initialize ZEGOCLOUD call listener in background when entering home
    if (!Get.testMode) {
      activeCallService.initZegoCallService();
    }
  }

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

  // Quick call actions on Home dashboard
  void onAudioCallTap() {
    Get.snackbar(
      'Audio Call',
      'Select any contact from the Contacts tab to start a 1-to-1 audio call.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }

  void onVideoCallTap() {
    Get.snackbar(
      'Video Call',
      'Video calling will be available in Phase 7. Audio calling is now active!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.primaryColor,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> logout() async {
    try {
      // Deinitialize ZEGOCLOUD call listener first to prevent stale sessions
      if (!Get.testMode) {
        await activeCallService.uninit();
      }
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
