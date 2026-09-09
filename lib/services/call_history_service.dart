import 'package:flutter/foundation.dart';
import '../data/repositories/call_history_repository.dart';
import '../models/call_model.dart';
import 'auth_service.dart';

/// CallHistoryService manages call history persistence and retrieval via local SQLite.
///
/// Features:
/// - Stores call records locally on the user's device using SQLite.
/// - Scoped to the current authenticated Firebase user UID to support multi-user devices.
/// - Fully asynchronous, non-blocking operations so local storage never interrupts active calls.
/// - Real-time reactive stream to update UI automatically upon call inserts or updates.
/// - Dependency injection friendly for unit testing.
class CallHistoryService {
  final CallHistoryRepository _repository;
  final AuthService _authService;

  CallHistoryService({
    CallHistoryRepository? repository,
    AuthService? authService,
    dynamic firestore, // Kept for constructor backward compatibility; ignored
  })  : _authService = authService ?? AuthService(),
        _repository = repository ??
            CallHistoryRepositoryImpl(
              authService: authService,
            );

  static CallHistoryService? _instance;
  static CallHistoryService get instance => _instance ??= CallHistoryService();

  static void setInstance(CallHistoryService? instance) {
    _instance = instance;
  }

  String? get _currentUserId => _authService.currentUserId;

  /// Create or update a call history record in local SQLite
  Future<bool> saveCallRecord(CallModel call, {String? userId}) async {
    final uid = userId ?? _currentUserId ?? call.firebaseUid;
    if (uid == null || uid.isEmpty) {
      debugPrint('CallHistoryService.saveCallRecord: No authenticated user ID');
      return false;
    }

    final recordToSave = call.firebaseUid != null && call.firebaseUid!.isNotEmpty
        ? call
        : call.copyWith(firebaseUid: uid);

    return await _repository.saveCallRecord(recordToSave, userId: uid);
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
    return await _repository.updateCallStatus(
      callId: callId,
      status: status,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      userId: uid,
    );
  }

  /// Retrieve call history records ordered by createdAt descending
  Future<List<CallModel>> getCallHistory({String? userId, int limit = 50}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      return [];
    }

    return await _repository.getCallHistory(userId: uid, limit: limit);
  }

  /// Real-time stream of call history records for reactive UI updates
  Stream<List<CallModel>> getCallHistoryStream({String? userId, int limit = 50}) {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      return const Stream.empty();
    }

    return _repository.getCallHistoryStream(userId: uid, limit: limit);
  }

  /// Retrieve recent calls for Home dashboard (default latest 5)
  Stream<List<CallModel>> getRecentCalls({String? userId, int limit = 5}) {
    return getCallHistoryStream(userId: userId, limit: limit);
  }

  /// Delete a single call record from local SQLite
  Future<bool> deleteCallRecord(String callId, {String? userId}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      return false;
    }

    return await _repository.deleteCallRecord(callId, userId: uid);
  }

  /// Clear all call history records for the current user from local SQLite
  Future<bool> clearAllHistory({String? userId}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      return false;
    }

    return await _repository.clearAllHistory(userId: uid);
  }
}
