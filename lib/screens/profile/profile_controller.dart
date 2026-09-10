import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/user_service.dart';
import '../../services/zego_call_service.dart';

class ProfileController extends GetxController {
  final UserService _userService;
  final AuthService _authService;
  final ThemeService _themeService;
  final ZegoCallService? zegoCallService;
  final String? currentUserIdOverride;

  ProfileController({
    UserService? userService,
    AuthService? authService,
    ThemeService? themeService,
    this.zegoCallService,
    this.currentUserIdOverride,
  })  : _userService = userService ?? UserService(),
        _authService = authService ?? AuthService(),
        _themeService = themeService ?? ThemeService.instance;

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
              : (authUser?.phoneNumber ?? 'User'),
          phoneNumber: authUser?.phoneNumber ?? '',
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
              : (authUser?.phoneNumber ?? 'User'),
          phoneNumber: authUser?.phoneNumber ?? '',
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
    final isDark = Get.isDarkMode;
    Get.defaultDialog(
      title: 'Logout',
      titleStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
      ),
      middleText: 'Are you sure you want to logout?',
      middleTextStyle: TextStyle(
        fontSize: 14,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
      ),
      backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      radius: 16,
      textConfirm: 'Logout',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red.shade600,
      textCancel: 'Cancel',
      cancelTextColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
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

  // --- Theme Management ---
  Rx<ThemeMode> get themeMode => _themeService.themeMode;
  String get currentThemeName => _themeService.currentThemeName;

  Future<void> setThemeMode(ThemeMode mode) async {
    await _themeService.setThemeMode(mode);
  }

  void showThemeSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Obx(() {
          final currentMode = _themeService.themeMode.value;

          return AlertDialog(
            backgroundColor: AppTheme.surfaceColorOf(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.palette_outlined,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Choose Theme',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThemeOption(
                  context: dialogContext,
                  title: 'System Default',
                  subtitle: 'Follow device system appearance',
                  icon: Icons.brightness_auto_rounded,
                  mode: ThemeMode.system,
                  isSelected: currentMode == ThemeMode.system,
                ),
                const SizedBox(height: 10),
                _buildThemeOption(
                  context: dialogContext,
                  title: 'Light Theme',
                  subtitle: 'Clean, bright Slate appearance',
                  icon: Icons.light_mode_rounded,
                  mode: ThemeMode.light,
                  isSelected: currentMode == ThemeMode.light,
                ),
                const SizedBox(height: 10),
                _buildThemeOption(
                  context: dialogContext,
                  title: 'Dark Theme',
                  subtitle: 'Sleek, eye-friendly dark appearance',
                  icon: Icons.dark_mode_rounded,
                  mode: ThemeMode.dark,
                  isSelected: currentMode == ThemeMode.dark,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
  }) {
    final activeColor = AppTheme.primaryColor;
    return InkWell(
      key: Key('theme_option_${mode.name}'),
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        setThemeMode(mode);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? activeColor
                : AppTheme.dividerColorOf(context).withValues(alpha: 0.6),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? activeColor.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.15)
                    : AppTheme.dividerColorOf(context).withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : AppTheme.textSecondaryOf(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? activeColor : AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: activeColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
