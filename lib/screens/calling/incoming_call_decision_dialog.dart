import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../models/pending_call_model.dart';
import '../../services/zego_call_service.dart';

/// IncomingCallDecisionDialog renders the unified incoming-call Accept / Reject screen
/// when launched from an incoming call push notification body tap.
///
/// Features:
/// - Single source of truth: converges directly into existing ZEGOCLOUD accept/reject logic
/// - Displays caller name, avatar, and call type (Audio / Video)
/// - Green Accept button -> existing ZegoCallService accept logic
/// - Red Reject button -> existing ZegoCallService reject logic & SQLite call history update
/// - Safe 60-second expiration countdown: automatically closes and clears state if expired
class IncomingCallDecisionDialog extends StatefulWidget {
  final PendingCallModel pendingCall;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const IncomingCallDecisionDialog({
    super.key,
    required this.pendingCall,
    this.onAccept,
    this.onReject,
  });

  static Future<void> show(BuildContext context, PendingCallModel call) async {
    if (call.isExpired) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      routeSettings: const RouteSettings(name: '/incoming_call_decision'),
      builder: (dialogContext) => IncomingCallDecisionDialog(pendingCall: call),
    );
  }

  @override
  State<IncomingCallDecisionDialog> createState() => _IncomingCallDecisionDialogState();
}

class _IncomingCallDecisionDialogState extends State<IncomingCallDecisionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;
  Timer? _countdownTimer;
  int _remainingSeconds = 60;
  bool _isActionTaken = false;

  @override
  void initState() {
    super.initState();

    _remainingSeconds = widget.pendingCall.expiresAt.difference(DateTime.now()).inSeconds;
    if (_remainingSeconds <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleReject();
      });
      return;
    }

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (!Get.testMode) {
      _rippleController.repeat(reverse: true);
    }

    _rippleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeInOut),
    );

    if (!Get.testMode) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _handleReject();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant IncomingCallDecisionDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingCall.callId != oldWidget.pendingCall.callId ||
        widget.onReject != oldWidget.onReject ||
        widget.onAccept != oldWidget.onAccept) {
      _isActionTaken = false;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _countdownTimer?.cancel();

    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (widget.onAccept != null) {
      widget.onAccept!();
    } else {
      await ZegoCallService.instance.acceptCallFromNotification(widget.pendingCall);
    }
  }

  Future<void> _handleReject() async {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _countdownTimer?.cancel();

    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (widget.onReject != null) {
      widget.onReject!();
    } else {
      await ZegoCallService.instance.rejectCallFromNotification(widget.pendingCall);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.pendingCall.isVideo;
    final callerName = widget.pendingCall.callerName.isNotEmpty
        ? widget.pendingCall.callerName
        : 'Unknown Caller';

    return PopScope(
      canPop: false, // Prevent accidental back button dismissal without decision
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF1E293B),
                Color(0xFF090D16),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 32),

                // Call type indicator badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Center: Avatar with animated ripple + Name
                Column(
                  children: [
                    AnimatedBuilder(
                      animation: _rippleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _rippleAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: 0.6),
                                  const Color(0xFF6366F1).withValues(alpha: 0.3),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                callerName.isNotEmpty ? callerName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      callerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ringing... ($_remainingSeconds s)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),

                // Bottom: Reject & Accept action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 🔴 REJECT BUTTON
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            key: const Key('incoming_call_reject_button'),
                            onTap: _handleReject,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.shade600,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Decline',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // 🟢 ACCEPT BUTTON
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            key: const Key('incoming_call_accept_button'),
                            onTap: _handleAccept,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF10B981), // Emerald green
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
