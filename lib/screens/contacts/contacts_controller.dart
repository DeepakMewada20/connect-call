import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../core/utils/phone_number_util.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/block_service.dart';
import '../../services/contact_service.dart';
import '../../services/favorite_service.dart';
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
  final BlockService _blockService;
  final FavoriteService _favoriteService;
  final ZegoCallService? zegoCallService;
  final String? currentUserIdOverride;
  final String? currentUserPhoneOverride;

  ContactsController({
    ContactService? contactService,
    UserService? userService,
    AuthService? authService,
    BlockService? blockService,
    FavoriteService? favoriteService,
    this.zegoCallService,
    this.currentUserIdOverride,
    this.currentUserPhoneOverride,
  })  : _contactService = contactService ?? ContactService(),
        _userService = userService ?? UserService(),
        _authService = authService ?? AuthService(),
        _blockService = blockService ?? BlockService.instance,
        _favoriteService = favoriteService ?? FavoriteService.instance;

  ZegoCallService get activeCallService =>
      zegoCallService ?? ZegoCallService.instance;

  // Reactive state
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxList<DeviceContact> deviceContacts = <DeviceContact>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isNetworkError = false.obs;
  final RxString searchQuery = ''.obs;
  final Rx<ContactsPermissionState> permissionState =
      ContactsPermissionState.initial.obs;

  // Remote smart search reactive state
  final RxBool isSearchingRemote = false.obs;
  final Rx<UserModel?> remoteSearchedUser = Rx<UserModel?>(null);
  final RxBool remoteSearchNotFound = false.obs;
  final RxBool isSelfNumberSearched = false.obs;
  final RxString remoteSearchError = ''.obs;

  // In-memory cache to prevent duplicate Firestore requests during screen session
  final Map<String, UserModel?> _searchedNumberCache = {};
  Timer? _searchDebounceTimer;

  // Search text controller for managing the search field
  final TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _blockService.initBlockedUsersListener();
      _favoriteService.initFavoritesListener();
      initContacts();
    });
  }

  @override
  void onClose() {
    _searchDebounceTimer?.cancel();
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
      // 1. Read contacts from local device and store deviceContacts
      final rawContacts = await _contactService.getContacts();
      deviceContacts.assignAll(rawContacts);

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

  // Reactive search query update with smart 10-digit number detection
  void onSearchChanged(String query) {
    searchQuery.value = query;
    _searchDebounceTimer?.cancel();

    // Reset previous remote search states
    isSearchingRemote.value = false;
    remoteSearchedUser.value = null;
    remoteSearchNotFound.value = false;
    isSelfNumberSearched.value = false;
    remoteSearchError.value = '';

    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Check if query could be a phone number
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(trimmed);

    // If query has alphabetic characters or fewer than 10 digits, keep to local contacts
    if (hasLetters || digitsOnly.length < 10) {
      return;
    }

    // Check if valid phone format
    if (!PhoneNumberUtil.isValid(trimmed)) {
      return;
    }

    final normalized = PhoneNumberUtil.normalize(trimmed);
    if (normalized == null || normalized.isEmpty) {
      return;
    }

    // Priority 1: Check local contacts first.
    // If a matching registered user already exists locally, do NOT query Firestore!
    final hasLocalMatch = users.any((u) {
      final userNorm = u.effectiveNormalizedPhone;
      final userPhoneNorm = PhoneNumberUtil.normalize(u.phoneNumber);
      return userNorm == normalized || userPhoneNorm == normalized;
    });

    if (hasLocalMatch) {
      return;
    }

    // Priority 2: Current user protection
    final currentUid = currentUserIdOverride ?? _authService.currentUserId;
    final currentRawPhone = currentUserPhoneOverride ?? _authService.currentUser?.phoneNumber;
    final currentNormalizedPhone = PhoneNumberUtil.normalize(currentRawPhone);

    if (currentNormalizedPhone != null && normalized == currentNormalizedPhone) {
      isSelfNumberSearched.value = true;
      final currentName = _authService.currentUser?.displayName;
      remoteSearchedUser.value = UserModel(
        uid: currentUid ?? 'self',
        name: (currentName != null && currentName.isNotEmpty) ? currentName : 'You',
        phoneNumber: currentRawPhone ?? normalized,
        normalizedPhoneNumber: normalized,
        createdAt: DateTime.now(),
      );
      return;
    }

    // Priority 3: Debounce and perform exact Firestore lookup
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      performRemoteSearch(normalized);
    });
  }

  /// Performs exact remote lookup with in-memory caching
  Future<void> performRemoteSearch(String normalized) async {
    // Check in-memory cache to prevent duplicate network calls
    if (_searchedNumberCache.containsKey(normalized)) {
      final cachedUser = _searchedNumberCache[normalized];
      if (cachedUser != null) {
        remoteSearchedUser.value = cachedUser;
      } else {
        remoteSearchNotFound.value = true;
      }
      return;
    }

    isSearchingRemote.value = true;
    remoteSearchError.value = '';

    try {
      final user = await _userService.getUserByPhoneNumber(normalized);
      _searchedNumberCache[normalized] = user;

      // Discard if user changed query while searching
      final currentNormalized = PhoneNumberUtil.normalize(searchQuery.value.trim());
      if (currentNormalized != normalized) {
        return;
      }

      if (user != null) {
        final currentUid = currentUserIdOverride ?? _authService.currentUserId;
        if (currentUid != null && currentUid.isNotEmpty && user.uid == currentUid) {
          isSelfNumberSearched.value = true;
        }
        remoteSearchedUser.value = user;
      } else {
        remoteSearchNotFound.value = true;
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') ||
          errorStr.contains('unavailable') ||
          errorStr.contains('connection')) {
        remoteSearchError.value = 'Network error. Please check your connection.';
      } else {
        remoteSearchError.value = 'Failed to search registered user.';
      }
    } finally {
      isSearchingRemote.value = false;
    }
  }

  void retryRemoteSearch() {
    final normalized = PhoneNumberUtil.normalize(searchQuery.value.trim());
    if (normalized != null && normalized.isNotEmpty) {
      performRemoteSearch(normalized);
    }
  }

  // Clear search field and filter
  void clearSearch() {
    _searchDebounceTimer?.cancel();
    searchController.clear();
    searchQuery.value = '';
    isSearchingRemote.value = false;
    remoteSearchedUser.value = null;
    remoteSearchNotFound.value = false;
    isSelfNumberSearched.value = false;
    remoteSearchError.value = '';
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

  // --- Phase 5: Device Contact Management & Linkage ---

  /// Finds the corresponding device contact for a given registered user, if any
  DeviceContact? findDeviceContactForUser(UserModel user) {
    final userNorm = user.effectiveNormalizedPhone;
    final userPhoneNorm = PhoneNumberUtil.normalize(user.phoneNumber);
    for (final dc in deviceContacts) {
      for (final p in dc.phones) {
        final norm = PhoneNumberUtil.normalize(p);
        if (norm == userNorm || (userPhoneNorm != null && norm == userPhoneNorm)) {
          return dc;
        }
      }
    }
    return null;
  }

  /// Adds a new contact to device phonebook and refreshes contacts
  Future<bool> addContact({required String name, required String phoneNumber}) async {
    try {
      final contactId = await _contactService.createContact(name: name, phoneNumber: phoneNumber);
      if (contactId.isNotEmpty) {
        await loadContacts();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Updates an existing contact in the device phonebook and refreshes contacts
  Future<bool> updateContact({
    required String contactId,
    required String newName,
    required String newPhoneNumber,
  }) async {
    try {
      final success = await _contactService.updateContact(
        id: contactId,
        name: newName,
        phoneNumber: newPhoneNumber,
      );
      if (success) {
        await loadContacts();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a contact from the device phonebook and refreshes contacts
  Future<bool> deleteContact(String contactId) async {
    try {
      final success = await _contactService.deleteContact(contactId);
      if (success) {
        await loadContacts();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // --- Phase 5: Favorites ---

  bool isFavorite(String userId) => _favoriteService.isFavoriteSync(userId);

  Future<void> toggleFavorite(UserModel user) async {
    await _favoriteService.toggleFavoriteUser(user);
  }

  // --- Phase 5: Block & Unblock ---

  bool isBlocked(String userId) => _blockService.isBlockedSync(userId);

  Future<void> blockUser(UserModel user) async {
    await _blockService.blockUser(blockedUserUid: user.uid);
  }

  Future<void> unblockUser(String userId) async {
    await _blockService.unblockUser(blockedUserUid: userId);
  }
}
