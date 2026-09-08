import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/user_model.dart';

class UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onAudioCall;
  final VoidCallback onVideoCall;

  const UserTile({
    super.key,
    required this.user,
    required this.onAudioCall,
    required this.onVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // User Avatar with Online Indicator
            _buildAvatarWithStatus(),
            const SizedBox(width: 14),

            // User Name and Status / Email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.name.isNotEmpty ? user.name : 'Unknown User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: user.isOnline
                              ? const Color(0xFF10B981)
                              : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: user.isOnline
                              ? const Color(0xFF10B981)
                              : AppTheme.textSecondary,
                        ),
                      ),
                      if (user.email.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Call Action Buttons
            _buildActionButton(
              icon: Icons.call_rounded,
              tooltip: 'Start Audio Call',
              color: const Color(0xFF10B981),
              onTap: onAudioCall,
              isEnabled: true,
            ),
            const SizedBox(width: 6),
            _buildActionButton(
              icon: Icons.videocam_rounded,
              tooltip: 'Start Video Call',
              color: AppTheme.primaryColor,
              onTap: onVideoCall,
              isEnabled: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWithStatus() {
    final String initial =
        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';
    final bool hasImage = user.profileImage.trim().isNotEmpty;

    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
          backgroundImage: hasImage ? NetworkImage(user.profileImage) : null,
          onBackgroundImageError:
              hasImage ? (error, stackTrace) {} : null,
          child: !hasImage
              ? Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: user.isOnline
                  ? const Color(0xFF10B981)
                  : Colors.grey.shade400,
              border: Border.all(
                color: Colors.white,
                width: 2.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isEnabled
            ? color.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: isEnabled ? color : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }
}
