import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import '../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/zego_token_response.dart';
import '../routes/app_routes.dart';
import '../screens/calling/custom_audio_calling_view.dart';
import '../screens/calling/invite_participant_sheet.dart';
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

      // Proactively request microphone and camera permissions so both caller and receiver
      // can transmit audio and video without missing runtime OS permission prompts
      try {
        await [
          Permission.microphone,
          Permission.camera,
        ].request();
      } catch (e) {
        debugPrint('Permissions request error: $e');
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
        config: ZegoCallInvitationConfig(
          inCalling: ZegoCallInvitationInCallingConfig(
            canInvitingInCalling: true,
            onlyInitiatorCanInvite: false,
          ),
        ),
        uiConfig: ZegoCallInvitationUIConfig(
          inviter: ZegoCallInvitationInviterUIConfig(
            defaultCameraOn: true,
            pageBuilder: (context, info) {
              if (info.callType == ZegoCallInvitationType.videoCall) {
                return null;
              }
              return CustomAudioCallingView(
                isOutgoingRinging: true,
                callingInfo: info,
                onCancelCall: () async {
                  try {
                    await ZegoUIKitPrebuiltCallInvitationService().cancel(
                      callees: info.invitees
                          .map((u) => ZegoCallUser(u.id, u.name))
                          .toList(),
                    );
                  } catch (e) {
                    debugPrint('Error canceling outgoing call: $e');
                  }
                },
              );
            },
            backgroundBuilder: (context, size, info) {
              if (info.callType == ZegoCallInvitationType.videoCall) {
                return null;
              }
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
            defaultCameraOn: true,
            showVideoOnCalling: true,
            backgroundBuilder: (context, size, info) {
              if (info.callType == ZegoCallInvitationType.videoCall) {
                return null;
              }
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
        events: ZegoUIKitPrebuiltCallEvents(
          onCallEnd: (ZegoCallEndEvent event, VoidCallback defaultAction) {
            debugPrint('ZegoCallService onCallEnd: ${event.reason}');
            isCalling.value = false;
            activeCallId.value = '';

            try {
              defaultAction();
            } catch (e) {
              debugPrint('defaultAction error: $e');
            }

            // Post-frame check: If the route stack was drained or not at home,
            // recover cleanly to HomeScreen without interfering with the pop animation.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final nav = navigatorKey.currentState;
              if (nav != null) {
                if (!nav.canPop() && Get.currentRoute != AppRoutes.home) {
                  Get.offAllNamed(AppRoutes.home);
                }
              } else if (Get.currentRoute != AppRoutes.home) {
                Get.offAllNamed(AppRoutes.home);
              }
            });
          },
        ),
        requireConfig: (ZegoCallInvitationData data) {
          activeCallId.value = data.callID;
          final isGroup = data.invitees.length > 1;

          if (data.type == ZegoCallInvitationType.videoCall) {
            // Proactively ensure camera is permitted and turned on for receiver
            Permission.camera.request().then((status) {
              if (status.isGranted) {
                ZegoUIKit().turnCameraOn(true);
              }
            });

            // Functional 1-to-1 or Multi-user Video Conference Call
            final config = isGroup
                ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
                : ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

            config.turnOnCameraWhenJoining = true;
            config.turnOnMicrophoneWhenJoining = true;
            config.useSpeakerWhenJoining = true;

            if (isGroup) {
              config.layout = ZegoLayout.gallery();
            } else {
              config.layout = ZegoLayout.pictureInPicture(
                isSmallViewDraggable: true,
                switchLargeOrSmallViewByClick: true,
                smallViewPosition: ZegoViewPosition.topRight,
              );
            }

            // In-call invite button in top bar to add more participants into conference
            config.topMenuBar.extendButtons = [
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Add to Conference',
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                  ),
                  onPressed: () {
                    InviteParticipantSheet.show(context, isVideo: true);
                  },
                ),
              ),
            ];

            config.bottomMenuBar.buttons = [
              ZegoCallMenuBarButtonName.toggleCameraButton,
              ZegoCallMenuBarButtonName.switchCameraButton,
              ZegoCallMenuBarButtonName.hangUpButton,
              ZegoCallMenuBarButtonName.toggleMicrophoneButton,
              ZegoCallMenuBarButtonName.switchAudioOutputButton,
              ZegoCallMenuBarButtonName.showMemberListButton,
            ];
            config.audioVideoView.useVideoViewAspectFill = true;
            config.audioVideoView.showCameraStateOnView = true;
            config.audioVideoView.showMicrophoneStateOnView = true;
            config.audioVideoView.showUserNameOnView = true;
            return config;
          }

          // Audio Calling (1-to-1 or Conference) with custom modular UI
          final config = isGroup
              ? ZegoUIKitPrebuiltCallConfig.groupVoiceCall()
              : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

          config.turnOnCameraWhenJoining = false;
          config.turnOnMicrophoneWhenJoining = true;
          config.useSpeakerWhenJoining = true;
          config.topMenuBar.isVisible = false;
          config.bottomMenuBar.buttons = [];
          config.audioVideoView.showCameraStateOnView = false;
          config.audioVideoView.showSoundWavesInAudioMode = true;
          config.audioVideoView.showAvatarInAudioMode = true;
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

  /// Check and request microphone permission before an audio or video call
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
      _showPermissionSettingsDialog(
        permissionName: 'Microphone Permission',
        featureDescription:
            'Microphone permission is permanently disabled. Please enable it in device settings to make audio and video calls.',
      );
    } else {
      Get.snackbar(
        'Microphone Permission Required',
        'Please grant microphone permission to make calls.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    }
    return false;
  }

  /// Check and request camera permission before a video call
  Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.camera.request();
    if (result.isGranted) {
      return true;
    }

    if (result.isPermanentlyDenied) {
      _showPermissionSettingsDialog(
        permissionName: 'Camera Permission',
        featureDescription:
            'Camera permission is permanently disabled. Please enable it in device settings to make video calls.',
      );
    } else {
      Get.snackbar(
        'Camera Permission Required',
        'Please grant camera permission to make video calls.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    }
    return false;
  }

  /// Check both microphone and camera permissions required for video calls
  Future<bool> checkVideoCallPermissions() async {
    final micGranted = await checkMicrophonePermission();
    if (!micGranted) return false;

    final cameraGranted = await checkCameraPermission();
    if (!cameraGranted) return false;

    return true;
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

  /// Send a 1-to-1 video call invitation to the target user
  Future<bool> sendVideoCallInvitation({
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

    // 2. Verify microphone and camera permissions
    final hasPermissions = await checkVideoCallPermissions();
    if (!hasPermissions) return false;

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
        isVideoCall: true, // Strict Phase 7 Requirement: VIDEO CALL
        timeoutSeconds: 60,
      );

      if (!sent) {
        Get.snackbar(
          'Call Failed',
          'Unable to send video call invitation to $inviteeName. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
      return sent;
    } catch (e) {
      debugPrint('sendVideoCallInvitation error: $e');
      Get.snackbar(
        'Call Error',
        'An unexpected error occurred while placing the video call.',
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

  /// Send a group / conference audio call invitation to multiple users
  Future<bool> sendGroupAudioCallInvitation({
    required List<UserModel> targetUsers,
  }) async {
    if (Get.testMode) return true;
    if (targetUsers.isEmpty) return false;

    if (targetUsers.length == 1) {
      return sendAudioCallInvitation(targetUser: targetUsers.first);
    }

    final hasPermission = await checkMicrophonePermission();
    if (!hasPermission) return false;

    if (!isInitialized.value) {
      final initialized = await initZegoCallService();
      if (!initialized) return false;
    }

    isCalling.value = true;
    try {
      final invitees = targetUsers.map((u) {
        final name = u.name.isNotEmpty ? u.name : 'User';
        return ZegoCallUser(u.uid, name);
      }).toList();

      final bool sent = await ZegoUIKitPrebuiltCallInvitationService().send(
        invitees: invitees,
        isVideoCall: false,
        timeoutSeconds: 60,
      );

      if (!sent) {
        Get.snackbar(
          'Call Failed',
          'Unable to send group audio call invitation.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
      return sent;
    } catch (e) {
      debugPrint('sendGroupAudioCallInvitation error: $e');
      return false;
    } finally {
      isCalling.value = false;
    }
  }

  /// Send a group / conference video call invitation to multiple users
  Future<bool> sendGroupVideoCallInvitation({
    required List<UserModel> targetUsers,
  }) async {
    if (Get.testMode) return true;
    if (targetUsers.isEmpty) return false;

    if (targetUsers.length == 1) {
      return sendVideoCallInvitation(targetUser: targetUsers.first);
    }

    final hasPermissions = await checkVideoCallPermissions();
    if (!hasPermissions) return false;

    if (!isInitialized.value) {
      final initialized = await initZegoCallService();
      if (!initialized) return false;
    }

    isCalling.value = true;
    try {
      final invitees = targetUsers.map((u) {
        final name = u.name.isNotEmpty ? u.name : 'User';
        return ZegoCallUser(u.uid, name);
      }).toList();

      final bool sent = await ZegoUIKitPrebuiltCallInvitationService().send(
        invitees: invitees,
        isVideoCall: true,
        timeoutSeconds: 60,
      );

      if (!sent) {
        Get.snackbar(
          'Call Failed',
          'Unable to send group video call invitation.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
      return sent;
    } catch (e) {
      debugPrint('sendGroupVideoCallInvitation error: $e');
      return false;
    } finally {
      isCalling.value = false;
    }
  }

  /// Invite a registered contact to the currently active audio or video conference
  Future<bool> inviteToOngoingCall({
    required UserModel targetUser,
    required bool isVideo,
  }) async {
    if (Get.testMode) {
      return true;
    }

    // Resolve room ID with triple fallback: UIKit room -> activeCallId -> invitation data
    final String currentRoomId = ZegoUIKit().getRoom().id.isNotEmpty
        ? ZegoUIKit().getRoom().id
        : (activeCallId.value.isNotEmpty
            ? activeCallId.value
            : ZegoUIKitPrebuiltCallInvitationService()
                .private
                .currentCallInvitationDataSafe
                .callID);

    if (currentRoomId.isEmpty) {
      Get.snackbar(
        'Conference Unavailable',
        'No active call room found to add participants.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return false;
    }

    final currentUid = _authService.currentUserId;
    if (targetUser.uid == currentUid) {
      Get.snackbar(
        'Invalid Action',
        'You cannot invite yourself.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return false;
    }

    try {
      final inviteeName =
          targetUser.name.isNotEmpty ? targetUser.name : 'User';

      bool sent = false;

      // 1. Primary: Standard ZEGOCLOUD Prebuilt Call invitation service
      try {
        sent = await ZegoUIKitPrebuiltCallInvitationService().send(
          invitees: [
            ZegoCallUser(targetUser.uid, inviteeName),
          ],
          isVideoCall: isVideo,
          callID: currentRoomId,
          timeoutSeconds: 60,
        );
        debugPrint('ZegoPrebuiltCallInvitationService.send returned: $sent');
      } catch (e) {
        debugPrint('ZegoPrebuiltCallInvitationService.send error: $e');
      }

      // 2. Resilient Fallback: Direct Signaling Plugin invitation to the active room
      if (!sent) {
        debugPrint(
            'Prebuilt send returned false; attempting signaling fallback to room: $currentRoomId');
        final currentUserName = ZegoUIKit().getLocalUser().name.isNotEmpty
            ? ZegoUIKit().getLocalUser().name
            : (_authService.getCurrentUser()?.displayName ?? 'User');
        final currentUserId = ZegoUIKit().getLocalUser().id.isNotEmpty
            ? ZegoUIKit().getLocalUser().id
            : (currentUid ?? '');

        final payload = jsonEncode({
          'call_id': currentRoomId,
          'inviter_name': currentUserName,
          'invitees': [
            {'user_id': targetUser.uid, 'user_name': inviteeName}
          ],
          'timeout': 60,
          'custom_data': '',
        });

        final int invitationType = isVideo ? 1 : 0;

        // Try sendAdvanceInvitation first
        try {
          final advanceResult =
              await ZegoUIKit().getSignalingPlugin().sendAdvanceInvitation(
                    inviterID: currentUserId,
                    inviterName: currentUserName,
                    invitees: [targetUser.uid],
                    timeout: 60,
                    type: invitationType,
                    data: payload,
                  );
          if (advanceResult.error == null ||
              (advanceResult.error?.code.isEmpty ?? true)) {
            sent = true;
            debugPrint(
                'Signaling advance invitation sent successfully: ${advanceResult.invitationID}');
          } else {
            debugPrint(
                'Signaling advance invitation returned code: ${advanceResult.error?.code}');
          }
        } catch (e) {
          debugPrint('sendAdvanceInvitation exception: $e');
        }

        // Try standard sendInvitation if advance invitation wasn't successful
        if (!sent) {
          try {
            final basicResult =
                await ZegoUIKit().getSignalingPlugin().sendInvitation(
                      inviterID: currentUserId,
                      inviterName: currentUserName,
                      invitees: [targetUser.uid],
                      timeout: 60,
                      type: invitationType,
                      data: payload,
                    );
            if (basicResult.error == null ||
                (basicResult.error?.code.isEmpty ?? true)) {
              sent = true;
              debugPrint(
                  'Basic signaling invitation sent successfully: ${basicResult.invitationID}');
            } else {
              debugPrint(
                  'Basic signaling invitation returned code: ${basicResult.error?.code}');
            }
          } catch (e) {
            debugPrint('sendInvitation exception: $e');
          }
        }
      }

      if (sent) {
        Get.snackbar(
          'Invitation Sent',
          'Invited $inviteeName to join the conference.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
        return true;
      } else {
        Get.snackbar(
          'Call Failed',
          'Unable to send conference invitation to $inviteeName.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
        return false;
      }
    } catch (e) {
      debugPrint('inviteToOngoingCall error: $e');
      return false;
    }
  }

  void _showPermissionSettingsDialog({
    required String permissionName,
    required String featureDescription,
  }) {
    Get.defaultDialog(
      title: permissionName,
      titleStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
      middleText: featureDescription,
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
