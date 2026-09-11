import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import '../core/theme/app_theme.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';
import '../models/zego_token_response.dart';
import '../models/pending_call_model.dart';
import '../routes/app_routes.dart';
import '../screens/calling/custom_audio_calling_view.dart';
import '../screens/calling/custom_screen_sharing_button.dart';
import '../screens/calling/incoming_call_decision_dialog.dart';
import '../screens/calling/invite_participant_sheet.dart';
import '../screens/calling/screen_sharing_indicator.dart';
import '../screens/home/home_controller.dart';
// ignore: implementation_imports
import 'package:zego_uikit/src/services/internal/internal.dart';
import '../widgets/network_quality_indicator.dart';
import 'auth_service.dart';
import 'block_service.dart';
import 'call_history_service.dart';
import 'call_notification_service.dart';
import 'contact_service.dart';
import 'network_quality_service.dart';
import 'pending_call_manager.dart';
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
  final CallHistoryService? _injectedCallHistoryService;
  final BlockService? _injectedBlockService;

  ZegoCallService({
    FirebaseFunctions? functions,
    AuthService? authService,
    UserService? userService,
    CallHistoryService? callHistoryService,
    BlockService? blockService,
  })  : _injectedFunctions = functions,
        _injectedAuthService = authService,
        _injectedUserService = userService,
        _injectedCallHistoryService = callHistoryService,
        _injectedBlockService = blockService;

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
  CallHistoryService get _callHistoryService =>
      _injectedCallHistoryService ?? CallHistoryService.instance;
  BlockService get _blockService =>
      _injectedBlockService ?? BlockService.instance;

  // Reactive state observables
  final RxBool isInitialized = false.obs;
  final RxBool isCalling = false.obs;
  final RxString activeCallId = ''.obs;
  final RxBool isScreenSharing = false.obs;
  StreamSubscription? _screenCaptureErrorSubscription;

  /// Optional override for testing or simulated foreground states
  bool? isForegroundOverride;

  /// Returns true if OUR Flutter app is currently in foreground (resumed and visible)
  bool get isAppInForeground {
    if (isForegroundOverride != null) return isForegroundOverride!;
    try {
      return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    } catch (_) {
      return false;
    }
  }

  String? _initializedUserId;

  // Active call session tracking for Call History
  String? _currentSessionCallId;
  DateTime? _callConnectedAt;
  bool _currentSessionIsVideo = false;
  String? _currentSessionTargetUid;
  String? _currentSessionTargetName;
  String? _currentSessionTargetPhoto;

  /// Public getter for current session target name
  String? get currentSessionTargetName => _currentSessionTargetName;

  ZegoTokenResponse? _cachedTokenResponse;

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

      _cachedTokenResponse = tokenResponse;
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
        displayName = currentUser.phoneNumber?.trim() ?? 'User';
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
        notificationConfig: ZegoCallInvitationNotificationConfig(
          androidNotificationConfig: ZegoCallAndroidNotificationConfig(
            callChannel: ZegoCallAndroidNotificationChannelConfig(
              channelID: 'incoming_calls_v2',
              channelName: 'Incoming Calls',
              icon: 'ic_launcher',
              vibrate: true,
            ),
            showOnFullScreen: true,
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
                    final callIdToCancel = activeCallId.value.isNotEmpty
                        ? activeCallId.value
                        : (_currentSessionCallId ?? '');
                    if (info.invitees.isNotEmpty && callIdToCancel.isNotEmpty) {
                      _dispatchFcmCallCancel(
                        receiverUid: info.invitees.first.id,
                        callId: callIdToCancel,
                      );
                    }
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
            showVideoOnCalling: false,
            popUp: ZegoCallInvitationNotifyPopUpUIConfig(
              visible: false,
            ),
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
        invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
          onOutgoingCallSent: (callID, caller, callType, callees, customData) async {
            _currentSessionCallId = callID;
            activeCallId.value = callID;
            _callConnectedAt = null;
            _currentSessionIsVideo = callType == ZegoCallInvitationType.videoCall;

            final targetUser = callees.isNotEmpty ? callees.first : null;
            _currentSessionTargetUid = targetUser?.id ?? '';
            _currentSessionTargetName = targetUser?.name.isNotEmpty ?? false ? targetUser!.name : 'User';

            final currentUid = _authService.currentUserId ?? caller.id;
            final currentName = caller.name.isNotEmpty
                ? caller.name
                : (_authService.getCurrentUser()?.displayName ?? 'User');

            await _callHistoryService.saveCallRecord(
              CallModel(
                id: callID,
                callerId: currentUid,
                callerName: currentName,
                callerPhoto: _authService.getCurrentUser()?.photoURL,
                calleeId: _currentSessionTargetUid ?? '',
                calleeName: _currentSessionTargetName ?? 'User',
                calleePhoto: _currentSessionTargetPhoto,
                callType: _currentSessionIsVideo ? 'video' : 'audio',
                direction: 'outgoing',
                status: 'calling',
                startedAt: DateTime.now(),
                durationSeconds: 0,
              ),
            );
          },
          onIncomingCallReceived: (callID, caller, callType, callees, customData) async {
            // Check if caller is blocked by current user
            if (await _blockService.isUserBlocked(targetUid: caller.id)) {
              debugPrint('ZegoCallService: Incoming call from blocked user ${caller.id} rejected.');
              try {
                ZegoUIKitPrebuiltCallInvitationService().reject();
              } catch (_) {}
              return;
            }

            // If this call is already active or being connected, do not reset state or show duplicate dialog
            if (activeCallId.value == callID && (_callConnectedAt != null || isCalling.value)) {
              debugPrint('[ZegoCallService] Call $callID is already connecting or active. Skipping duplicate dialog.');
              return;
            }

            // If another call is already actively connected in a room, reject new incoming call as busy
            final isRoomActive = ZegoUIKit().getRoom().id.isNotEmpty && _callConnectedAt != null;
            if (isRoomActive && activeCallId.value != callID) {
              debugPrint('[ZegoCallService] Live room is currently connected (${ZegoUIKit().getRoom().id}). Rejecting incoming call $callID as busy.');
              try {
                await ZegoUIKitPrebuiltCallInvitationService().reject();
              } catch (_) {}
              return;
            }

            _currentSessionCallId = callID;
            activeCallId.value = callID;
            _callConnectedAt = null;
            _currentSessionIsVideo = callType == ZegoCallInvitationType.videoCall;

            _currentSessionTargetUid = caller.id;

            String resolvedCallerName = caller.name.isNotEmpty ? caller.name : 'User';
            String? callerPhone;
            if (customData.isNotEmpty) {
              try {
                final data = jsonDecode(customData) as Map<String, dynamic>;
                callerPhone = data['callerPhone'] as String?;
              } catch (_) {}
            }
            if (callerPhone == null || callerPhone.isEmpty) {
              final callerProfile = await _userService.getUser(caller.id);
              callerPhone = callerProfile?.phoneNumber;
            }
            resolvedCallerName = ContactService.instance.resolveDisplayName(
              phoneNumber: callerPhone,
              registeredName: resolvedCallerName,
              fallback: resolvedCallerName,
            );

            _currentSessionTargetName = resolvedCallerName;

            final currentUid = _authService.currentUserId ?? '';
            final currentName = _authService.getCurrentUser()?.displayName ?? 'User';

            await _callHistoryService.saveCallRecord(
              CallModel(
                id: callID,
                callerId: caller.id,
                callerName: resolvedCallerName,
                phoneNumber: callerPhone,
                calleeId: currentUid,
                calleeName: currentName,
                calleePhoto: _authService.getCurrentUser()?.photoURL,
                callType: _currentSessionIsVideo ? 'video' : 'audio',
                direction: 'incoming',
                status: 'calling',
                startedAt: DateTime.now(),
                durationSeconds: 0,
              ),
            );

            final now = DateTime.now();
            final pendingCall = PendingCallModel(
              callId: callID,
              callerUid: caller.id,
              callerName: resolvedCallerName,
              callerZegoUserId: caller.id,
              callerPhoto: null,
              callType: _currentSessionIsVideo ? 'video' : 'audio',
              timestamp: now,
              expiresAt: now.add(const Duration(seconds: 60)),
            );
            await PendingCallManager.instance.savePendingCall(pendingCall);



            if (isAppInForeground) {
              // CASE 1: App is FOREGROUND
              // Direct full-screen Incoming Call Screen. No top notification/banner!
              debugPrint('[ZegoCallService] App is FOREGROUND -> Opening direct Incoming Call Screen.');
              IncomingCallDecisionDialog.show(
                null,
                pendingCall,
                onAccept: () async {
                  final accepted = await ZegoUIKitPrebuiltCallInvitationService().accept();
                  if (!accepted) {
                    await acceptCallFromNotification(pendingCall);
                  }
                  if (pendingCall.isVideo) {
                    Future.delayed(const Duration(milliseconds: 700), () {
                      try {
                        ZegoUIKit().turnCameraOn(true);
                        debugPrint('[ZegoCallService] Auto-recovered camera after dialog accept.');
                      } catch (_) {}
                    });
                  }
                },
                onReject: () async {
                  try {
                    await ZegoUIKitPrebuiltCallInvitationService().reject();
                  } catch (_) {}
                  await rejectCallFromNotification(pendingCall);
                },
              );
            } else {
              // CASE 2 / CASE 3: Another app is foreground / Our app is NOT foreground
              // Do NOT force-launch the app over another app!
              debugPrint('[ZegoCallService] App is NOT FOREGROUND -> Showing Android system notification.');
              await CallNotificationService.instance.showIncomingCallNotification(pendingCall);
            }
          },
          onOutgoingCallAccepted: (callID, callee) async {
            _callConnectedAt ??= DateTime.now();
            NetworkQualityService.instance.startMonitoring();
            await _callHistoryService.updateCallStatus(
              callId: callID,
              status: 'connected',
            );
          },
          onIncomingCallAcceptButtonPressed: () async {
            IncomingCallDecisionDialog.dismissCurrent();
            _callConnectedAt ??= DateTime.now();
            NetworkQualityService.instance.startMonitoring();
            final targetCallId = activeCallId.value.isNotEmpty
                ? activeCallId.value
                : (_currentSessionCallId ?? '');
            if (targetCallId.isNotEmpty) {
              await _callHistoryService.updateCallStatus(
                callId: targetCallId,
                status: 'connected',
              );
            }
            if (_currentSessionIsVideo) {
              Future.delayed(const Duration(milliseconds: 700), () {
                try {
                  ZegoUIKit().turnCameraOn(true);
                  debugPrint('[ZegoCallService] Auto-recovered camera after accept button press.');
                } catch (_) {}
              });
            }
          },
          onOutgoingCallDeclined: (callID, callee, customData) async {
            NetworkQualityService.instance.stopMonitoring();
            await _callHistoryService.updateCallStatus(
              callId: callID,
              status: 'rejected',
              endedAt: DateTime.now(),
              durationSeconds: 0,
            );
          },
          onOutgoingCallRejectedCauseBusy: (callID, callee, customData) async {
            NetworkQualityService.instance.stopMonitoring();
            await _callHistoryService.updateCallStatus(
              callId: callID,
              status: 'busy',
              endedAt: DateTime.now(),
              durationSeconds: 0,
            );
          },
          onIncomingCallDeclineButtonPressed: () async {
            IncomingCallDecisionDialog.dismissCurrent();
            NetworkQualityService.instance.stopMonitoring();
            final targetCallId = activeCallId.value.isNotEmpty
                ? activeCallId.value
                : (_currentSessionCallId ?? '');
            if (targetCallId.isNotEmpty) {
              await _callHistoryService.updateCallStatus(
                callId: targetCallId,
                status: 'rejected',
                endedAt: DateTime.now(),
                durationSeconds: 0,
              );
            }
          },
          onIncomingCallTimeout: (callID, caller) async {
            IncomingCallDecisionDialog.dismissCurrent(callID);
            await CallNotificationService.instance.dismissNotification(callID);
            await PendingCallManager.instance.clearPendingCall();
            NetworkQualityService.instance.stopMonitoring();
            await _callHistoryService.updateCallStatus(
              callId: callID,
              status: 'missed',
              endedAt: DateTime.now(),
              durationSeconds: 0,
            );
          },
          onIncomingCallCanceled: (callID, caller, customData) async {
            IncomingCallDecisionDialog.dismissCurrent(callID);
            await CallNotificationService.instance.dismissNotification(callID);
            await PendingCallManager.instance.clearPendingCall();
            NetworkQualityService.instance.stopMonitoring();
            await _callHistoryService.updateCallStatus(
              callId: callID,
              status: 'missed',
              endedAt: DateTime.now(),
              durationSeconds: 0,
            );
          },
          onOutgoingCallTimeout: (callID, callees, isVideoCall) async {
            NetworkQualityService.instance.stopMonitoring();
            await _callHistoryService.updateCallStatus(
              callId: callID,
              status: 'missed',
              endedAt: DateTime.now(),
              durationSeconds: 0,
            );
          },
          onOutgoingCallCancelButtonPressed: () async {
            NetworkQualityService.instance.stopMonitoring();
            final targetCallId = activeCallId.value.isNotEmpty
                ? activeCallId.value
                : (_currentSessionCallId ?? '');
            if (targetCallId.isNotEmpty) {
              _dispatchFcmCallCancel(
                receiverUid: _currentSessionTargetUid ?? '',
                callId: targetCallId,
              );
              await _callHistoryService.updateCallStatus(
                callId: targetCallId,
                status: 'ended',
                endedAt: DateTime.now(),
                durationSeconds: 0,
              );
            }
          },
        ),
        events: ZegoUIKitPrebuiltCallEvents(
          onCallEnd: (ZegoCallEndEvent event, VoidCallback defaultAction) async {
            debugPrint('ZegoCallService onCallEnd: ${event.reason}');
            NetworkQualityService.instance.stopMonitoring();

            // Ensure screen sharing is cleanly stopped and state reset on call termination
            if (isScreenSharing.value || ZegoUIKit().getScreenSharingStateNotifier().value) {
              try {
                await ZegoUIKit().stopSharingScreen();
              } catch (_) {}
            }
            isScreenSharing.value = false;

            final endCallId = activeCallId.value.isNotEmpty
                ? activeCallId.value
                : (_currentSessionCallId ?? ZegoUIKit().getRoom().id);

            int duration = 0;
            final connectedAt = _callConnectedAt;
            if (connectedAt != null) {
              duration = DateTime.now().difference(connectedAt).inSeconds;
              if (duration < 0) duration = 0;
            }

            final isDisconnected = event.reason == ZegoCallEndReason.kickOut ||
                event.reason == ZegoCallEndReason.abandoned;
            final endStatus = isDisconnected ? 'disconnected' : 'ended';

            if (endCallId.isNotEmpty) {
              await _callHistoryService.updateCallStatus(
                callId: endCallId,
                status: endStatus,
                endedAt: DateTime.now(),
                durationSeconds: duration,
              );
            }

            _callConnectedAt = null;
            _currentSessionCallId = null;
            isCalling.value = false;
            activeCallId.value = '';

            try {
              defaultAction();
            } catch (e) {
              debugPrint('defaultAction error: $e');
            }

            if (!Get.isRegistered<HomeController>()) {
              Get.put(HomeController(), permanent: true);
            }
          },
        ),
        requireConfig: (ZegoCallInvitationData data) {
          activeCallId.value = data.callID;
          _callConnectedAt ??= DateTime.now();
          NetworkQualityService.instance.startMonitoring();
          if (data.callID.isNotEmpty) {
            _callHistoryService.updateCallStatus(
              callId: data.callID,
              status: 'connected',
            );
          }
          final isGroup = data.invitees.length > 1;

          if (data.type == ZegoCallInvitationType.videoCall) {
            // Functional 1-to-1 or Multi-user Video Conference Call
            final config = isGroup
                ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
                : ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

            config.turnOnCameraWhenJoining = true;
            config.turnOnMicrophoneWhenJoining = true;
            config.useSpeakerWhenJoining = true;

            // In 1-on-1 video call, Picture-in-Picture layout displays the remote user fullscreen
            // with local preview in a corner, avoiding black screen tile issues in gallery layout
            config.layout = isGroup
                ? ZegoLayout.gallery(
                    showNewScreenSharingViewInFullscreenMode: true,
                    showScreenSharingFullscreenModeToggleButtonRules:
                        ZegoShowFullscreenModeToggleButtonRules.alwaysShow,
                  )
                : ZegoLayout.pictureInPicture(
                    isSmallViewDraggable: true,
                    switchLargeOrSmallViewByClick: true,
                    showNewScreenSharingViewInFullscreenMode: true,
                    showScreenSharingFullscreenModeToggleButtonRules:
                        ZegoShowFullscreenModeToggleButtonRules.alwaysShow,
                  );

            // Screen Sharing configuration
            config.screenSharing = ZegoCallScreenSharingConfig(
              defaultFullScreen: true,
            );

            // Real-time Network Quality Indicator overlay + Screen Sharing active indicator
            config.foreground = const Stack(
              children: [
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.only(top: 60, right: 16),
                      child: IgnorePointer(
                        child: NetworkQualityIndicator(),
                      ),
                    ),
                  ),
                ),
                ScreenSharingIndicator(),
              ],
            );

            // In-call invite button & Screen share quick action in top bar
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: CustomScreenSharingButton(
                  buttonSize: Size(34, 34),
                  iconSize: Size(18, 18),
                ),
              ),
            ];

            config.bottomMenuBar.maxCount = 6;
            config.bottomMenuBar.buttons = [
              ZegoCallMenuBarButtonName.toggleMicrophoneButton,
              ZegoCallMenuBarButtonName.toggleCameraButton,
              ZegoCallMenuBarButtonName.hangUpButton,
              ZegoCallMenuBarButtonName.switchCameraButton,
              ZegoCallMenuBarButtonName.switchAudioOutputButton,
              ZegoCallMenuBarButtonName.showMemberListButton,
            ];
            // Use custom screen sharing button to avoid Zego's internal stop-button check bug
            config.bottomMenuBar.extendButtons = [
              const CustomScreenSharingButton(),
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

      // Register screen sharing state and error listeners
      try {
        ZegoUIKit().getScreenSharingStateNotifier().removeListener(_onScreenSharingStateChanged);
        ZegoUIKit().getScreenSharingStateNotifier().addListener(_onScreenSharingStateChanged);
        _screenCaptureErrorSubscription?.cancel();
        _screenCaptureErrorSubscription = ZegoUIKit().getErrorStream().listen(_onZegoErrorReceived);
      } catch (e) {
        debugPrint('[ZegoCallService] Screen sharing listener registration error: $e');
      }

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
      NetworkQualityService.instance.stopMonitoring();
      if (!Get.testMode && (isScreenSharing.value || ZegoUIKit().getScreenSharingStateNotifier().value)) {
        try {
          await ZegoUIKit().stopSharingScreen();
        } catch (_) {}
      }
      isScreenSharing.value = false;
      if (!Get.testMode) {
        try {
          ZegoUIKit().getScreenSharingStateNotifier().removeListener(_onScreenSharingStateChanged);
          _screenCaptureErrorSubscription?.cancel();
          _screenCaptureErrorSubscription = null;
        } catch (_) {}
      }
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

  /// Internal callback invoked when ZEGOCLOUD screen sharing state changes
  void _onScreenSharingStateChanged() {
    try {
      final active = ZegoUIKit().getScreenSharingStateNotifier().value;
      isScreenSharing.value = active;
      debugPrint('[ZegoCallService] Screen sharing state updated: $active');
    } catch (e) {
      debugPrint('[ZegoCallService] _onScreenSharingStateChanged error: $e');
    }
  }

  /// Internal callback for ZEGOCLOUD error events
  void _onZegoErrorReceived(ZegoUIKitError error) {
    debugPrint('[ZegoCallService] ZegoUIKit error: code=${error.code}, msg=${error.message}');
    if (error.code == ZegoUIKitErrorCode.screenCaptureExceptionMediaProjectionPermissionDenied) {
      isScreenSharing.value = false;
      Get.snackbar(
        'Screen Sharing',
        'Screen sharing permission was cancelled or denied.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber.shade900,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    } else if (error.code == ZegoUIKitErrorCode.screenCaptureExceptionForegroundServiceFailed) {
      isScreenSharing.value = false;
      Get.snackbar(
        'Screen Sharing Failed',
        'Foreground service could not start for screen sharing.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    } else if (error.code == ZegoUIKitErrorCode.screenCaptureExceptionAlreadyStarted) {
      Get.snackbar(
        'Screen Sharing',
        'Screen sharing is already active.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blueGrey.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } else if (error.code == ZegoUIKitErrorCode.screenCaptureExceptionVideoNotSupported) {
      isScreenSharing.value = false;
      Get.snackbar(
        'Screen Sharing Unsupported',
        'Screen capture is not supported on this device version.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    } else if (error.code == ZegoUIKitErrorCode.screenCaptureExceptionSystemError) {
      isScreenSharing.value = false;
      Get.snackbar(
        'Screen Sharing Error',
        'Unable to start screen sharing. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Start screen sharing in an active call
  Future<bool> startScreenSharing() async {
    try {
      if (isScreenSharing.value) {
        debugPrint('[ZegoCallService] Screen sharing is already active.');
        return true;
      }
      if (!Get.testMode) {
        // Prevent ZegoUIKit's buggy double-start cycle on Android that immediately
        // stops and destroys the screen capture source while the system dialog is open.
        try {
          ZegoUIKitCore.shared.coreData.isFirstScreenSharing = false;
        } catch (e) {
          debugPrint('[ZegoCallService] isFirstScreenSharing override error: $e');
        }
        await ZegoUIKit().startSharingScreen();
      }
      isScreenSharing.value = true;
      debugPrint('[ZegoCallService] Screen sharing successfully initiated.');
      return true;
    } catch (e) {
      debugPrint('[ZegoCallService] startScreenSharing exception: $e');
      isScreenSharing.value = false;
      Get.snackbar(
        'Screen Sharing Error',
        'Unable to start screen sharing. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
      return false;
    }
  }

  /// Stop screen sharing cleanly without ending the call
  Future<void> stopScreenSharing() async {
    try {
      debugPrint('[ZegoCallService] Stopping screen sharing...');
      if (!Get.testMode) {
        await ZegoUIKit().stopSharingScreen();
      }
    } catch (e) {
      debugPrint('[ZegoCallService] stopScreenSharing error: $e');
    } finally {
      isScreenSharing.value = false;
      try {
        ZegoUIKit().getScreenSharingStateNotifier().value = false;
      } catch (_) {}
      debugPrint('[ZegoCallService] Screen sharing cleanly stopped.');
    }
  }

  /// Toggle screen sharing on/off
  Future<void> toggleScreenSharing() async {
    if (isScreenSharing.value) {
      await stopScreenSharing();
    } else {
      await startScreenSharing();
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
    // 0. Centralized non-bypassable block check
    if (await _blockService.isUserBlocked(targetUid: targetUser.uid)) {
      Get.snackbar(
        'Blocked User',
        'You have blocked ${targetUser.name.isNotEmpty ? targetUser.name : 'this user'}. Unblock them to make calls.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return false;
    }

    if (Get.testMode) {
      final currentUid = _authService.currentUserId ?? 'test_caller_uid';
      final callID = 'call_${currentUid}_${DateTime.now().millisecondsSinceEpoch}';
      await _callHistoryService.saveCallRecord(
        CallModel(
          id: callID,
          callerId: currentUid,
          callerName: _authService.getCurrentUser()?.displayName ?? 'Tester',
          callerPhoto: _authService.getCurrentUser()?.photoURL,
          calleeId: targetUser.uid,
          calleeName: targetUser.name,
          calleePhoto: targetUser.profileImage.isNotEmpty ? targetUser.profileImage : null,
          callType: 'audio',
          direction: 'outgoing',
          status: 'calling',
          startedAt: DateTime.now(),
          durationSeconds: 0,
        ),
      );
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
    final inviteeName = ContactService.instance.resolveDisplayName(
      phoneNumber: targetUser.phoneNumber,
      registeredName: targetUser.name,
      fallback: 'User',
    );
    final currentName = _authService.getCurrentUser()?.displayName ?? 'User';
    final currentPhone = _authService.currentUser?.phoneNumber ?? '';
    final callID = 'call_${currentUid}_${DateTime.now().millisecondsSinceEpoch}';
    _currentSessionCallId = callID;
    activeCallId.value = callID;
    _callConnectedAt = null;
    _currentSessionIsVideo = false;
    _currentSessionTargetUid = targetUser.uid;
    _currentSessionTargetName = inviteeName;
    _currentSessionTargetPhoto =
        targetUser.profileImage.isNotEmpty ? targetUser.profileImage : null;

    try {
      // Save initial outgoing call record
      await _callHistoryService.saveCallRecord(
        CallModel(
          id: callID,
          callerId: currentUid,
          callerName: currentName,
          callerPhoto: _authService.getCurrentUser()?.photoURL,
          calleeId: targetUser.uid,
          calleeName: inviteeName,
          calleePhoto: _currentSessionTargetPhoto,
          phoneNumber: targetUser.phoneNumber,
          callType: 'audio',
          direction: 'outgoing',
          status: 'calling',
          startedAt: DateTime.now(),
          durationSeconds: 0,
        ),
      );

      final customPayload = jsonEncode({
        'callerPhone': currentPhone,
        'callerName': currentName,
      });

      final bool sent = await ZegoUIKitPrebuiltCallInvitationService().send(
        invitees: [
          ZegoCallUser(targetUser.uid, inviteeName),
        ],
        isVideoCall: false, // Strict Phase 6 Requirement: AUDIO ONLY
        customData: customPayload,
        callID: callID,
        timeoutSeconds: 60,
      );

      if (sent) {
        _dispatchFcmCallPush(
          receiverUid: targetUser.uid,
          callId: callID,
          callType: 'audio',
          callerName: currentName,
          callerPhoto: _authService.getCurrentUser()?.photoURL,
        );
      } else {
        await _callHistoryService.updateCallStatus(
          callId: callID,
          status: 'failed',
          endedAt: DateTime.now(),
          durationSeconds: 0,
        );
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
      await _callHistoryService.updateCallStatus(
        callId: callID,
        status: 'failed',
        endedAt: DateTime.now(),
        durationSeconds: 0,
      );
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
    // 0. Centralized non-bypassable block check
    if (await _blockService.isUserBlocked(targetUid: targetUser.uid)) {
      Get.snackbar(
        'Blocked User',
        'You have blocked ${targetUser.name.isNotEmpty ? targetUser.name : 'this user'}. Unblock them to make calls.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return false;
    }

    if (Get.testMode) {
      final currentUid = _authService.currentUserId ?? 'test_caller_uid';
      final callID = 'call_${currentUid}_${DateTime.now().millisecondsSinceEpoch}';
      await _callHistoryService.saveCallRecord(
        CallModel(
          id: callID,
          callerId: currentUid,
          callerName: _authService.getCurrentUser()?.displayName ?? 'Tester',
          callerPhoto: _authService.getCurrentUser()?.photoURL,
          calleeId: targetUser.uid,
          calleeName: targetUser.name,
          calleePhoto: targetUser.profileImage.isNotEmpty ? targetUser.profileImage : null,
          callType: 'video',
          direction: 'outgoing',
          status: 'calling',
          startedAt: DateTime.now(),
          durationSeconds: 0,
        ),
      );
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
    final inviteeName = ContactService.instance.resolveDisplayName(
      phoneNumber: targetUser.phoneNumber,
      registeredName: targetUser.name,
      fallback: 'User',
    );
    final currentName = _authService.getCurrentUser()?.displayName ?? 'User';
    final currentPhone = _authService.currentUser?.phoneNumber ?? '';
    final callID = 'call_${currentUid}_${DateTime.now().millisecondsSinceEpoch}';
    _currentSessionCallId = callID;
    activeCallId.value = callID;
    _callConnectedAt = null;
    _currentSessionIsVideo = true;
    _currentSessionTargetUid = targetUser.uid;
    _currentSessionTargetName = inviteeName;
    _currentSessionTargetPhoto =
        targetUser.profileImage.isNotEmpty ? targetUser.profileImage : null;

    try {
      // Save initial outgoing call record
      await _callHistoryService.saveCallRecord(
        CallModel(
          id: callID,
          callerId: currentUid,
          callerName: currentName,
          callerPhoto: _authService.getCurrentUser()?.photoURL,
          calleeId: targetUser.uid,
          calleeName: inviteeName,
          calleePhoto: _currentSessionTargetPhoto,
          phoneNumber: targetUser.phoneNumber,
          callType: 'video',
          direction: 'outgoing',
          status: 'calling',
          startedAt: DateTime.now(),
          durationSeconds: 0,
        ),
      );

      final customPayload = jsonEncode({
        'callerPhone': currentPhone,
        'callerName': currentName,
      });

      final bool sent = await ZegoUIKitPrebuiltCallInvitationService().send(
        invitees: [
          ZegoCallUser(targetUser.uid, inviteeName),
        ],
        isVideoCall: true, // Strict Phase 7 Requirement: VIDEO CALL
        customData: customPayload,
        callID: callID,
        timeoutSeconds: 60,
      );

      if (sent) {
        _dispatchFcmCallPush(
          receiverUid: targetUser.uid,
          callId: callID,
          callType: 'video',
          callerName: currentName,
          callerPhoto: _authService.getCurrentUser()?.photoURL,
        );
      } else {
        await _callHistoryService.updateCallStatus(
          callId: callID,
          status: 'failed',
          endedAt: DateTime.now(),
          durationSeconds: 0,
        );
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
      await _callHistoryService.updateCallStatus(
        callId: callID,
        status: 'failed',
        endedAt: DateTime.now(),
        durationSeconds: 0,
      );
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

  // --- Phase 10: FCM Push Dispatch & Notification Entry Points ---

  Future<void> Function(PendingCallModel call)? acceptNotificationCallDelegate;
  Future<void> Function(PendingCallModel call)? rejectNotificationCallDelegate;

  void _dispatchFcmCallPush({
    required String receiverUid,
    required String callId,
    required String callType,
    required String callerName,
    String? callerPhoto,
  }) async {
    if (Get.testMode) return;
    try {
      final res = await _functions.httpsCallable('sendCallNotification').call({
        'receiverUid': receiverUid,
        'callId': callId,
        'callType': callType,
        'callerName': callerName,
        'callerZegoUserId': _authService.currentUserId,
        'callerPhoto': callerPhoto,
      });
      debugPrint('[FCM] Dispatched call notification result: ${res.data}');
    } catch (e) {
      debugPrint('[FCM] sendCallNotification error: $e');
    }
  }

  void _dispatchFcmCallCancel({required String receiverUid, required String callId}) async {
    if (Get.testMode) return;
    try {
      await _functions.httpsCallable('cancelCallNotification').call({
        'receiverUid': receiverUid,
        'callId': callId,
      });
      debugPrint('[FCM] Dispatched call cancel for call: $callId');
    } catch (e) {
      debugPrint('[FCM] cancelCallNotification error: $e');
    }
  }

  /// Accepts an incoming call received from push notification (converges into existing call pipeline)
  Future<void> acceptCallFromNotification(PendingCallModel call) async {
    debugPrint('[CALL PUSH] Existing Accept logic invoked for call: ${call.callId} (${call.callType})');

    // 1. Verify call is not expired
    if (call.isExpired) {
      debugPrint('[CALL PUSH] Pending call ${call.callId} expired. Discarding.');
      await CallNotificationService.instance.dismissNotification(call.callId);
      await PendingCallManager.instance.clearPendingCall();
      if (!Get.testMode) {
        Get.snackbar(
          'Call Expired',
          'This incoming call invitation has expired.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.amber.shade800,
          colorText: Colors.white,
        );
      }
      return;
    }

    // 2. Centralized non-bypassable block check
    if (await _blockService.isUserBlocked(targetUid: call.callerUid)) {
      debugPrint('[CALL PUSH] Rejecting call from blocked user ${call.callerUid}');
      await rejectCallFromNotification(call);
      return;
    }

    // 3. Dismiss notification and clear pending state
    await CallNotificationService.instance.dismissNotification(call.callId);
    await PendingCallManager.instance.clearPendingCall();

    if (acceptNotificationCallDelegate != null) {
      await acceptNotificationCallDelegate!(call);
      return;
    }

    // 4. Ensure CallService is initialized and token is ready
    if (!isInitialized.value) {
      final ok = await initZegoCallService();
      if (!ok && !Get.testMode) {
        debugPrint('[CALL PUSH] Failed to initialize ZegoCallService on accept.');
        return;
      }
    }

    // Ensure permissions are acquired before entering room without redundant re-requesting
    if (!Get.testMode) {
      try {
        if (call.isVideo) {
          final cameraGranted = await Permission.camera.isGranted;
          final micGranted = await Permission.microphone.isGranted;
          if (!cameraGranted || !micGranted) {
            await [Permission.camera, Permission.microphone].request();
          }
        } else {
          final micGranted = await Permission.microphone.isGranted;
          if (!micGranted) {
            await Permission.microphone.request();
          }
        }
      } catch (e) {
        debugPrint('[CALL PUSH] Permission request error: $e');
      }
    }

    // 4a. Accept the incoming invitation via ZEGOCLOUD signaling so the caller is notified,
    // ringtones on both devices stop, and the call connects
    bool acceptedByZego = false;
    if (!Get.testMode) {
      for (int i = 0; i < 6; i++) {
        try {
          acceptedByZego = await ZegoUIKitPrebuiltCallInvitationService().accept();
          if (acceptedByZego) {
            debugPrint('[CALL PUSH] ZEGOCLOUD accepted call on attempt ${i + 1}');
            break;
          }
        } catch (e) {
          debugPrint('[CALL PUSH] Zego accept attempt $i error: $e');
        }
        await Future.delayed(const Duration(milliseconds: 250));
      }

      if (!acceptedByZego) {
        try {
          await ZegoUIKit().getSignalingPlugin().acceptInvitation(
            inviterID: call.callerUid,
            data: '',
          );
          debugPrint('[CALL PUSH] Accepted invitation via ZIM signaling plugin for call: ${call.callId}');
        } catch (e) {
          debugPrint('[CALL PUSH] ZIM signaling accept error: $e');
        }
      }
    }

    ZegoTokenResponse tokenData;
    if (_cachedTokenResponse != null && _cachedTokenResponse!.isValid) {
      tokenData = _cachedTokenResponse!;
    } else {
      try {
        tokenData = await getZegoToken();
        _cachedTokenResponse = tokenData;
      } catch (e) {
        debugPrint('[CALL PUSH] Error getting token on accept: $e');
        tokenData = ZegoTokenResponse(
          appId: _cachedTokenResponse?.appId ?? 0,
          token: '',
          userId: _authService.currentUserId ?? '',
          expiresIn: 3600,
        );
      }
    }

    activeCallId.value = call.callId;
    _currentSessionCallId = call.callId;
    _callConnectedAt = DateTime.now();
    _currentSessionIsVideo = call.isVideo;
    _currentSessionTargetUid = call.callerUid;
    _currentSessionTargetName = call.callerName;

    // 5. Update local SQLite call history
    final currentUid = _authService.currentUserId ?? '';
    final currentName = _authService.getCurrentUser()?.displayName ?? 'User';

    await _callHistoryService.saveCallRecord(
      CallModel(
        id: call.callId,
        callerId: call.callerUid,
        callerName: call.callerName,
        callerPhoto: call.callerPhoto,
        calleeId: currentUid,
        calleeName: currentName,
        calleePhoto: _authService.getCurrentUser()?.photoURL,
        callType: call.callType,
        direction: 'incoming',
        status: 'connected',
        startedAt: DateTime.now(),
        durationSeconds: 0,
      ),
    );

    if (Get.testMode) return;

    // If acceptedByZego is true, ZEGOCLOUD's invitation service automatically enters
    // the call room and presents the prebuilt call screen via requireConfig!
    if (acceptedByZego) {
      debugPrint('[CALL PUSH] Call connected via ZEGOCLOUD invitation service. Skipping manual navigation.');
      if (call.isVideo) {
        Future.delayed(const Duration(milliseconds: 700), () {
          try {
            ZegoUIKit().turnCameraOn(true);
            debugPrint('[ZegoCallService] Auto-recovered camera after notification accept.');
          } catch (_) {}
        });
      }
      return;
    }

    if (!acceptedByZego && !Get.testMode) {
      debugPrint('[CALL PUSH] Call invitation is no longer active or was cancelled by caller. Aborting room entry.');
      await _callHistoryService.updateCallStatus(
        callId: call.callId,
        status: 'missed',
        endedAt: DateTime.now(),
        durationSeconds: 0,
      );
      activeCallId.value = '';
      _currentSessionCallId = null;
      _callConnectedAt = null;
      Get.snackbar(
        'Call Ended',
        'The caller has already ended this call.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blueGrey.shade800,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Ensure we transition from splash to home so the call page has a stable parent route
    if (Get.currentRoute == AppRoutes.splash || Get.currentRoute.isEmpty) {
      Get.offAllNamed(AppRoutes.home);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // 6. Navigate to active call screen if not already entered by ZEGOCLOUD
    final nav = navigatorKey.currentState ?? Get.key.currentState;
    if (nav != null) {
      if (call.isVideo) {
        final config = ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();
        config.turnOnCameraWhenJoining = true;
        config.turnOnMicrophoneWhenJoining = true;
        config.useSpeakerWhenJoining = true;
        config.layout = ZegoLayout.pictureInPicture(
          isSmallViewDraggable: true,
          switchLargeOrSmallViewByClick: true,
        );
        config.audioVideoView.useVideoViewAspectFill = true;
        config.audioVideoView.showCameraStateOnView = true;
        config.audioVideoView.showMicrophoneStateOnView = true;
        config.audioVideoView.showUserNameOnView = true;
        config.screenSharing = ZegoCallScreenSharingConfig(
          defaultFullScreen: true,
        );
        config.bottomMenuBar.maxCount = 6;
        config.bottomMenuBar.buttons = [
          ZegoCallMenuBarButtonName.toggleMicrophoneButton,
          ZegoCallMenuBarButtonName.toggleCameraButton,
          ZegoCallMenuBarButtonName.hangUpButton,
          ZegoCallMenuBarButtonName.switchCameraButton,
          ZegoCallMenuBarButtonName.switchAudioOutputButton,
          ZegoCallMenuBarButtonName.showMemberListButton,
        ];
        config.bottomMenuBar.extendButtons = [
          const CustomScreenSharingButton(),
        ];
        config.foreground = const Stack(
          children: [
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 60, right: 16),
                  child: IgnorePointer(
                    child: NetworkQualityIndicator(),
                  ),
                ),
              ),
            ),
            ScreenSharingIndicator(),
          ],
        );
        nav.push(
          MaterialPageRoute(
            builder: (context) => ZegoUIKitPrebuiltCall(
              appID: tokenData.appId,
              token: tokenData.token,
              userID: currentUid,
              userName: currentName,
              callID: call.callId,
              config: config,
              events: ZegoUIKitPrebuiltCallEvents(
                onCallEnd: (event, defaultAction) async {
                  _handleCallEndCleanUp(event, defaultAction);
                },
              ),
            ),
          ),
        );
      } else {
        final config = ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();
        config.turnOnCameraWhenJoining = false;
        config.turnOnMicrophoneWhenJoining = true;
        config.useSpeakerWhenJoining = true;
        config.topMenuBar.isVisible = false;
        config.bottomMenuBar.buttons = [];
        config.audioVideoView.showCameraStateOnView = false;
        config.audioVideoView.showSoundWavesInAudioMode = true;
        config.audioVideoView.showAvatarInAudioMode = true;
        config.foreground = const CustomAudioCallingView();
        nav.push(
          MaterialPageRoute(
            builder: (context) => ZegoUIKitPrebuiltCall(
              appID: tokenData.appId,
              token: tokenData.token,
              userID: currentUid,
              userName: currentName,
              callID: call.callId,
              config: config,
              events: ZegoUIKitPrebuiltCallEvents(
                onCallEnd: (event, defaultAction) async {
                  _handleCallEndCleanUp(event, defaultAction);
                },
              ),
            ),
          ),
        );
      }
    }
  }

  /// Rejects an incoming call received from push notification (converges into existing call pipeline)
  Future<void> rejectCallFromNotification(PendingCallModel call) async {
    debugPrint('[CALL PUSH] Existing Reject logic invoked for call: ${call.callId}');

    // 1. Dismiss notification and stop ringtone
    await CallNotificationService.instance.dismissNotification(call.callId);
    await PendingCallManager.instance.clearPendingCall();

    if (rejectNotificationCallDelegate != null) {
      await rejectNotificationCallDelegate!(call);
      return;
    }

    // 2. Reject via ZEGOCLOUD signaling if active
    if (!Get.testMode) {
      bool rejected = false;
      for (int i = 0; i < 4; i++) {
        try {
          rejected = await ZegoUIKitPrebuiltCallInvitationService().reject();
          if (rejected) break;
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 200));
      }
      try {
        await ZegoUIKit().getSignalingPlugin().refuseInvitation(
          inviterID: call.callerUid,
          data: '',
        );
      } catch (_) {}
    }

    // 3. Save or update call record in SQLite call history as 'rejected'
    final currentUid = _authService.currentUserId ?? '';
    final currentName = _authService.getCurrentUser()?.displayName ?? 'User';

    await _callHistoryService.saveCallRecord(
      CallModel(
        id: call.callId,
        callerId: call.callerUid,
        callerName: call.callerName,
        callerPhoto: call.callerPhoto,
        calleeId: currentUid,
        calleeName: currentName,
        calleePhoto: _authService.getCurrentUser()?.photoURL,
        callType: call.callType,
        direction: 'incoming',
        status: 'rejected',
        startedAt: call.timestamp,
        endedAt: DateTime.now(),
        durationSeconds: 0,
      ),
    );
  }

  void _handleCallEndCleanUp(ZegoCallEndEvent event, VoidCallback defaultAction) async {
    // Ensure screen sharing cleanly stops on call termination
    if (isScreenSharing.value || ZegoUIKit().getScreenSharingStateNotifier().value) {
      try {
        await ZegoUIKit().stopSharingScreen();
      } catch (_) {}
    }
    isScreenSharing.value = false;

    final endCallId = activeCallId.value.isNotEmpty
        ? activeCallId.value
        : (_currentSessionCallId ?? ZegoUIKit().getRoom().id);

    int duration = 0;
    final connectedAt = _callConnectedAt;
    if (connectedAt != null) {
      duration = DateTime.now().difference(connectedAt).inSeconds;
      if (duration < 0) duration = 0;
    }

    final isDisconnected = event.reason == ZegoCallEndReason.kickOut ||
        event.reason == ZegoCallEndReason.abandoned;
    final endStatus = isDisconnected ? 'disconnected' : 'ended';

    if (endCallId.isNotEmpty) {
      await _callHistoryService.updateCallStatus(
        callId: endCallId,
        status: endStatus,
        endedAt: DateTime.now(),
        durationSeconds: duration,
      );
    }

    _callConnectedAt = null;
    _currentSessionCallId = null;
    isCalling.value = false;
    activeCallId.value = '';

    try {
      if (_currentSessionTargetUid != null && _currentSessionTargetUid!.isNotEmpty && endCallId.isNotEmpty) {
        _dispatchFcmCallCancel(
          receiverUid: _currentSessionTargetUid!,
          callId: endCallId,
        );
      }
    } catch (_) {}

    try {
      defaultAction();
    } catch (_) {}

    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController(), permanent: true);
    }
  }
}
