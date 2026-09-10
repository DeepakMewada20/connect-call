import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../routes/app_routes.dart';
import '../../services/call_notification_service.dart';
import '../../services/fcm_service.dart';
import '../../services/pending_call_manager.dart';
import '../../services/user_service.dart';
import '../../services/zego_call_service.dart';
import '../calling/incoming_call_decision_dialog.dart';

class SplashController extends GetxController {
  // Optional authStateChecker for unit testing / mocking
  final Future<bool> Function()? authStateChecker;
  final UserService _userService;

  SplashController({
    this.authStateChecker,
    UserService? userService,
  }) : _userService = userService ?? UserService();

  // Status message for splash screen loading state
  final RxString statusMessage = 'Initializing...'.obs;

  @override
  void onReady() {
    super.onReady();
    _initializeAppAndNavigate();
  }

  Future<void> _initializeAppAndNavigate() async {
    try {
      statusMessage.value = 'Connecting...';

      // Ensure minimal splash display duration for smooth UX transition
      // while performing the auth check concurrently.
      final results = await Future.wait([
        _checkAuthenticationState(),
        Future.delayed(
            const Duration(milliseconds: AppConstants.splashMinDurationMs)),
      ]);

      final bool isAuthenticated = results[0] as bool;

      if (isAuthenticated) {
        // If authStateChecker is injected (e.g. for unit tests), bypass Firestore lookup
        if (authStateChecker != null) {
          Get.offAllNamed(AppRoutes.home);
          return;
        }

        // Verify that authenticated user has a complete Firestore profile
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final profile = await _userService.getUser(user.uid);
          if (profile != null && profile.name.trim().isNotEmpty) {
            // Sync FCM token upon successful authentication
            FcmService.instance.syncFcmToken();

            // If an active call is already underway or connecting, do NOT wipe navigation stack!
            if (ZegoCallService.instance.activeCallId.value.isNotEmpty) {
              debugPrint('[SPLASH] Active call detected (${ZegoCallService.instance.activeCallId.value}). Retaining call screen.');
              return;
            }

            // Check if application was launched from incoming call notification
            final pendingCall = await PendingCallManager.instance.getPendingCall();
            final launchAction = PendingCallManager.instance.launchAction;

            if (pendingCall != null && !pendingCall.isExpired) {
              debugPrint('[SPLASH] Incoming call detected on launch: ${pendingCall.callId}, action: $launchAction');

              // 1. Ensure ZEGOCLOUD Call Service is initialized and connected to ZIM
              if (!ZegoCallService.instance.isInitialized.value) {
                await ZegoCallService.instance.initZegoCallService();
              }

              // 2. Set HomeScreen as root route so any pop lands safely on Home
              Get.offAllNamed(AppRoutes.home);

              // 3. Process the pending call action on top of HomeScreen
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                PendingCallManager.instance.launchAction = null;
                if (launchAction == CallNotificationService.actionAccept) {
                  debugPrint('[SPLASH] Executing accept for cold launched call: ${pendingCall.callId}');
                  await ZegoCallService.instance.acceptCallFromNotification(pendingCall);
                } else if (launchAction == CallNotificationService.actionReject) {
                  debugPrint('[SPLASH] Executing reject for cold launched call: ${pendingCall.callId}');
                  await ZegoCallService.instance.rejectCallFromNotification(pendingCall);
                } else {
                  final ctx = Get.context;
                  if (ctx != null && ZegoCallService.instance.activeCallId.value.isEmpty) {
                    debugPrint('[SPLASH] Displaying IncomingCallDecisionDialog on HomeScreen.');
                    IncomingCallDecisionDialog.show(
                      ctx,
                      pendingCall,
                      onAccept: () async {
                        await ZegoCallService.instance.acceptCallFromNotification(pendingCall);
                      },
                      onReject: () async {
                        await ZegoCallService.instance.rejectCallFromNotification(pendingCall);
                      },
                    );
                  }
                }
              });
              return;
            }

            Get.offAllNamed(AppRoutes.home);
          } else {
            Get.offAllNamed(
              AppRoutes.name,
              arguments: {
                'uid': user.uid,
                'phoneNumber': user.phoneNumber,
              },
            );
          }
        } else {
          Get.offAllNamed(AppRoutes.login);
        }
      } else {
        Get.offAllNamed(AppRoutes.login);
      }
    } catch (e, stackTrace) {
      debugPrint('Error during splash initialization: $e');
      debugPrint('$stackTrace');
      // Graceful fallback: Navigate to login rather than getting stuck indefinitely
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<bool> _checkAuthenticationState() async {
    if (authStateChecker != null) {
      return authStateChecker!();
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      return user != null;
    } catch (e) {
      debugPrint('FirebaseAuth check error: $e');
      return false;
    }
  }
}
