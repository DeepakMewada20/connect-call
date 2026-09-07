import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/zego_call_service.dart';

class ProfileController extends GetxController {
  final UserService _userService;
  final AuthService _authService;
  final ZegoCallService? zegoCallService;
  final String? currentUserIdOverride;

  ProfileController({
    UserService? userService,
    AuthService? authService,
    this.zegoCallService,
    this.currentUserIdOverride,
  })  : _userService = userService ?? UserService(),
        _authService = authService ?? AuthService();

  ZegoCallService get activeCallService =>
      zegoCallService ?? ZegoCallService.instance;

  // Reactive state
  final Rxn<UserModel> user = Rxn<UserModel>();
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isLoggingOut = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserProfile();
  }

  // Retrieve authenticated user profile from Cloud Firestore
  Future<void> loadUserProfile() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final String? currentUid =
          currentUserIdOverride ?? _authService.currentUserId;

      if (currentUid == null || currentUid.isEmpty) {
        final authUser = _authService.getCurrentUser();
        user.value = UserModel(
          uid: 'user_local',
          name: authUser?.displayName?.isNotEmpty == true
              ? authUser!.displayName!
              : (authUser?.email?.split('@').first ?? 'User'),
          email: authUser?.email ?? 'user@example.com',
          profileImage: authUser?.photoURL ?? '',
          isOnline: false,
          createdAt: DateTime.now(),
        );
        return;
      }

      final fetchedUser = await _userService.getUser(currentUid);

      if (fetchedUser != null) {
        user.value = fetchedUser;
      } else {
        // Fallback to Firebase Auth user data if Firestore document is missing
        final authUser = _authService.getCurrentUser();
        user.value = UserModel(
          uid: currentUid,
          name: authUser?.displayName?.isNotEmpty == true
              ? authUser!.displayName!
              : (authUser?.email?.split('@').first ?? 'User'),
          email: authUser?.email ?? '',
          profileImage: authUser?.photoURL ?? '',
          isOnline: true,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      errorMessage.value = 'Unable to load profile. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  // Display confirmation dialog before logging out
  void showLogoutConfirmation() {
    Get.defaultDialog(
      title: 'Logout',
      titleStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
      middleText: 'Are you sure you want to logout?',
      middleTextStyle: const TextStyle(
        fontSize: 14,
        color: AppTheme.textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      radius: 16,
      textConfirm: 'Logout',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red.shade600,
      textCancel: 'Cancel',
      cancelTextColor: AppTheme.textPrimary,
      onCancel: () {
        Get.back();
      },
      onConfirm: () {
        Get.back(); // Dismiss dialog
        logout();
      },
    );
  }

  // Perform sign out and navigate to login screen
  Future<void> logout() async {
    isLoggingOut.value = true;
    try {
      // Deinitialize ZEGOCLOUD CallKit first
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
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isLoggingOut.value = false;
    }
  }

  // Navigate to edit profile screen and refresh upon return
  Future<void> navigateToEditProfile() async {
    final result = await Get.toNamed(
      AppRoutes.editProfile,
      arguments: user.value,
    );
    if (result == true) {
      await loadUserProfile();
    }
  }
}
