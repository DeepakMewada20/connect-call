import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/user_model.dart';

class UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onAudioCall;
  final VoidCallback? onVideoCall;
  final bool isSelf;
  final bool isBlocked;
  final bool isFavorite;
  final String? badgeText;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onEditContact;
  final VoidCallback? onDeleteContact;
  final VoidCallback? onToggleBlock;

  const UserTile({
    super.key,
    required this.user,
    this.onAudioCall,
    this.onVideoCall,
    this.isSelf = false,
    this.isBlocked = false,
    this.isFavorite = false,
    this.badgeText,
    this.onToggleFavorite,
    this.onEditContact,
    this.onDeleteContact,
    this.onToggleBlock,
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

            // User Name and Status / Phone Number
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
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
                      ),
                      if (isFavorite) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                      ],
                      if (isBlocked) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            'Blocked',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ] else if (badgeText != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
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
                      if (user.phoneNumber.isNotEmpty) ...[
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
                            user.phoneNumber,
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

            // Call Action Buttons or Self/Blocked State
            if (isSelf)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: const Text(
                  'This is your account',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              )
            else if (isBlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Blocked',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              )
            else ...[
              _buildActionButton(
                icon: Icons.call_rounded,
                tooltip: 'Start Audio Call',
                color: const Color(0xFF10B981),
                onTap: onAudioCall ?? () {},
                isEnabled: onAudioCall != null,
              ),
              const SizedBox(width: 6),
              _buildActionButton(
                icon: Icons.videocam_rounded,
                tooltip: 'Start Video Call',
                color: AppTheme.primaryColor,
                onTap: onVideoCall ?? () {},
                isEnabled: onVideoCall != null,
              ),
            ],

            // Contact / User Management Overflow Menu
            if (!isSelf &&
                (onToggleFavorite != null ||
                    onEditContact != null ||
                    onDeleteContact != null ||
                    onToggleBlock != null)) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (action) {
                  switch (action) {
                    case 'favorite':
                      onToggleFavorite?.call();
                      break;
                    case 'edit':
                      onEditContact?.call();
                      break;
                    case 'delete':
                      onDeleteContact?.call();
                      break;
                    case 'block':
                      onToggleBlock?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (onToggleFavorite != null)
                    PopupMenuItem(
                      value: 'favorite',
                      child: Row(
                        children: [
                          Icon(
                            isFavorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 20,
                            color: isFavorite
                                ? const Color(0xFFF59E0B)
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Text(isFavorite
                              ? 'Remove from Favorites'
                              : 'Add to Favorites'),
                        ],
                      ),
                    ),
                  if (onEditContact != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 20, color: AppTheme.textSecondary),
                          SizedBox(width: 10),
                          Text('Edit Contact'),
                        ],
                      ),
                    ),
                  if (onDeleteContact != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 20, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text(
                            'Delete Contact',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  if (onToggleBlock != null)
                    PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(
                            isBlocked
                                ? Icons.lock_open_rounded
                                : Icons.block_rounded,
                            size: 20,
                            color: isBlocked ? Colors.green : Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isBlocked ? 'Unblock User' : 'Block User',
                            style: TextStyle(
                              color:
                                  isBlocked ? Colors.green : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
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
