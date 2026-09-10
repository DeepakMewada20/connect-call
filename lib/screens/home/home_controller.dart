import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../models/call_model.dart';
import '../../models/favorite_contact_model.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/block_service.dart';
import '../../services/call_history_service.dart';
import '../../services/favorite_service.dart';
import '../../services/user_service.dart';
import '../../services/zego_call_service.dart';
import '../calls/calls_controller.dart';
import '../contacts/contacts_controller.dart';

class HomeController extends GetxController {
  final AuthService _authService;
  final UserService _userService;
  final CallHistoryService _callHistoryService;
  final BlockService _blockService;
  final FavoriteService _favoriteService;
  final ZegoCallService? zegoCallService;

  HomeController({
    AuthService? authService,
    UserService? userService,
    CallHistoryService? callHistoryService,
    BlockService? blockService,
    FavoriteService? favoriteService,
    this.zegoCallService,
  })  : _authService = authService ?? AuthService(),
        _userService = userService ?? UserService(),
        _callHistoryService = callHistoryService ?? CallHistoryService.instance,
        _blockService = blockService ?? BlockService.instance,
        _favoriteService = favoriteService ?? FavoriteService.instance;

  ZegoCallService get activeCallService =>
      zegoCallService ?? ZegoCallService.instance;

  // Observables
  final RxList<CallModel> recentCalls = <CallModel>[].obs;
  StreamSubscription<List<CallModel>>? _recentCallsSubscription;

  // Phase 5 Observables
  final RxList<FavoriteContactModel> favoriteContacts = <FavoriteContactModel>[].obs;
  final RxList<UserModel> mostCalledContacts = <UserModel>[].obs;
  final RxMap<String, int> mostCalledCounts = <String, int>{}.obs;
  final RxBool isLoadingHomeContacts = false.obs;

  StreamSubscription<List<FavoriteContactModel>>? _favoritesSubscription;
  StreamSubscription<Set<String>>? _blockedSubscription;

  String? get currentUid => _authService.currentUserId;

  @override
  void onInit() {
    super.onInit();
    _blockService.initBlockedUsersListener();
    _favoriteService.initFavoritesListener();
    _subscribeToFavoritesAndBlocks();
  }

  @override
  void onReady() {
    super.onReady();
    // Initialize ZEGOCLOUD call listener in background when entering home
    if (!Get.testMode) {
      activeCallService.initZegoCallService();
      _ensureUserDocumentExists();
      _subscribeToRecentCalls();
    }
    loadHomeContacts();
  }

  @override
  void onClose() {
    _recentCallsSubscription?.cancel();
    _favoritesSubscription?.cancel();
    _blockedSubscription?.cancel();
    super.onClose();
  }

  void _subscribeToFavoritesAndBlocks() {
    _favoritesSubscription = _favoriteService.favorites.listen((favs) {
      final nonBlocked = favs.where((f) => !_blockService.isBlockedSync(f.userId)).toList();
      favoriteContacts.assignAll(nonBlocked);
      if (favoriteContacts.isEmpty) {
        _computeMostCalled();
      } else {
        mostCalledContacts.clear();
        mostCalledCounts.clear();
      }
    });
    _blockedSubscription = _blockService.blockedUserIds.listen((_) {
      final nonBlocked = _favoriteService.favorites.where((f) => !_blockService.isBlockedSync(f.userId)).toList();
      favoriteContacts.assignAll(nonBlocked);
      if (favoriteContacts.isEmpty) {
        _computeMostCalled();
      } else {
        mostCalledContacts.clear();
        mostCalledCounts.clear();
      }
    });
  }

  Future<void> loadHomeContacts() async {
    isLoadingHomeContacts.value = true;
    try {
      // 1. Fetch favorite contacts
      final allFavs = await _favoriteService.getFavorites();
      final nonBlockedFavs = allFavs.where((f) => !_blockService.isBlockedSync(f.userId)).toList();
      favoriteContacts.assignAll(nonBlockedFavs);

      // 2. If no favorites, calculate most frequently called from SQLite Call History
      if (favoriteContacts.isEmpty) {
        await _computeMostCalled();
      } else {
        mostCalledContacts.clear();
        mostCalledCounts.clear();
      }
    } catch (e) {
      debugPrint('HomeController.loadHomeContacts error: $e');
    } finally {
      isLoadingHomeContacts.value = false;
    }
  }

  Future<void> _computeMostCalled() async {
    try {
      final history = await _callHistoryService.getCallHistory(limit: 100);
      final myUid = currentUid ?? '';

      final Map<String, int> counts = {};
      final Map<String, CallModel> latestCallsByUser = {};

      for (final call in history) {
        final otherUid = call.getOtherUserId(myUid);
        if (otherUid.isEmpty || otherUid == myUid) continue;
        if (_blockService.isBlockedSync(otherUid)) continue;

        counts[otherUid] = (counts[otherUid] ?? 0) + 1;
        latestCallsByUser.putIfAbsent(otherUid, () => call);
      }

      // Sort by call count descending
      final sortedUids = counts.keys.toList()
        ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));

      final topUids = sortedUids.take(5).toList();
      final List<UserModel> topUsers = [];
      mostCalledCounts.clear();

      for (final uid in topUids) {
        mostCalledCounts[uid] = counts[uid] ?? 1;
        final call = latestCallsByUser[uid]!;
        final otherName = call.getOtherUserName(myUid);
        final otherPhoto = call.getOtherUserPhoto(myUid) ?? '';
        topUsers.add(UserModel(
          uid: uid,
          name: otherName,
          phoneNumber: '',
          profileImage: otherPhoto,
          createdAt: DateTime.now(),
        ));
      }

