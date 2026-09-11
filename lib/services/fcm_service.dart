import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/pending_call_model.dart';
import '../screens/calling/incoming_call_decision_dialog.dart';
import 'auth_service.dart';
import 'call_notification_service.dart';
import 'pending_call_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import '../firebase_options.dart';
import 'zego_call_service.dart';

typedef FcmTokenSyncDelegate = Future<void> Function(String uid, String token);
typedef FcmTokenCleanDelegate = Future<void> Function(String uid);

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[FCM] Background binding/firebase init note: $e');
  }

  debugPrint('[FCM] Background push received: ${message.data}');
  final data = message.data;
  final type = data['type'] as String?;

  if (type == 'incoming_call') {
    try {
      final pendingCall = PendingCallModel.fromFcmPayload(data);
      if (!pendingCall.isExpired) {
        await PendingCallManager.instance.savePendingCall(pendingCall);
        await CallNotificationService.instance.showIncomingCallNotification(pendingCall);
      } else {
        debugPrint('[FCM] Received expired incoming call in background.');
      }
    } catch (e) {
      debugPrint('[FCM] Error processing background incoming call: $e');
    }
  } else if (type == 'call_cancelled') {
    final callId = data['callId'] as String?;
    if (callId != null && callId.isNotEmpty) {
      await CallNotificationService.instance.dismissNotification(callId);
      await PendingCallManager.instance.clearPendingCall();
      debugPrint('[FCM] Dismissed cancelled call notification for $callId');
    }
  }
}

/// FcmService manages Firebase Cloud Messaging lifecycle, token persistence in Firestore,
/// token refresh updates, and notification routing.
class FcmService {
  static FcmService? _instance;
  static FcmService get instance => _instance ??= FcmService();

  @visibleForTesting
  static void setInstance(FcmService service) {
    _instance = service;
  }

  final FirebaseMessaging? _injectedMessaging;
  final FirebaseFirestore? _injectedFirestore;
  final AuthService? _injectedAuthService;

  final FcmTokenSyncDelegate? tokenSyncDelegate;
  final FcmTokenCleanDelegate? tokenCleanDelegate;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;

  FcmService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    AuthService? authService,
    this.tokenSyncDelegate,
    this.tokenCleanDelegate,
  })  : _injectedMessaging = messaging,
        _injectedFirestore = firestore,
        _injectedAuthService = authService;

  FirebaseMessaging get _messaging => _injectedMessaging ?? FirebaseMessaging.instance;
  FirebaseFirestore get _firestore => _injectedFirestore ?? FirebaseFirestore.instance;
  AuthService get _authService => _injectedAuthService ?? AuthService();

  String? _cachedFcmToken;
  String? get currentFcmToken => _cachedFcmToken;

  /// Initialize FCM permissions and message listeners
  Future<void> initialize({
    void Function(PendingCallModel call)? onIncomingCallTapped,
  }) async {
    if (kIsWeb) return;

    try {
      // 1. Request OS notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // 2. Set foreground presentation options
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Obtain initial token and sync if user is currently logged in
      final token = await _messaging.getToken();
      if (token != null) {
        _cachedFcmToken = token;
        debugPrint('[FCM] Token received: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
        await syncFcmToken(token);
      }

      // 4. Listen for token refresh events
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        _cachedFcmToken = newToken;
        debugPrint('[FCM] Token refreshed.');
        await syncFcmToken(newToken);
      });

      // 5. Listen for foreground messages
      _foregroundMessageSub?.cancel();
      _foregroundMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('[FCM] Incoming foreground message: ${message.data}');
        final data = message.data;
        final type = data['type'] as String?;

        if (type == 'incoming_call') {
          final pendingCall = PendingCallModel.fromFcmPayload(data);
          if (!pendingCall.isExpired) {
            await PendingCallManager.instance.savePendingCall(pendingCall);
            // If our app is not currently in foreground (e.g. another app is open),
            // ensure system notification is presented with [Reject] [Accept]
            if (!ZegoCallService.instance.isAppInForeground) {
              await CallNotificationService.instance.showIncomingCallNotification(pendingCall);
            }
          }
        } else if (type == 'call_cancelled') {
          final callId = data['callId'] as String?;
          if (callId != null && callId.isNotEmpty) {
            IncomingCallDecisionDialog.dismissCurrent(callId);
            await CallNotificationService.instance.dismissNotification(callId);
            await PendingCallManager.instance.clearPendingCall();
          }
        }
      });

      // 6. Handle notification tap when app opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] App opened via notification: ${message.data}');
        _handleMessageTap(message.data, onIncomingCallTapped);
      });

      // 7. Check if app was launched directly from a terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App launched from terminated state via message: ${initialMessage.data}');
        _handleMessageTap(initialMessage.data, onIncomingCallTapped);
      }
    } catch (e) {
      debugPrint('[FCM] Initialization error: $e');
    }
  }

  void _handleMessageTap(Map<String, dynamic> data, void Function(PendingCallModel call)? callback) {
    final type = data['type'] as String?;
    if (type == 'incoming_call') {
      try {
        final pendingCall = PendingCallModel.fromFcmPayload(data);
        if (!pendingCall.isExpired) {
          PendingCallManager.instance.savePendingCall(pendingCall);
          if (callback != null) {
            callback(pendingCall);
          }
        } else {
          debugPrint('[FCM] Tap ignored: pending call is expired.');
        }
      } catch (e) {
        debugPrint('[FCM] Error processing message tap: $e');
      }
    }
  }

  /// Syncs the FCM token to the user's Firestore profile
  Future<void> syncFcmToken([String? token]) async {
    final targetToken = token ?? _cachedFcmToken;
    if (targetToken == null || targetToken.isEmpty) return;

    final currentUid = _authService.currentUserId;
    if (currentUid == null || currentUid.isEmpty) {
      debugPrint('[FCM] syncFcmToken skipped: user not authenticated.');
      return;
    }

    if (tokenSyncDelegate != null) {
      await tokenSyncDelegate!(currentUid, targetToken);
      return;
    }

    try {
      await _firestore.collection('users').doc(currentUid).update({
        'fcmToken': targetToken,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FCM] Synced FCM token to Firestore for user $currentUid');
    } catch (e) {
      debugPrint('[FCM] Error syncing FCM token to Firestore: $e');
    }
  }

  /// Clears the FCM token from the user's Firestore profile upon logout
  Future<void> cleanFcmToken([String? uid]) async {
    final targetUid = uid ?? _authService.currentUserId;
    if (targetUid == null || targetUid.isEmpty) return;

    if (tokenCleanDelegate != null) {
      await tokenCleanDelegate!(targetUid);
      return;
    }

    try {
      await _firestore.collection('users').doc(targetUid).update({
        'fcmToken': FieldValue.delete(),
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FCM] Cleared FCM token from Firestore for user $targetUid');
    } catch (e) {
      debugPrint('[FCM] Error clearing FCM token: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundMessageSub?.cancel();
  }
}
