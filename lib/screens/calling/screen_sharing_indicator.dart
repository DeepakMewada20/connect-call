import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/zego_call_service.dart';

/// ScreenSharingIndicator displays an obvious, high-visibility visual indicator
/// when the user is sharing their screen in an active video call.
///
/// Features:
/// - Visual pulse animation (🔴 "Sharing your screen")
/// - Quick-action "Stop" button to terminate screen sharing immediately
/// - Built with GetX reactivity [Obx] to automatically show/hide based on [isScreenSharing]
class ScreenSharingIndicator extends StatefulWidget {
  const ScreenSharingIndicator({super.key});

  @override
  State<ScreenSharingIndicator> createState() => _ScreenSharingIndicatorState();
}

class _ScreenSharingIndicatorState extends State<ScreenSharingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSharing = ZegoCallService.instance.isScreenSharing.value;
      if (!isSharing) {
        if (_animController.isAnimating) {
          _animController.stop();
        }
        return const SizedBox.shrink();
      }

      if (!_animController.isAnimating) {
        _animController.repeat(reverse: true);
      }

      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xDD0F172A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _pulseAnim,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Sharing your screen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        ZegoCallService.instance.stopScreenSharing();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent, width: 1),
                        ),
                        child: const Text(
                          'Stop',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
