import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../core/utils/phone_number_util.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/contact_service.dart';
import '../../services/user_service.dart';
import '../../services/zego_call_service.dart';

enum ContactsPermissionState {
  initial,
  granted,
  denied,
  permanentlyDenied,
}

class ContactsController extends GetxController {
  final ContactService _contactService;
  final UserService _userService;
  final AuthService _authService;
  final ZegoCallService? zegoCallService;
  final String? currentUserIdOverride;
  final String? currentUserPhoneOverride;

  ContactsController({
    ContactService? contactService,
    UserService? userService,
    AuthService? authService,
    this.zegoCallService,
    this.currentUserIdOverride,
    this.currentUserPhoneOverride,
  })  : _contactService = contactService ?? ContactService(),
        _userService = userService ?? UserService(),
        _authService = authService ?? AuthService();

  ZegoCallService get activeCallService =>
      zegoCallService ?? ZegoCallService.instance;

  // Reactive state
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isNetworkError = false.obs;
  final RxString searchQuery = ''.obs;
  final Rx<ContactsPermissionState> permissionState =
      ContactsPermissionState.initial.obs;

  // Search text controller for managing the search field
  final TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    initContacts();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Initial entry point: checks permission and loads contacts if granted,
  /// or requests permission if not determined yet.
  Future<void> initContacts() async {
    final status = await _contactService.checkPermission();
    if (status.isGranted) {
      permissionState.value = ContactsPermissionState.granted;
      await loadContacts();
    } else if (status.isPermanentlyDenied) {
      permissionState.value = ContactsPermissionState.permanentlyDenied;
    } else {
      // Prompt user for permission on first visit
      await requestPermission();
    }
  }

  /// Explicitly requests permission (e.g. from 'Grant Permission' button).
  Future<void> requestPermission() async {
    errorMessage.value = '';
    isNetworkError.value = false;
    final status = await _contactService.requestPermission();
    if (status.isGranted) {
      permissionState.value = ContactsPermissionState.granted;
      await loadContacts();
    } else if (status.isPermanentlyDenied) {
      permissionState.value = ContactsPermissionState.permanentlyDenied;
    } else {
      permissionState.value = ContactsPermissionState.denied;
    }
  }

  /// Opens the device app settings screen when permission is permanently denied.
  Future<void> openSettings() async {
    await _contactService.openAppSettings();
  }

  /// Reads contacts from local device, normalizes phone numbers,
  /// matches them with registered Firebase users, and updates state.
  Future<void> loadContacts() async {
    isLoading.value = true;
    errorMessage.value = '';
    isNetworkError.value = false;

    try {
      // 1. Read normalized numbers from local contacts
      final deviceNumbers = await _contactService.getNormalizedPhoneNumbers();

      // 2. Identify current user info to exclude
      final currentUid = currentUserIdOverride ?? _authService.currentUserId;
      final currentRawPhone = currentUserPhoneOverride ?? _authService.currentUser?.phoneNumber;
      final currentNormalizedPhone = PhoneNumberUtil.normalize(currentRawPhone);

      // 3. Exclude current user's number from query list
      final filteredNumbers = deviceNumbers.where((phone) {
        if (currentNormalizedPhone != null && phone == currentNormalizedPhone) {
          return false;
        }
        return true;
      }).toList();

      if (filteredNumbers.isEmpty) {
        users.clear();
        return;
      }

      // 4. Batch query Firestore (chunks of 30 max)
      final matchedUsers = await _userService.matchUsersByPhoneNumbers(filteredNumbers);

      // 5. Exclude current user by UID and current phone number if returned
      final safeUsers = matchedUsers.where((u) {
        if (currentUid != null && currentUid.isNotEmpty && u.uid == currentUid) {
          return false;
        }
        if (currentNormalizedPhone != null &&
            u.effectiveNormalizedPhone == currentNormalizedPhone) {
          return false;
        }
        return true;
      }).toList();

      // 6. Deduplicate by UID
      final Map<String, UserModel> dedupMap = {};
      for (final u in safeUsers) {
        dedupMap[u.uid] = u;
      }

      users.assignAll(dedupMap.values.toList());
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') ||
          errorStr.contains('unavailable') ||
          errorStr.contains('connection')) {
        isNetworkError.value = true;
        errorMessage.value = 'Network error. Please check your connection.';
      } else {
        errorMessage.value = 'Something went wrong while finding contacts.';
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Backward-compatible alias for refreshing or loading users
  Future<void> loadUsers() async {
    if (permissionState.value == ContactsPermissionState.granted) {
      await loadContacts();
    } else {
      await initContacts();
    }
  }

  /// Refresh action invoked by pull-to-refresh
  Future<void> refreshContacts() => loadUsers();

  // Reactive search query update
  void onSearchChanged(String query) {
    searchQuery.value = query;
  }

  // Clear search field and filter
  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  // Case-insensitive client-side filtered users by name or phone number
  List<UserModel> get filteredUsers {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) {
      return users;
    }

    return users.where((user) {
      final matchesName = user.name.toLowerCase().contains(query);
      final matchesPhone = user.phoneNumber.toLowerCase().contains(query);
      return matchesName || matchesPhone;
    }).toList();
  }

  // Audio call action: initiates real 1-to-1 audio call via ZegoCallService
  Future<void> onAudioCallTap(UserModel user) async {
    await activeCallService.sendAudioCallInvitation(targetUser: user);
  }

  // Video call action: initiates real 1-to-1 video call via ZegoCallService
  Future<void> onVideoCallTap(UserModel user) async {
    await activeCallService.sendVideoCallInvitation(targetUser: user);
  }
}
