import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zego_uikit/zego_uikit.dart';
import '../../services/zego_call_service.dart';

/// CustomScreenSharingButton provides a robust, direct toggle for screen sharing
/// in video calls. It bypasses the buggy check in Zego's default toggle button
/// and ensures both starting and stopping screen sharing work reliably every time.
class CustomScreenSharingButton extends StatelessWidget {
  final Size? buttonSize;
  final Size? iconSize;

  const CustomScreenSharingButton({
    super.key,
    this.buttonSize,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final bSize = buttonSize ?? const Size(48, 48);
    final iSize = iconSize?.width ?? 24.0;

    return Obx(() {
      final isSharing = ZegoCallService.instance.isScreenSharing.value;

      return ValueListenableBuilder<bool>(
        valueListenable: ZegoUIKit().getScreenSharingStateNotifier(),
        builder: (context, uikitSharing, _) {
          final active = isSharing || uikitSharing;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              if (active) {
                await ZegoCallService.instance.stopScreenSharing();
              } else {
                await ZegoCallService.instance.startScreenSharing();
              }
            },
            child: Container(
              width: bSize.width,
              height: bSize.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? Colors.redAccent.withValues(alpha: 0.9)
                    : Colors.white24,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                active
                    ? Icons.stop_screen_share_rounded
                    : Icons.screen_share_rounded,
                color: Colors.white,
                size: iSize,
              ),
            ),
          );
        },
      );
    });
  }
}
