import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/call_model.dart';
import '../services/auth_service.dart';
import '../services/contact_service.dart';

/// CallHistoryTile renders a single call record item in the Call History list.
class CallHistoryTile extends StatelessWidget {
  final CallModel call;
  final String? currentUserId;
  final VoidCallback? onRedial;
  final VoidCallback? onTap;
  final bool showBorder;

  const CallHistoryTile({
    super.key,
    required this.call,
    this.currentUserId,
    this.onRedial,
    this.onTap,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final cardColor = AppTheme.cardColorOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);
    final dividerColor = AppTheme.dividerColorOf(context);

    final effectiveUid = currentUserId ?? AuthService().currentUserId;
    final otherRegisteredName = call.getOtherUserName(effectiveUid);
    final otherName = ContactService.instance.resolveDisplayName(
      phoneNumber: call.phoneNumber,
      registeredName: otherRegisteredName,
      fallback: otherRegisteredName,
    );
    final otherPhoto = call.getOtherUserPhoto(effectiveUid);
    final initial = otherName.isNotEmpty ? otherName[0].toUpperCase() : 'U';

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap ?? onRedial,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: showBorder
                ? Border.all(color: dividerColor.withValues(alpha: isDark ? 0.8 : 0.6))
                : null,
          ),
          child: Row(
            children: [
              // 1. User Avatar
              _buildAvatar(context, otherPhoto, initial),

              const SizedBox(width: 14),

              // 2. Center info: Name, Direction & Type Icon, Date/Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Participant name
                    Text(
                      otherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: call.isMissed
                            ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
                            : textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Direction icon + Call Type + Date
                    Row(
                      children: [
                        _buildDirectionIcon(),
                        const SizedBox(width: 4),
                        Icon(
                          call.isVideo
                              ? Icons.videocam_rounded
                              : Icons.phone_rounded,
                          size: 13,
                          color: _getStatusColor(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            call.formattedDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 3. Status Badge or Duration
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusOrDuration(context),
                  const SizedBox(height: 4),
                  if (onRedial != null)
                    IconButton(
                      icon: Icon(
                        call.isVideo
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      onPressed: onRedial,
                      tooltip: call.isVideo ? 'Video Call' : 'Audio Call',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String? photoUrl, String initial) {
    final isDark = AppTheme.isDarkMode(context);
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 23,
        backgroundColor: AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {},
        child: Text(
          initial,
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: call.isMissed
              ? [Colors.red.shade300, Colors.red.shade600]
              : [AppTheme.primaryLight, AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionIcon() {
    if (call.isMissed) {
      return Icon(
        Icons.call_missed_rounded,
        size: 14,
        color: Colors.red.shade600,
      );
    } else if (call.isOutgoing) {
      return Icon(
        Icons.call_made_rounded,
        size: 14,
        color: const Color(0xFF10B981), // Emerald green
      );
    } else {
      return Icon(
        Icons.call_received_rounded,
        size: 14,
        color: const Color(0xFF3B82F6), // Blue
      );
    }
  }

  Color _getStatusColor(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    if (call.isMissed) return isDark ? Colors.red.shade400 : Colors.red.shade600;
    if (call.isRejected) return isDark ? Colors.orange.shade400 : Colors.orange.shade700;
    if (call.isFailed) return isDark ? Colors.red.shade400 : Colors.red.shade600;
    return AppTheme.textSecondaryOf(context);
  }

  Widget _buildStatusOrDuration(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    if (call.isMissed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.red.shade900.withValues(alpha: 0.35)
              : Colors.red.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Missed',
          style: TextStyle(
            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (call.isRejected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.orange.shade900.withValues(alpha: 0.35)
              : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Rejected',
          style: TextStyle(
            color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (call.isBusy) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.orange.shade900.withValues(alpha: 0.35)
              : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Busy',
          style: TextStyle(
            color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (call.isDisconnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Disconnected',
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (call.isFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.red.shade900.withValues(alpha: 0.35)
              : Colors.red.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Failed',
          style: TextStyle(
            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Ended or Connected: display formatted duration
    return Text(
      call.formattedDuration,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondaryOf(context),
      ),
    );
  }
}
