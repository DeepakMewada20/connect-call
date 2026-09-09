import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/call_model.dart';
import '../../services/auth_service.dart';
import '../datasources/call_history_local_data_source.dart';

/// Repository interface for call history data access.
abstract class CallHistoryRepository {
  Future<bool> saveCallRecord(CallModel call, {String? userId});
  Future<bool> updateCallStatus({
    required String callId,
    required String status,
    DateTime? endedAt,
    int? durationSeconds,
    String? userId,
  });
  Future<List<CallModel>> getCallHistory({String? userId, int limit = 50});
  Stream<List<CallModel>> getCallHistoryStream({String? userId, int limit = 50});
  Future<bool> deleteCallRecord(String callId, {String? userId});
  Future<bool> clearAllHistory({String? userId});
}

/// SQLite-backed implementation of CallHistoryRepository.
class CallHistoryRepositoryImpl implements CallHistoryRepository {
  final CallHistoryLocalDataSource _localDataSource;
  final AuthService _authService;

  // Broadcast stream controller to notify UI of call history changes
  final StreamController<void> _changeNotifier = StreamController<void>.broadcast();

  CallHistoryRepositoryImpl({
    CallHistoryLocalDataSource? localDataSource,
    AuthService? authService,
  })  : _localDataSource = localDataSource ?? CallHistoryLocalDataSource(),
        _authService = authService ?? AuthService();

  String? _resolveUserId(String? userId) {
    return userId ?? _authService.currentUserId;
  }

  void _notifyChange() {
    if (!_changeNotifier.isClosed) {
      _changeNotifier.add(null);
    }
  }

  @override
  Future<bool> saveCallRecord(CallModel call, {String? userId}) async {
    final uid = _resolveUserId(userId ?? call.firebaseUid);
    if (uid == null || uid.isEmpty) {
      debugPrint('CallHistoryRepository: Cannot save call, no active user ID');
      return false;
    }

    // Ensure record is scoped to the user
    final recordToSave = call.firebaseUid == uid
        ? call
        : call.copyWith(firebaseUid: uid);

    final success = await _localDataSource.insertCall(recordToSave);
    if (success) {
      _notifyChange();
    }
    return success;
  }

  @override
  Future<bool> updateCallStatus({
    required String callId,
    required String status,
    DateTime? endedAt,
    int? durationSeconds,
    String? userId,
  }) async {
    final uid = _resolveUserId(userId);
    final success = await _localDataSource.updateCallStatus(
      callId: callId,
      status: status,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      userId: uid,
    );
    if (success) {
      _notifyChange();
    }
    return success;
  }

  @override
  Future<List<CallModel>> getCallHistory({String? userId, int limit = 50}) async {
    final uid = _resolveUserId(userId);
    if (uid == null || uid.isEmpty) {
      return [];
    }

    return await _localDataSource.getCalls(firebaseUid: uid, limit: limit);
  }

  @override
  Stream<List<CallModel>> getCallHistoryStream({
    String? userId,
    int limit = 50,
  }) async* {
    final uid = _resolveUserId(userId);
    if (uid == null || uid.isEmpty) {
      yield [];
      return;
    }

    // Initial emission
    yield await _localDataSource.getCalls(firebaseUid: uid, limit: limit);

    // Yield on subsequent mutations
    await for (final _ in _changeNotifier.stream) {
      final currentUid = _resolveUserId(userId);
      if (currentUid != null && currentUid.isNotEmpty) {
        yield await _localDataSource.getCalls(firebaseUid: currentUid, limit: limit);
      } else {
        yield [];
      }
    }
  }

  @override
  Future<bool> deleteCallRecord(String callId, {String? userId}) async {
    final uid = _resolveUserId(userId);
    final success = await _localDataSource.deleteCall(
      callId: callId,
      firebaseUid: uid,
    );
    if (success) {
      _notifyChange();
    }
    return success;
  }

  @override
  Future<bool> clearAllHistory({String? userId}) async {
    final uid = _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return false;

    final success = await _localDataSource.clearAllCalls(firebaseUid: uid);
    if (success) {
      _notifyChange();
    }
    return success;
  }

  void dispose() {
    _changeNotifier.close();
  }
}
