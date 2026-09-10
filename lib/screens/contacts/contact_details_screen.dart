import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_number_util.dart';
import 'contact_details_controller.dart';

class ContactDetailsScreen extends StatelessWidget {
  const ContactDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ContactDetailsController>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColorOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textPrimaryOf(context),
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() {
            final isFav = controller.isFavorite;
            return IconButton(
              icon: Icon(
                isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFav ? const Color(0xFFF59E0B) : AppTheme.textSecondaryOf(context),
                size: 26,
              ),
              tooltip: isFav ? 'Remove Favorite' : 'Add to Favorites',
              onPressed: controller.toggleFavorite,
            );
          }),
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              color: AppTheme.textPrimaryOf(context),
              size: 22,
            ),
            tooltip: 'Share Contact',
            onPressed: controller.shareContact,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          final targetUser = controller.user.value;
          final currentName = controller.displayName.value;
          final currentPhone = controller.phoneNumber.value;
          final isBlk = controller.isBlocked;
          final formattedPhone = PhoneNumberUtil.formatForDisplay(currentPhone);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Contact Avatar
                _buildAvatar(context, controller),
                const SizedBox(height: 18),

                // 2. Name & Registered Alias
                Text(
                  currentName.isNotEmpty ? currentName : 'Unknown Contact',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                    letterSpacing: -0.5,
                  ),
                ),
                if (targetUser != null &&
                    targetUser.name.trim().isNotEmpty &&
                    targetUser.name.trim() != currentName.trim()) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Registered as: ${targetUser.name}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // 3. Phone Number Badge
                InkWell(
                  onTap: controller.copyPhoneNumber,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColorOf(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dividerColorOf(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 15,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedPhone.isNotEmpty ? formattedPhone : 'No Phone Number',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Blocked Status Banner if blocked
                if (isBlk) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.block_rounded, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Contact is currently Blocked',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 5. Quick Calling Action Chips (Audio & Video)
                _buildCallingActions(context, controller),

                const SizedBox(height: 24),

                // 6. Communication Actions Card
                _buildSectionHeader(context, 'Communication'),
                const SizedBox(height: 8),
                _buildActionCard(
                  context,
                  children: [
                    _buildActionTile(
                      context,
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: const Color(0xFF2563EB),
                      title: 'Message',
                      subtitle: 'Open default SMS application',
                      onTap: controller.openSms,
                    ),
                    _buildDivider(context),
                    _buildActionTile(
                      context,
                      icon: Icons.chat_rounded,
                      iconColor: const Color(0xFF10B981),
                      title: 'WhatsApp',
                      subtitle: 'Start WhatsApp chat',
                      onTap: controller.openWhatsApp,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 7. Contact Details Management Card
                _buildSectionHeader(context, 'Contact Actions'),
                const SizedBox(height: 8),
                _buildActionCard(
                  context,
                  children: [
                    _buildActionTile(
                      context,
                      icon: Icons.copy_rounded,
                      iconColor: const Color(0xFF64748B),
                      title: 'Copy Phone Number',
                      subtitle: formattedPhone,
                      onTap: controller.copyPhoneNumber,
                    ),
                    _buildDivider(context),
                    _buildActionTile(
                      context,
                      icon: Icons.share_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      title: 'Share Contact',
                      subtitle: 'Send contact info via share sheet',
                      onTap: controller.shareContact,
                    ),
                    if (controller.deviceContact.value != null) ...[
                      _buildDivider(context),
                      _buildActionTile(
                        context,
                        icon: Icons.edit_outlined,
                        iconColor: AppTheme.primaryColor,
                        title: 'Edit Contact',
                        subtitle: 'Update name or number on phone',
                        onTap: () => controller.showEditContactDialog(context),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                // 8. Privacy & Danger Zone
                _buildSectionHeader(context, 'Privacy & Manage'),
                const SizedBox(height: 8),
                _buildActionCard(
                  context,
                  children: [
                    _buildActionTile(
                      context,
                      icon: isBlk ? Icons.lock_open_rounded : Icons.block_rounded,
                      iconColor: isBlk ? const Color(0xFF10B981) : Colors.redAccent,
                      title: isBlk ? 'Unblock Contact' : 'Block Contact',
                      subtitle: isBlk
                          ? 'Allow calls from this contact'
                          : 'Prevent this contact from calling you',
                      onTap: () => controller.confirmToggleBlock(context),
                    ),
                    if (controller.deviceContact.value != null) ...[
                      _buildDivider(context),
                      _buildActionTile(
                        context,
                        icon: Icons.delete_outline_rounded,
                        iconColor: Colors.red,
                        title: 'Delete Contact',
                        subtitle: 'Remove from device phonebook',
                        textColor: Colors.red,
                        onTap: () => controller.confirmDeleteContact(context),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, ContactDetailsController controller) {
    final user = controller.user.value;
    final name = controller.displayName.value;
    final hasImage = user != null && user.profileImage.trim().isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                user.profileImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(initial),
              )
            : _buildInitialAvatar(initial),
      ),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildCallingActions(BuildContext context, ContactDetailsController controller) {
    final isBlk = controller.isBlocked;

    return Row(
      children: [
        // Audio Call Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isBlk ? () => controller.makeAudioCall() : controller.makeAudioCall,
            icon: const Icon(Icons.call_rounded, size: 20),
            label: const Text(
              'Audio Call',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isBlk ? Colors.grey.shade400 : const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: isBlk ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Video Call Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isBlk ? () => controller.makeVideoCall() : controller.makeVideoCall,
            icon: const Icon(Icons.videocam_rounded, size: 22),
            label: const Text(
              'Video Call',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isBlk ? Colors.grey.shade400 : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: isBlk ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondaryOf(context),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColorOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColorOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDarkMode(context) ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: AppTheme.dividerColorOf(context),
    );
  }
}
