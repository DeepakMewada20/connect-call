import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/call_model.dart';
import 'auth_service.dart';

/// CallHistoryService manages call history persistence and retrieval via Cloud Firestore.
///
/// Each user's call history is strictly scoped under:
/// `users/{userId}/call_history/{callId}`
///
/// Features:
/// - Deterministic call IDs ensure zero duplicates across callbacks.
/// - Fully asynchronous, non-blocking operations so Firestore operations never interrupt active calls.
/// - Dependency injection friendly for unit testing.
class CallHistoryService {
  final FirebaseFirestore? _injectedFirestore;
  final AuthService? _injectedAuthService;
  FirebaseFirestore? _firestoreInstance;
  AuthService? _authServiceInstance;

  CallHistoryService({
    FirebaseFirestore? firestore,
    AuthService? authService,
  })  : _injectedFirestore = firestore,
        _injectedAuthService = authService;

  static final CallHistoryService instance = CallHistoryService();

  FirebaseFirestore get _firestore {
    _firestoreInstance ??= _injectedFirestore ?? FirebaseFirestore.instance;
    return _firestoreInstance!;
  }

  AuthService get _authService {
    _authServiceInstance ??= _injectedAuthService ?? AuthService();
    return _authServiceInstance!;
  }

  String? get _currentUserId => _authService.currentUserId;

  // Collection reference for a given user's call history
  CollectionReference<Map<String, dynamic>> _userHistoryCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('call_history');
  }

  /// Create or update a call history record using deterministic [call.id]
  Future<bool> saveCallRecord(CallModel call, {String? userId}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      debugPrint('CallHistoryService.saveCallRecord: No authenticated user ID');
      return false;
    }

    try {
      await _userHistoryCollection(uid).doc(call.id).set(
            call.toMap(),
            SetOptions(merge: true),
          );
      debugPrint('Call history record saved [ID: ${call.id}] for user $uid');
      return true;
    } catch (e) {
      debugPrint('CallHistoryService.saveCallRecord error: $e');
      return false;
    }
  }

  /// Update call status and connected duration upon call answer or completion
  Future<bool> updateCallStatus({
    required String callId,
    required String status,
    DateTime? endedAt,
    int? durationSeconds,
    String? userId,
  }) async {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      debugPrint('CallHistoryService.updateCallStatus: No authenticated user ID');
      return false;
    }

    try {
      final updateData = <String, dynamic>{
        'status': status,
      };

      if (endedAt != null) {
        updateData['endedAt'] = Timestamp.fromDate(endedAt);
      }
      if (durationSeconds != null) {
        updateData['durationSeconds'] = durationSeconds;
      }

      await _userHistoryCollection(uid).doc(callId).set(
            updateData,
            SetOptions(merge: true),
          );
      debugPrint('Call history updated [ID: $callId, Status: $status, Duration: ${durationSeconds ?? 0}s] for $uid');
      return true;
    } catch (e) {
      debugPrint('CallHistoryService.updateCallStatus error: $e');
      return false;
    }
  }

  /// Retrieve call history records ordered by startedAt descending
  Future<List<CallModel>> getCallHistory({String? userId, int limit = 50}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      return [];
    }

    try {
      final snapshot = await _userHistoryCollection(uid)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CallModel.fromMap(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('CallHistoryService.getCallHistory error: $e');
      return [];
    }
  }

  /// Real-time stream of call history records for reactive UI updates
  Stream<List<CallModel>> getCallHistoryStream({String? userId, int limit = 50}) {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      return const Stream.empty();
    }

    try {
      return _userHistoryCollection(uid)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => CallModel.fromMap(doc.data(), documentId: doc.id))
            .toList();
      });
    } catch (e) {
      debugPrint('CallHistoryService.getCallHistoryStream error: $e');
      return const Stream.empty();
    }
  }

  /// Retrieve recent calls for Home dashboard (default latest 5)
  Stream<List<CallModel>> getRecentCalls({String? userId, int limit = 5}) {
    return getCallHistoryStream(userId: userId, limit: limit);
  }

  /// Delete a single call record
  Future<bool> deleteCallRecord(String callId, {String? userId}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      return false;
    }

    try {
      await _userHistoryCollection(uid).doc(callId).delete();
      debugPrint('Call history record deleted [ID: $callId] for user $uid');
      return true;
    } catch (e) {
      debugPrint('CallHistoryService.deleteCallRecord error: $e');
      return false;
    }
  }
}
