import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pending_call_model.dart';

/// Delegate signatures for testability
typedef SavePendingCallDelegate = Future<void> Function(PendingCallModel call);
typedef GetPendingCallDelegate = Future<PendingCallModel?> Function();
typedef ClearPendingCallDelegate = Future<void> Function();

/// PendingCallManager manages temporary pending incoming call state
/// across foreground, background, and terminated lifecycle transitions.
///
/// Features:
/// - In-memory and test-mockable state
/// - Persistent SharedPreferences backing across background isolates and cold launch
/// - Safe 60-second automatic expiration checking
/// - Zero leak: stale calls are automatically purged
class PendingCallManager {
  static const String _prefKey = 'connect_call_pending_call_json';

  static PendingCallManager? _instance;
  static PendingCallManager get instance => _instance ??= PendingCallManager();

  @visibleForTesting
  static void setInstance(PendingCallManager manager) {
    _instance = manager;
  }

  final SavePendingCallDelegate? saveDelegate;
  final GetPendingCallDelegate? getDelegate;
  final ClearPendingCallDelegate? clearDelegate;

  PendingCallManager({
    this.saveDelegate,
    this.getDelegate,
    this.clearDelegate,
  });

  PendingCallModel? _inMemoryPendingCall;

  /// Tracks notification action ('accept', 'reject', or 'body') during cold launch
  String? launchAction;

  final Rx<PendingCallModel?> currentPendingCall = Rx<PendingCallModel?>(null);

  /// Saves an incoming call payload to pending state
  Future<void> savePendingCall(PendingCallModel call) async {
    _inMemoryPendingCall = call;
    currentPendingCall.value = call;

    if (!Get.testMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKey, jsonEncode(call.toMap()));
      } catch (e) {
        debugPrint('[PendingCallManager] Error persisting pending call: $e');
      }
    }

    if (saveDelegate != null) {
      await saveDelegate!(call);
      return;
    }
  }

  /// Retrieves the active pending call if still valid (< 60s TTL)
  Future<PendingCallModel?> getPendingCall() async {
    if (getDelegate != null) {
      final call = await getDelegate!();
      if (call != null && !call.isExpired) {
        currentPendingCall.value = call;
        return call;
      }
      return null;
    }

    if (_inMemoryPendingCall != null) {
      if (_inMemoryPendingCall!.isExpired) {
        debugPrint('[CALL PUSH] Pending call ${_inMemoryPendingCall!.callId} expired. Purging.');
        await clearPendingCall();
        return null;
      }
      return _inMemoryPendingCall;
    }

    if (!Get.testMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = prefs.getString(_prefKey);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final call = PendingCallModel.fromMap(map);
          if (!call.isExpired) {
            _inMemoryPendingCall = call;
            currentPendingCall.value = call;
            return call;
          } else {
            await prefs.remove(_prefKey);
          }
        }
      } catch (e) {
        debugPrint('[PendingCallManager] Error reading from prefs: $e');
      }
    }

    return null;
  }

  /// Clears the pending call state
  Future<void> clearPendingCall() async {
    _inMemoryPendingCall = null;
    currentPendingCall.value = null;

    if (!Get.testMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefKey);
      } catch (e) {
        debugPrint('[PendingCallManager] Error clearing prefs: $e');
      }
    }

    if (clearDelegate != null) {
      await clearDelegate!();
    }
  }

  /// Checks whether a valid pending call currently exists
  bool hasValidPendingCall() {
    return _inMemoryPendingCall != null && !_inMemoryPendingCall!.isExpired;
  }
}
