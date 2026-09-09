import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/blocked_user_model.dart';
import 'auth_service.dart';

/// Centralized service for managing and enforcing user blocking in ConnectCall.
///
/// Block relationships are stored in Cloud Firestore under:
/// `users/{currentUserUid}/blockedUsers/{blockedUserUid}`.
class BlockService {
  final FirebaseFirestore? _injectedFirestore;
  final AuthService _authService;
  static BlockService? _instance;

  // In-memory reactive set of currently blocked user IDs for fast zero-latency checks
  final RxSet<String> blockedUserIds = <String>{}.obs;
  Stream<Set<String>> get blockedUsersStream => blockedUserIds.stream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  // Optional mock delegates for unit/widget testing
  Future<bool> Function(String blockedUid, String? currentUid)? blockUserDelegate;
  Future<bool> Function(String blockedUid, String? currentUid)? unblockUserDelegate;
  Future<bool> Function(String targetUid, String? currentUid)? isBlockedDelegate;
  Future<List<String>> Function(String? currentUid)? getBlockedListDelegate;

  BlockService({
    FirebaseFirestore? firestore,
    AuthService? authService,
    this.blockUserDelegate,
    this.unblockUserDelegate,
    this.isBlockedDelegate,
    this.getBlockedListDelegate,
  })  : _injectedFirestore = firestore,
        _authService = authService ?? AuthService();

  static BlockService get instance => _instance ??= BlockService();

  static void setInstance(BlockService? service) {
    _instance = service;
  }

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  String? get _currentUid => _authService.currentUserId;

  CollectionReference<Map<String, dynamic>> _blockedCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('blockedUsers');
  }

  /// Initializes real-time listener for current user's blocked users
  void initBlockedUsersListener({String? userId}) {
    final uid = userId ?? _currentUid;
    if (uid == null || uid.isEmpty) {
      blockedUserIds.clear();
      return;
    }

    if (Get.testMode && _injectedFirestore == null) {
      return;
    }

    _subscription?.cancel();
    try {
      _subscription = _blockedCollection(uid).snapshots().listen((snap) {
        final ids = snap.docs.map((d) => d.id).toSet();
        blockedUserIds.assignAll(ids);
      }, onError: (e) {
        debugPrint('BlockService listener error: $e');
      });
    } catch (e) {
      debugPrint('BlockService.initBlockedUsersListener error: $e');
    }
  }

  /// Blocks a registered user.
  Future<bool> blockUser({
    required String blockedUserUid,
    String? currentUserId,
  }) async {
    final uid = currentUserId ?? _currentUid;
    if (uid == null || uid.isEmpty || blockedUserUid.isEmpty) return false;

    if (blockUserDelegate != null) {
      final success = await blockUserDelegate!(blockedUserUid, uid);
      if (success) blockedUserIds.add(blockedUserUid);
      return success;
    }

    try {
      final model = BlockedUserModel(
        blockedUserUid: blockedUserUid,
        createdAt: DateTime.now(),
      );
      await _blockedCollection(uid).doc(blockedUserUid).set(model.toMap());
      blockedUserIds.add(blockedUserUid);
      return true;
    } catch (e) {
      debugPrint('BlockService.blockUser error: $e');
      return false;
    }
  }

  /// Unblocks a previously blocked user.
  Future<bool> unblockUser({
    required String blockedUserUid,
    String? currentUserId,
  }) async {
    final uid = currentUserId ?? _currentUid;
    if (uid == null || uid.isEmpty || blockedUserUid.isEmpty) return false;

    if (unblockUserDelegate != null) {
      final success = await unblockUserDelegate!(blockedUserUid, uid);
      if (success) blockedUserIds.remove(blockedUserUid);
      return success;
    }

    try {
      await _blockedCollection(uid).doc(blockedUserUid).delete();
      blockedUserIds.remove(blockedUserUid);
      return true;
    } catch (e) {
      debugPrint('BlockService.unblockUser error: $e');
      return false;
    }
  }

  /// Checks whether [targetUid] is blocked by the current user.
  Future<bool> isUserBlocked({
    required String targetUid,
    String? currentUserId,
  }) async {
    if (targetUid.isEmpty) return false;

    if (isBlockedDelegate != null) {
      return await isBlockedDelegate!(targetUid, currentUserId ?? _currentUid);
    }

    // Fast check in-memory cache
    if (blockedUserIds.contains(targetUid)) return true;

    final uid = currentUserId ?? _currentUid;
    if (uid == null || uid.isEmpty) return false;

    try {
      final doc = await _blockedCollection(uid).doc(targetUid).get();
      final blocked = doc.exists;
      if (blocked) blockedUserIds.add(targetUid);
      return blocked;
    } catch (e) {
      debugPrint('BlockService.isUserBlocked error: $e');
      return blockedUserIds.contains(targetUid);
    }
  }

  /// Synchronous fast check against the in-memory blocked user set.
  bool isBlockedSync(String targetUid) {
    return blockedUserIds.contains(targetUid);
  }

  /// Fetches all blocked user IDs for the current user.
  Future<List<String>> getBlockedUserIds({String? currentUserId}) async {
    if (getBlockedListDelegate != null) {
      final list = await getBlockedListDelegate!(currentUserId ?? _currentUid);
      blockedUserIds.assignAll(list);
      return list;
    }

    final uid = currentUserId ?? _currentUid;
    if (uid == null || uid.isEmpty) return [];

    try {
      final snap = await _blockedCollection(uid).get();
      final ids = snap.docs.map((d) => d.id).toList();
      blockedUserIds.assignAll(ids);
      return ids;
    } catch (e) {
      debugPrint('BlockService.getBlockedUserIds error: $e');
      return blockedUserIds.toList();
    }
  }

  /// Disposes active stream subscription
  void dispose() {
    _subscription?.cancel();
  }
}