      mostCalledContacts.assignAll(topUsers);
    } catch (e) {
      debugPrint('HomeController._computeMostCalled error: $e');
    }
  }

  void _subscribeToRecentCalls() {
    _recentCallsSubscription?.cancel();
    _recentCallsSubscription =
        _callHistoryService.getCallHistoryStream(limit: 100).listen((calls) {
      recentCalls.assignAll(calls);
      if (favoriteContacts.isEmpty) {
        _computeMostCalled();
      }
    });
  }

  Future<void> deleteCall(String callId) async {
    await _callHistoryService.deleteCallRecord(callId);
  }

  Future<void> clearAllHistory() async {
    await _callHistoryService.clearAllHistory();
    recentCalls.clear();
    mostCalledContacts.clear();
    mostCalledCounts.clear();
  }

  // Ensure current logged-in user document is present in Firestore
  Future<void> _ensureUserDocumentExists() async {
    try {
      final user = _authService.getCurrentUser();
      if (user != null) {
        final existingUser = await _userService.getUser(user.uid);
        if (existingUser == null) {
          final newUser = UserModel(
            uid: user.uid,
            name: user.displayName ?? 'User',
            phoneNumber: user.phoneNumber ?? '',
            profileImage: user.photoURL ?? '',
            isOnline: true,
            createdAt: DateTime.now(),
          );
          await _userService.createUser(newUser);
          debugPrint('HomeController: User document synced to Firestore for ${user.uid}');
        } else {
          await _userService.updateOnlineStatus(user.uid, true);
        }
      }
    } catch (e) {
      debugPrint('HomeController._ensureUserDocumentExists error: $e');
    }
  }

  // Bottom navigation tab state
  final RxInt selectedIndex = 0.obs;

  void changeTab(int index) {
    selectedIndex.value = index;
    if (index == 1 && Get.isRegistered<ContactsController>()) {
      Get.find<ContactsController>().loadUsers();
    } else if (index == 2 && Get.isRegistered<CallsController>()) {
      Get.find<CallsController>().loadHistory();
    }
  }

  // Dynamic greeting based on current local time
  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning 👋';
    } else if (hour < 17) {
      return 'Good Afternoon 👋';
    } else {
      return 'Good Evening 👋';
    }
  }

  // User display name with safe fallback
  String get userName {
    final user = _authService.getCurrentUser();
    final displayName = user?.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    final phone = user?.phoneNumber;
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    return 'User';
  }

  String get userInitial => userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

  // Quick call actions on Home dashboard
  void onAudioCallTap() {
    Get.snackbar(
      'Audio Call',
      'Select any contact from the Contacts tab to start a 1-to-1 audio call.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }

  void onVideoCallTap() {
    Get.snackbar(
      'Video Call',
      'Select any contact from the Contacts tab to start a 1-to-1 video call.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.primaryColor,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> redial(CallModel call) async {
    final myUid = currentUid ?? '';
    final otherUid = call.getOtherUserId(myUid);
    final otherName = call.getOtherUserName(myUid);
    final otherAvatar = call.getOtherUserPhoto(myUid) ?? '';

    if (otherUid.isEmpty) return;

    if (_blockService.isBlockedSync(otherUid)) {
      Get.snackbar('Blocked User', 'Cannot place a call to a blocked user.');
      return;
    }

    UserModel targetUser;
    final freshUser = await _userService.getUser(otherUid);
    if (freshUser != null) {
      targetUser = freshUser;
    } else {
      targetUser = UserModel(
        uid: otherUid,
        name: otherName,
        profileImage: otherAvatar,
        createdAt: DateTime.now(),
      );
    }

    if (call.isVideo) {
      await activeCallService.sendVideoCallInvitation(targetUser: targetUser);
    } else {
      await activeCallService.sendAudioCallInvitation(targetUser: targetUser);
    }
  }

  // --- Phase 5: Favorite & Most Called Call Actions ---

  Future<void> onFavoriteAudioCall(FavoriteContactModel fav) async {
    if (_blockService.isBlockedSync(fav.userId)) {
      Get.snackbar('Blocked User', 'Cannot place a call to a blocked user.');
      return;
    }
    final targetUser = UserModel(
      uid: fav.userId,
      name: fav.name,
      phoneNumber: fav.phoneNumber,
      profileImage: fav.avatarUrl,
      createdAt: DateTime.now(),
    );
    await activeCallService.sendAudioCallInvitation(targetUser: targetUser);
  }

  Future<void> onFavoriteVideoCall(FavoriteContactModel fav) async {
    if (_blockService.isBlockedSync(fav.userId)) {
      Get.snackbar('Blocked User', 'Cannot place a call to a blocked user.');
      return;
    }
    final targetUser = UserModel(
      uid: fav.userId,
      name: fav.name,
      phoneNumber: fav.phoneNumber,
      profileImage: fav.avatarUrl,
      createdAt: DateTime.now(),
    );
    await activeCallService.sendVideoCallInvitation(targetUser: targetUser);
  }

  Future<void> onMostCalledAudioCall(UserModel user) async {
    if (_blockService.isBlockedSync(user.uid)) {
      Get.snackbar('Blocked User', 'Cannot place a call to a blocked user.');
      return;
    }
    await activeCallService.sendAudioCallInvitation(targetUser: user);
  }

  Future<void> onMostCalledVideoCall(UserModel user) async {
    if (_blockService.isBlockedSync(user.uid)) {
      Get.snackbar('Blocked User', 'Cannot place a call to a blocked user.');
      return;
    }
    await activeCallService.sendVideoCallInvitation(targetUser: user);
  }

  Future<void> logout() async {
    try {
      // Deinitialize ZEGOCLOUD call listener first to prevent stale sessions
      if (!Get.testMode) {
        await activeCallService.uninit();
      }
      await _authService.logout();
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      Get.snackbar(
        'Logout Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }
}
