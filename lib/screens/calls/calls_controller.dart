import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/call_history_service.dart';
import '../../services/user_service.dart';
import '../../services/zego_call_service.dart';

/// CallsController manages the state, real-time synchronization, and interactions
/// for the Call History screen using GetX.
class CallsController extends GetxController {
  final CallHistoryService _callHistoryService;
  final AuthService _authService;
  final UserService _userService;
  final ZegoCallService? zegoCallService;

  CallsController({
    CallHistoryService? callHistoryService,
    AuthService? authService,
    UserService? userService,
    this.zegoCallService,
  })  : _callHistoryService = callHistoryService ?? CallHistoryService.instance,
        _authService = authService ?? AuthService(),
        _userService = userService ?? UserService();

  ZegoCallService get _callService =>
      zegoCallService ?? ZegoCallService.instance;

  // Observables
  final RxList<CallModel> callHistory = <CallModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  StreamSubscription<List<CallModel>>? _historySubscription;

  String? get currentUid => _authService.currentUserId;

  @override
  void onInit() {
    super.onInit();
    loadHistory();
    _subscribeToHistoryStream();
  }

  @override
  void onClose() {
    _historySubscription?.cancel();
    super.onClose();
  }

  /// Subscribe to real-time Firestore stream for instant call updates
  void _subscribeToHistoryStream() {
    if (Get.testMode) return;

    _historySubscription?.cancel();
    _historySubscription =
        _callHistoryService.getCallHistoryStream().listen((records) {
      callHistory.assignAll(records);
      hasError.value = false;
      errorMessage.value = '';
    }, onError: (e) {
      debugPrint('CallsController._historySubscription error: $e');
      if (callHistory.isEmpty) {
        hasError.value = true;
        errorMessage.value = 'Unable to load call history.';
      }
    });
  }

  /// Fetch call history with loading and error state management
  Future<void> loadHistory() async {
    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';

    try {
      final records = await _callHistoryService.getCallHistory();
      callHistory.assignAll(records);
      hasError.value = false;
    } catch (e) {
      debugPrint('CallsController.loadHistory error: $e');
      hasError.value = true;
      errorMessage.value = 'Unable to load call history.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Redial participant from history record (audio or video)
  Future<void> redialCall(CallModel call) async {
    final otherUid = call.getOtherUserId(currentUid);
    final otherName = call.getOtherUserName(currentUid);
    final otherPhoto = call.getOtherUserPhoto(currentUid) ?? '';

    if (otherUid.isEmpty) {
      Get.snackbar(
        'Cannot Place Call',
        'User information is unavailable.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Attempt to load fresh UserModel from Firestore; fallback to call metadata
    UserModel targetUser;
    final freshUser = await _userService.getUser(otherUid);
    if (freshUser != null) {
      targetUser = freshUser;
    } else {
      targetUser = UserModel(
        uid: otherUid,
        name: otherName,
        email: '',
        profileImage: otherPhoto,
        createdAt: DateTime.now(),
      );
    }

    if (call.isVideo) {
      await _callService.sendVideoCallInvitation(targetUser: targetUser);
    } else {
      await _callService.sendAudioCallInvitation(targetUser: targetUser);
    }
  }

  /// Delete a call record from history
  Future<void> deleteCall(String callId) async {
    final success = await _callHistoryService.deleteCallRecord(callId);
    if (success) {
      callHistory.removeWhere((c) => c.id == callId);
    }
  }
}
