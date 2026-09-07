import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/zego_call_service.dart';

class ContactsController extends GetxController {
  final UserService _userService;
  final AuthService _authService;
  final ZegoCallService? zegoCallService;
  final String? currentUserIdOverride;

  ContactsController({
    UserService? userService,
    AuthService? authService,
    this.zegoCallService,
    this.currentUserIdOverride,
  })  : _userService = userService ?? UserService(),
        _authService = authService ?? AuthService();

  ZegoCallService get activeCallService =>
      zegoCallService ?? ZegoCallService.instance;

  // Reactive state
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString searchQuery = ''.obs;

  // Search text controller for managing the search field
  final TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadUsers();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  // Load all users from Firestore and filter out the currently logged in user
  Future<void> loadUsers() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final allUsers = await _userService.getUsers();
      final String? currentUserId =
          currentUserIdOverride ?? _authService.currentUserId;

      // Filter out the current user safely
      final otherUsers = currentUserId != null && currentUserId.isNotEmpty
          ? allUsers.where((user) => user.uid != currentUserId).toList()
          : allUsers;

      users.assignAll(otherUsers);
    } catch (e) {
      errorMessage.value = 'Unable to load contacts';
    } finally {
      isLoading.value = false;
    }
  }

  // Reactive search query update
  void onSearchChanged(String query) {
    searchQuery.value = query;
  }

  // Clear search field and filter
  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  // Case-insensitive client-side filtered users by name or email
  List<UserModel> get filteredUsers {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) {
      return users;
    }

    return users.where((user) {
      final matchesName = user.name.toLowerCase().contains(query);
      final matchesEmail = user.email.toLowerCase().contains(query);
      return matchesName || matchesEmail;
    }).toList();
  }

  // Audio call action: initiates real 1-to-1 audio call via ZegoCallService
  Future<void> onAudioCallTap(UserModel user) async {
    await activeCallService.sendAudioCallInvitation(targetUser: user);
  }

  // Video call action: placeholder for Phase 7
  void onVideoCallTap(UserModel user) {
    Get.snackbar(
      'Video Call',
      'Video calling will be available in Phase 7. Use the green audio call button for voice calls.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.primaryColor,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }
}
