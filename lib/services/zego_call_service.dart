import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import '../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/zego_token_response.dart';
import '../screens/calling/custom_audio_calling_view.dart';
import 'auth_service.dart';
import 'user_service.dart';

/// ZegoCallService manages 1-to-1 audio calling via ZEGOCLOUD Call Kit.
///
/// Security & Architecture:
/// - ServerSecret is NEVER stored or handled in Flutter.
/// - Authenticated session tokens are obtained from the Firebase Cloud Function `getZegoToken`.
/// - The global [navigatorKey] is used for call invitation routing.
/// - Call Kit is initialized upon user login and properly deinitialized upon logout.
class ZegoCallService {
  final FirebaseFunctions? _injectedFunctions;
  final AuthService? _injectedAuthService;
  final UserService? _injectedUserService;

  ZegoCallService({
    FirebaseFunctions? functions,
    AuthService? authService,
    UserService? userService,
  })  : _injectedFunctions = functions,
        _injectedAuthService = authService,
        _injectedUserService = userService;

  static final ZegoCallService instance = ZegoCallService();

  // Global Navigator Key for ZEGOCLOUD CallKit navigation
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  FirebaseFunctions get _functions =>
      _injectedFunctions ?? FirebaseFunctions.instance;
  AuthService get _authService =>
      _injectedAuthService ?? AuthService();
  UserService get _userService =>
      _injectedUserService ?? UserService();

  // Reactive state observables
  final RxBool isInitialized = false.obs;
  final RxBool isCalling = false.obs;
  final RxString activeCallId = ''.obs;

  String? _initializedUserId;

  /// Request a secure temporary session token from the Firebase Cloud Function
  Future<ZegoTokenResponse> getZegoToken() async {
    final currentUid = _authService.currentUserId;
    if (currentUid == null || currentUid.isEmpty) {
      throw 'User is not authenticated. Please log in first.';
    }

    try {
      final HttpsCallable callable = _functions.httpsCallable('getZegoToken');
      final HttpsCallableResult result = await callable.call();

      if (result.data == null) {
        throw 'Empty response received from token server.';
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map);

      final tokenResponse = ZegoTokenResponse.fromMap(data);
      if (!tokenResponse.isValid) {
        throw 'Invalid token response received from server.';
      }

      return tokenResponse;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('getZegoToken FirebaseFunctionsException: ${e.code} - ${e.message}');
      if (e.code == 'unauthenticated') {
        throw 'Session expired. Please sign in again.';
      } else if (e.code == 'failed-precondition') {
        throw 'Calling service configuration error. Please ensure ZEGOCLOUD credentials are set on the backend.';
      }
      throw e.message ?? 'Failed to obtain calling credentials.';
    } catch (e) {
      debugPrint('getZegoToken unexpected error: $e');
      throw 'Unable to connect to calling service. Please check your internet connection.';
    }
  }

  /// Initialize ZEGOCLOUD Call Invitation Service with the authenticated user and token
  Future<bool> initZegoCallService({UserModel? userModel}) async {
    if (Get.testMode) {
      isInitialized.value = true;
      _initializedUserId = 'test_user';
      return true;
    }

    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) {
      debugPrint('ZegoCallService.init skipped: user is not authenticated.');
      return false;
    }

    // Skip redundant initialization if already active for this UID
    if (isInitialized.value && _initializedUserId == currentUser.uid) {
      return true;
    }

    try {
      // 1. Obtain temporary token from Cloud Function
      final ZegoTokenResponse tokenData = await getZegoToken();

      // 2. Resolve display name
      String displayName = userModel?.name.trim() ?? '';
      if (displayName.isEmpty) {
        final profile = await _userService.getUser(currentUser.uid);
        displayName = profile?.name.trim() ?? '';
      }
      if (displayName.isEmpty) {
        displayName = currentUser.displayName?.trim() ?? '';
      }
      if (displayName.isEmpty) {
        displayName = currentUser.email?.split('@').first ?? 'User';
      }

      // 3. Bind global navigator key
      ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

      // 4. Initialize ZEGOCLOUD CallKit
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: tokenData.appId,
        token: tokenData.token,
        userID: currentUser.uid,
        userName: displayName,
        plugins: [ZegoUIKitSignalingPlugin()],
        uiConfig: ZegoCallInvitationUIConfig(
          inviter: ZegoCallInvitationInviterUIConfig(
            defaultCameraOn: false,
            cameraButton: ZegoCallButtonUIConfig(visible: false),
            cameraSwitchButton: ZegoCallButtonUIConfig(visible: false),
            backgroundBuilder: (context, size, info) {
              return Container(
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
              );
            },
          ),
          invitee: ZegoCallInvitationInviteeUIConfig(
            defaultCameraOn: false,
            showVideoOnCalling: false,
            cameraButton: ZegoCallButtonUIConfig(visible: false),
            cameraSwitchButton: ZegoCallButtonUIConfig(visible: false),
            backgroundBuilder: (context, size, info) {
              return Container(
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
              );
            },
          ),
        ),
        requireConfig: (ZegoCallInvitationData data) {
          // Phase 6 is 1-to-1 Audio Calling with custom modular UI
          final config = ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();
          config.turnOnCameraWhenJoining = false;
          config.useSpeakerWhenJoining = false;
          config.topMenuBar.isVisible = false;
          config.bottomMenuBar.buttons = [];
          config.audioVideoView.showCameraStateOnView = false;
          config.audioVideoView.showSoundWavesInAudioMode = true;
          config.foreground = CustomAudioCallingView(callData: data);
          return config;
        },
      );

