import 'package:flutter/material.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:zego_express_engine/zego_express_engine.dart';
import 'package:zego_uikit/zego_uikit.dart';

/// Normalized 3-state call network quality levels.
enum NetworkQualityLevel {
  good,
  fair,
  poor,
}

extension NetworkQualityLevelExtension on NetworkQualityLevel {
  String get label {
    switch (this) {
      case NetworkQualityLevel.good:
        return 'Good';
      case NetworkQualityLevel.fair:
        return 'Fair';
      case NetworkQualityLevel.poor:
        return 'Poor';
    }
  }

  Color get color {
    switch (this) {
      case NetworkQualityLevel.good:
        return const Color(0xFF10B981); // Emerald Green
      case NetworkQualityLevel.fair:
        return const Color(0xFFF59E0B); // Amber / Warning
      case NetworkQualityLevel.poor:
        return const Color(0xFFEF4444); // Rose Red / Error
    }
  }

  IconData get icon {
    switch (this) {
      case NetworkQualityLevel.good:
        return Icons.signal_cellular_alt;
      case NetworkQualityLevel.fair:
        return Icons.signal_cellular_alt_2_bar;
      case NetworkQualityLevel.poor:
        return Icons.signal_cellular_alt_1_bar;
    }
  }
}

/// NetworkQualityService observes ongoing ZEGOCLOUD call network metrics
/// in real-time and normalizes them into Good, Fair, and Poor states.
///
/// Architecture & Safety:
/// - Pure passive observer: does NOT reconnect, interrupt, or control the call.
/// - Directly hooks into ZEGOCLOUD's RTC callbacks via [ZegoUIKitExpressEventInterface].
/// - Zero external polling, zero test-file downloads.
/// - Lightweight reactive state via GetX ([Rx]).
/// - Strictly cleans up event listeners when the call ends to prevent leaks.
class NetworkQualityService extends ZegoUIKitExpressEventInterface {
  NetworkQualityService._();
  static final NetworkQualityService instance = NetworkQualityService._();

  /// Reactive current quality level.
  /// Null indicates initial connecting state before the first valid RTC metric arrives.
  final Rx<NetworkQualityLevel?> currentQuality = Rx<NetworkQualityLevel?>(null);

  /// Whether active monitoring is in progress.
  final RxBool isMonitoring = false.obs;

  /// Map raw ZEGOCLOUD [ZegoStreamQualityLevel] to 3 normalized states.
  static NetworkQualityLevel? mapQualityLevel(ZegoStreamQualityLevel level) {
    switch (level) {
      case ZegoStreamQualityLevel.Excellent:
      case ZegoStreamQualityLevel.Good:
        return NetworkQualityLevel.good;
      case ZegoStreamQualityLevel.Medium:
        return NetworkQualityLevel.fair;
      case ZegoStreamQualityLevel.Bad:
      case ZegoStreamQualityLevel.Die:
        return NetworkQualityLevel.poor;
      case ZegoStreamQualityLevel.Unknown:
        return null;
    }
  }

  /// Combine upstream and downstream qualities into a single call rating.
  /// Prioritizes the degraded link to give users accurate status.
  static NetworkQualityLevel? combineQuality(
    ZegoStreamQualityLevel upstream,
    ZegoStreamQualityLevel downstream,
  ) {
    final up = mapQualityLevel(upstream);
    final down = mapQualityLevel(downstream);

    if (up == null && down == null) return null;
    if (up == null) return down;
    if (down == null) return up;

    if (up == NetworkQualityLevel.poor || down == NetworkQualityLevel.poor) {
      return NetworkQualityLevel.poor;
    }
    if (up == NetworkQualityLevel.fair || down == NetworkQualityLevel.fair) {
      return NetworkQualityLevel.fair;
    }
    return NetworkQualityLevel.good;
  }

  /// Start monitoring network quality for an active call.
  void startMonitoring() {
    if (isMonitoring.value) return;

    isMonitoring.value = true;
    currentQuality.value = null; // Neutral / initial state until first metric

    try {
      ZegoUIKit().registerExpressEvent(this);
      debugPrint('[NetworkQualityService] Registered ZEGOCLOUD express event listener.');
    } catch (e) {
      debugPrint('[NetworkQualityService] Error registering express event listener: $e');
    }
  }

  /// Stop monitoring and clean up listeners on call end.
  void stopMonitoring() {
    if (!isMonitoring.value) {
      currentQuality.value = null;
      return;
    }

    try {
      ZegoUIKit().unregisterExpressEvent(this);
      debugPrint('[NetworkQualityService] Unregistered ZEGOCLOUD express event listener.');
    } catch (e) {
      debugPrint('[NetworkQualityService] Error unregistering express event listener: $e');
    } finally {
      isMonitoring.value = false;
      currentQuality.value = null;
    }
  }

  // --- ZEGOCLOUD Express Event Callbacks ---

  @override
  void onNetworkQuality(
    String userID,
    ZegoStreamQualityLevel upstreamQuality,
    ZegoStreamQualityLevel downstreamQuality,
  ) {
    if (!isMonitoring.value) return;

    final quality = combineQuality(upstreamQuality, downstreamQuality);
    if (quality != null) {
      currentQuality.value = quality;
    }
  }

  @override
  void onPublisherQualityUpdate(
    String streamID,
    ZegoPublishStreamQuality quality,
  ) {
    if (!isMonitoring.value) return;

    final mapped = mapQualityLevel(quality.level);
    if (mapped != null) {
      currentQuality.value = mapped;
    }
  }

  @override
  void onPlayerQualityUpdate(
    String streamID,
    ZegoPlayStreamQuality quality,
  ) {
    if (!isMonitoring.value) return;

    final mapped = mapQualityLevel(quality.level);
    if (mapped != null) {
      currentQuality.value = mapped;
    }
  }

  /// Test helper to simulate network quality states in tests.
  @visibleForTesting
  void updateQualityForTesting(NetworkQualityLevel? level) {
    currentQuality.value = level;
  }
}
