import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/pending_call_model.dart';
import 'pending_call_manager.dart';

typedef NotificationActionHandler = Future<void> Function(String action, PendingCallModel call);

/// Top-level background notification response handler required by flutter_local_notifications
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('[CALL PUSH] notificationTapBackground action: ${notificationResponse.actionId}');
  final payload = notificationResponse.payload;
  if (payload != null && payload.isNotEmpty) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final pendingCall = PendingCallModel.fromMap(map);
      PendingCallManager.instance.savePendingCall(pendingCall);
    } catch (e) {
      debugPrint('[CALL PUSH] Error decoding payload in background: $e');
    }
  }
}

/// CallNotificationService manages high-priority Android incoming call notifications
/// with custom sound/ringtone, category call, full-screen intent, and Accept / Reject actions.
class CallNotificationService {
  static CallNotificationService? _instance;
  static CallNotificationService get instance => _instance ??= CallNotificationService();

  @visibleForTesting
  static void setInstance(CallNotificationService service) {
    _instance = service;
  }

  static const String channelId = 'incoming_calls_v2';
  static const String oldChannelId = 'incoming_calls';
  static const String channelName = 'Incoming Calls';
  static const String channelDescription = 'High-priority channel for incoming audio and video calls';

  static const AndroidNotificationSound callRingtoneSound = RawResourceAndroidNotificationSound('call_ringtone');
  static final Int64List callVibrationPattern = Int64List.fromList([0, 1000, 800, 1000, 800, 1000]);

  static const String actionAccept = 'action_accept';
  static const String actionReject = 'action_reject';

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final NotificationActionHandler? onActionReceived;

  // Custom delegates for unit testing
  final Future<void> Function(PendingCallModel call)? showNotificationDelegate;
  final Future<void> Function(String callId)? dismissNotificationDelegate;

  bool _isInitialized = false;

  CallNotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    this.onActionReceived,
    this.showNotificationDelegate,
    this.dismissNotificationDelegate,
  }) : _notificationsPlugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  /// Initialize local notification plugin and channel settings
  Future<void> initialize({
    void Function(PendingCallModel call)? onNotificationBodyTapped,
    void Function(PendingCallModel call)? onAcceptTapped,
    void Function(PendingCallModel call)? onRejectTapped,
  }) async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationResponse(
            response,
            onBodyTap: onNotificationBodyTapped,
            onAccept: onAcceptTapped,
            onReject: onRejectTapped,
          );
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Create Android Notification Channel with high importance and call ringtone
      final androidNotificationChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: callRingtoneSound,
        enableVibration: true,
        vibrationPattern: callVibrationPattern,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      );

      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        try {
          await androidImplementation.deleteNotificationChannel(channelId: oldChannelId);
        } catch (_) {}
        await androidImplementation.createNotificationChannel(androidNotificationChannel);
      }

      _isInitialized = true;
      debugPrint('[CALL PUSH] CallNotificationService initialized successfully.');

      // Check if application was launched directly by tapping a notification or action
      try {
        final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
        if (details != null && details.didNotificationLaunchApp && details.notificationResponse != null) {
          debugPrint('[CALL PUSH] App launched via notification! Action: ${details.notificationResponse?.actionId}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleNotificationResponse(
              details.notificationResponse!,
              onBodyTap: onNotificationBodyTapped,
              onAccept: onAcceptTapped,
              onReject: onRejectTapped,
            );
          });
        }
      } catch (e) {
        debugPrint('[CALL PUSH] Error reading getNotificationAppLaunchDetails: $e');
      }
    } catch (e) {
      debugPrint('[CALL PUSH] Failed to initialize CallNotificationService: $e');
    }
  }

  void _handleNotificationResponse(
    NotificationResponse response, {
    void Function(PendingCallModel call)? onBodyTap,
    void Function(PendingCallModel call)? onAccept,
    void Function(PendingCallModel call)? onReject,
  }) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final pendingCall = PendingCallModel.fromMap(map);

      // If call is already expired (>60s), do not process
      if (pendingCall.isExpired) {
        debugPrint('[CALL PUSH] Notification clicked but call is expired.');
        dismissNotification(pendingCall.callId);
        return;
      }

      final actionId = response.actionId;
      debugPrint('[CALL PUSH] Notification response actionId: $actionId');

      if (actionId == actionAccept) {
        debugPrint('[CALL PUSH] Accept action clicked from notification.');
        if (onAccept != null) {
          onAccept(pendingCall);
        } else if (onActionReceived != null) {
          onActionReceived!(actionAccept, pendingCall);
        }
      } else if (actionId == actionReject) {
        debugPrint('[CALL PUSH] Reject action clicked from notification.');
        dismissNotification(pendingCall.callId);
        if (onReject != null) {
          onReject(pendingCall);
        } else if (onActionReceived != null) {
          onActionReceived!(actionReject, pendingCall);
        }
      } else {
        // Body tapped: MUST NOT automatically accept!
        debugPrint('[CALL PUSH] Notification body tapped -> opening incoming call screen.');
        if (onBodyTap != null) {
          onBodyTap(pendingCall);
        }
      }
    } catch (e) {
      debugPrint('[CALL PUSH] Error handling notification response: $e');
    }
  }

  /// Displays high-priority incoming call notification
  Future<void> showIncomingCallNotification(PendingCallModel call) async {
    if (showNotificationDelegate != null) {
      await showNotificationDelegate!(call);
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    final int notificationId = call.callId.hashCode.abs();
    final callTypeLabel = call.isVideo ? 'Incoming Video Call' : 'Incoming Audio Call';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      autoCancel: false,
      ongoing: true,
      playSound: true,
      sound: callRingtoneSound,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      enableVibration: true,
      vibrationPattern: callVibrationPattern,
      color: const Color(0xFF2563EB),
      colorized: true,
      visibility: NotificationVisibility.public,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          actionAccept,
          '🔵 Accept',
          titleColor: Color(0xFF2563EB),
          icon: DrawableResourceAndroidBitmap('ic_call_accept'),
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionReject,
          '🔴 Reject',
          titleColor: Color(0xFFEF4444),
          icon: DrawableResourceAndroidBitmap('ic_call_reject'),
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'incoming_call',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: notificationId,
      title: call.callerName.isNotEmpty ? call.callerName : 'Unknown Caller',
      body: callTypeLabel,
      notificationDetails: notificationDetails,
      payload: jsonEncode(call.toMap()),
    );

    debugPrint('[CALL PUSH] Posted incoming call notification: ${call.callId}');
  }

  /// Cancels notification and ceases alerts
  Future<void> dismissNotification(String callId) async {
    if (dismissNotificationDelegate != null) {
      await dismissNotificationDelegate!(callId);
      return;
    }

    final int notificationId = callId.hashCode.abs();
    try {
      await _notificationsPlugin.cancel(id: notificationId);
      debugPrint('[CALL PUSH] Dismissed notification for call: $callId');
    } catch (e) {
      debugPrint('[CALL PUSH] Error dismissing notification $callId: $e');
    }
  }

  /// Cancels all active notifications
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