      _initializedUserId = currentUser.uid;
      isInitialized.value = true;
      debugPrint('ZegoCallService initialized successfully for UID: ${currentUser.uid}');
      return true;
    } catch (e) {
      debugPrint('ZegoCallService initialization error: $e');
      isInitialized.value = false;
      _initializedUserId = null;
      return false;
    }
  }

  /// Deinitialize ZEGOCLOUD Call Invitation Service upon user logout
  Future<void> uninit() async {
    try {
      if (isInitialized.value) {
        await ZegoUIKitPrebuiltCallInvitationService().uninit();
        debugPrint('ZegoCallService uninitialized successfully.');
      }
    } catch (e) {
      debugPrint('ZegoCallService.uninit error: $e');
    } finally {
      isInitialized.value = false;
      _initializedUserId = null;
      isCalling.value = false;
      activeCallId.value = '';
    }
  }

  /// Check and request microphone permission before an audio call
  Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.microphone.request();
    if (result.isGranted) {
      return true;
    }

    if (result.isPermanentlyDenied) {
      _showPermissionSettingsDialog();
    } else {
      Get.snackbar(
        'Microphone Permission Required',
        'Please grant microphone permission to make audio calls.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    }
    return false;
  }

  /// Send a 1-to-1 audio call invitation to the target user
  Future<bool> sendAudioCallInvitation({
    required UserModel targetUser,
  }) async {
    if (Get.testMode) {
      return true;
    }

    // 1. Prevent duplicate simultaneous call attempts
    if (isCalling.value) {
      Get.snackbar(
        'Call in Progress',
        'A call is already being initiated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.primaryColor,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return false;
    }

    final currentUid = _authService.currentUserId;
    if (currentUid == null || currentUid.isEmpty) {
      Get.snackbar(
        'Authentication Required',
        'Please log in to make calls.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return false;
    }

    if (targetUser.uid == currentUid) {
      Get.snackbar(
        'Invalid Action',
        'You cannot call yourself.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return false;
    }

    // 2. Verify microphone permission
    final hasPermission = await checkMicrophonePermission();
    if (!hasPermission) return false;

    // 3. Ensure service is initialized
    if (!isInitialized.value) {
      final initialized = await initZegoCallService();
      if (!initialized) {
        Get.snackbar(
          'Service Unavailable',
          'Unable to connect to call service. Please check your network and try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
        return false;
      }
    }

    isCalling.value = true;
    try {
      final inviteeName =
          targetUser.name.isNotEmpty ? targetUser.name : 'User';

      final bool sent = await ZegoUIKitPrebuiltCallInvitationService().send(
        invitees: [
          ZegoCallUser(targetUser.uid, inviteeName),
        ],
        isVideoCall: false, // Strict Phase 6 Requirement: AUDIO ONLY
        timeoutSeconds: 60,
      );

      if (!sent) {
        Get.snackbar(
          'Call Failed',
          'Unable to send call invitation to $inviteeName. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
      return sent;
    } catch (e) {
      debugPrint('sendAudioCallInvitation error: $e');
      Get.snackbar(
        'Call Error',
        'An unexpected error occurred while placing the call.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return false;
    } finally {
      isCalling.value = false;
    }
  }

  void _showPermissionSettingsDialog() {
    Get.defaultDialog(
      title: 'Microphone Permission',
      titleStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
      middleText:
          'Microphone permission is permanently disabled. Please enable it in device settings to make audio calls.',
      middleTextStyle: const TextStyle(
        fontSize: 14,
        color: AppTheme.textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      radius: 16,
      textConfirm: 'Open Settings',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primaryColor,
      textCancel: 'Cancel',
      cancelTextColor: AppTheme.textPrimary,
      onConfirm: () {
        Get.back();
        openAppSettings();
      },
      onCancel: () {
        Get.back();
      },
    );
  }
}
