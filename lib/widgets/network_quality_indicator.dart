import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/network_quality_service.dart';

/// A lightweight, real-time call network quality indicator widget.
///
/// States:
/// - 🟢 Good (strong signal, Emerald color)
/// - 🟡 Fair (medium signal, Amber color)
/// - 🔴 Poor (weak signal, Red color)
/// - Initial: Neutral connecting indicator (never prematurely shows "Poor")
class NetworkQualityIndicator extends StatelessWidget {
  final NetworkQualityService? service;
  final bool showLabel;
  final EdgeInsetsGeometry padding;

  const NetworkQualityIndicator({
    super.key,
    this.service,
    this.showLabel = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    final qualityService = service ?? NetworkQualityService.instance;

    return Obx(() {
      final quality = qualityService.currentQuality.value;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: quality != null
                ? quality.color.withValues(alpha: 0.35)
                : Colors.white12,
            width: 1,
          ),
          boxShadow: [
            if (quality != null)
              BoxShadow(
                color: quality.color.withValues(alpha: 0.15),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildContent(quality),
        ),
      );
    });
  }

  Widget _buildContent(NetworkQualityLevel? quality) {
    if (quality == null) {
      // Safe initial state: neutral indicator while awaiting first RTC packet
      return const Row(
        key: ValueKey('connecting_state'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.signal_cellular_alt,
            color: Colors.white38,
            size: 14,
          ),
          SizedBox(width: 5),
          Text(
            'Checking...',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      key: ValueKey(quality),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          quality.icon,
          color: quality.color,
          size: 15,
        ),
        if (showLabel) ...[
          const SizedBox(width: 5),
          Text(
            quality.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              shadows: [
                Shadow(
                  color: quality.color.withValues(alpha: 0.8),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
