import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'profile_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure ProfileController is registered
    final ProfileController controller =
        Get.isRegistered<ProfileController>()
            ? Get.find<ProfileController>()
            : Get.put(ProfileController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColorOf(context),
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value && controller.user.value == null) {
            return _buildLoadingState(context);
          }

          if (controller.errorMessage.isNotEmpty &&
              controller.user.value == null) {
            return _buildErrorState(controller, context);
          }

          final currentUser = controller.user.value;

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            backgroundColor: AppTheme.surfaceColorOf(context),
            onRefresh: controller.loadUserProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                children: [
                  // Profile Header Card: Avatar, Name, Phone Number, Status
                  _buildProfileHeader(controller, currentUser, context),

                  const SizedBox(height: 20),

                  // Edit Profile Button
                  _buildEditProfileButton(controller),

                  const SizedBox(height: 28),

                  // Account Information Section
                  _buildAccountSection(currentUser, context),

                  const SizedBox(height: 20),

                  // Settings & Logout Section
                  _buildSettingsSection(controller, context),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // Profile Header with Avatar, Name, Phone Number, and Online/Offline Badge
  Widget _buildProfileHeader(
      ProfileController controller, dynamic currentUser, BuildContext context) {
    final String displayName =
        currentUser?.name.isNotEmpty == true ? currentUser!.name : 'User';
    final String contactInfo = currentUser?.phoneNumber ?? '';
    final String initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final bool isOnline = currentUser?.isOnline ?? false;
    final bool hasImage =
        currentUser?.profileImage.trim().isNotEmpty == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardColorOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColorOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDarkMode(context) ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with Online Status Indicator
          Stack(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.12),
                backgroundImage:
                    hasImage ? NetworkImage(currentUser!.profileImage) : null,
                onBackgroundImageError:
                    hasImage ? (error, stackTrace) {} : null,
                child: !hasImage
                    ? Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline
                        ? const Color(0xFF10B981)
                        : Colors.grey.shade400,
                    border: Border.all(
                      color: AppTheme.cardColorOf(context),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // User Name
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),

          const SizedBox(height: 4),

          // User Phone Number
          if (contactInfo.isNotEmpty) ...[
            Text(
              contactInfo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 12),

          // Online / Offline Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : (AppTheme.isDarkMode(context)
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline
                        ? const Color(0xFF10B981)
                        : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOnline
                        ? const Color(0xFF10B981)
                        : (AppTheme.isDarkMode(context)
                            ? AppTheme.darkTextSecondary
                            : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Edit Profile Action Button
  Widget _buildEditProfileButton(ProfileController controller) {
    return ElevatedButton.icon(
      onPressed: controller.navigateToEditProfile,
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text(
        'Edit Profile',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // Account Information Section
  Widget _buildAccountSection(dynamic currentUser, BuildContext context) {
    return Material(
      color: AppTheme.cardColorOf(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.dividerColorOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Text(
                'Account',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondaryOf(context),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _buildInfoTile(
              context: context,
              icon: Icons.shield_outlined,
              title: 'Account Status',
              subtitle: 'Verified & Active',
              trailingColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  // Settings Section: Theme toggle, App info and Logout
  Widget _buildSettingsSection(ProfileController controller, BuildContext context) {
    return Material(
      color: AppTheme.cardColorOf(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.dividerColorOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondaryOf(context),
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Theme Settings Tile
            Obx(() {
              final themeName = controller.currentThemeName;
              final IconData themeIcon;
              switch (controller.themeMode.value) {
                case ThemeMode.light:
                  themeIcon = Icons.light_mode_rounded;
                  break;
                case ThemeMode.dark:
                  themeIcon = Icons.dark_mode_rounded;
                  break;
                case ThemeMode.system:
                  themeIcon = Icons.brightness_auto_rounded;
                  break;
              }

              return ListTile(
                key: const Key('profile_theme_tile'),
                onTap: () => controller.showThemeSelectionDialog(context),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    themeIcon,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Theme',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                subtitle: Text(
                  themeName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        themeName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textSecondaryOf(context),
                      size: 20,
                    ),
                  ],
                ),
              );
            }),

            Divider(height: 1, indent: 56, color: AppTheme.dividerColorOf(context)),

            // App Version Tile
            _buildInfoTile(
              context: context,
              icon: Icons.info_outline_rounded,
              title: AppConstants.appName,
              subtitle: 'Version 1.0.0',
            ),

            Divider(height: 1, indent: 56, color: AppTheme.dividerColorOf(context)),

            // Logout Tile
            ListTile(
              onTap: controller.isLoggingOut.value
                  ? null
                  : () => controller.showLogoutConfirmation(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.red.shade50.withValues(
                      alpha: AppTheme.isDarkMode(context) ? 0.15 : 1.0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.red.shade400,
                  size: 20,
                ),
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade400,
                ),
              ),
              subtitle: Text(
                'Sign out from your account',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondaryOf(context)),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondaryOf(context),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    Color? trailingColor,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryOf(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: trailingColor ?? AppTheme.textSecondaryOf(context),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: TextStyle(
              color: AppTheme.textSecondaryOf(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ProfileController controller, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.errorMessage.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: controller.loadUserProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
