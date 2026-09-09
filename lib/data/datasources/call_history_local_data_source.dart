import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../models/call_model.dart';

/// CallHistoryLocalDataSource handles raw SQLite queries and mutations on the
/// `call_history` table.
class CallHistoryLocalDataSource {
  final AppDatabase _appDatabase;

  CallHistoryLocalDataSource({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase.instance;

  Future<Database> get _db => _appDatabase.database;

  /// Insert or replace a call record in SQLite
  Future<bool> insertCall(CallModel call) async {
    try {
      final db = await _db;
      final rowsAffected = await db.insert(
        AppDatabase.callHistoryTable,
        call.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('CallHistoryLocalDataSource: Inserted call ${call.id} (rowId: $rowsAffected)');
      return rowsAffected > 0;
    } catch (e) {
      debugPrint('CallHistoryLocalDataSource.insertCall error: $e');
      return false;
    }
  }

  /// Update call status, end time, and duration
  Future<bool> updateCallStatus({
    required String callId,
    required String status,
    DateTime? endedAt,
    int? durationSeconds,
    String? userId,
  }) async {
    try {
      final db = await _db;
      final values = <String, dynamic>{
        'status': status,
      };

      if (endedAt != null) {
        values['endedAt'] = endedAt.millisecondsSinceEpoch;
      }
      if (durationSeconds != null) {
        values['durationSeconds'] = durationSeconds;
      }

      String whereClause = 'id = ?';
      List<dynamic> whereArgs = [callId];

      if (userId != null && userId.isNotEmpty) {
        whereClause += ' AND firebaseUid = ?';
        whereArgs.add(userId);
      }

      final count = await db.update(
        AppDatabase.callHistoryTable,
        values,
        where: whereClause,
        whereArgs: whereArgs,
      );

      debugPrint('CallHistoryLocalDataSource: Updated call $callId with status $status (rows: $count)');
      return count > 0;
    } catch (e) {
      debugPrint('CallHistoryLocalDataSource.updateCallStatus error: $e');
      return false;
    }
  }

  /// Retrieve call history records scoped to a user, ordered newest first
  Future<List<CallModel>> getCalls({
    required String firebaseUid,
    int limit = 50,
  }) async {
    try {
      final db = await _db;
      final results = await db.query(
        AppDatabase.callHistoryTable,
        where: 'firebaseUid = ?',
        whereArgs: [firebaseUid],
        orderBy: 'createdAt DESC',
        limit: limit,
      );

      return results.map((map) => CallModel.fromSqliteMap(map)).toList();
    } catch (e) {
      debugPrint('CallHistoryLocalDataSource.getCalls error: $e');
      return [];
    }
  }

  /// Retrieve a specific call by ID
  Future<CallModel?> getCallById(String callId) async {
    try {
      final db = await _db;
      final results = await db.query(
        AppDatabase.callHistoryTable,
        where: 'id = ?',
        whereArgs: [callId],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return CallModel.fromSqliteMap(results.first);
    } catch (e) {
      debugPrint('CallHistoryLocalDataSource.getCallById error: $e');
      return null;
    }
  }

  /// Delete a single call record
  Future<bool> deleteCall({
    required String callId,
    String? firebaseUid,
  }) async {
    try {
      final db = await _db;
      String whereClause = 'id = ?';
      List<dynamic> whereArgs = [callId];

      if (firebaseUid != null && firebaseUid.isNotEmpty) {
        whereClause += ' AND firebaseUid = ?';
        whereArgs.add(firebaseUid);
      }

      final count = await db.delete(
        AppDatabase.callHistoryTable,
        where: whereClause,
        whereArgs: whereArgs,
      );

      debugPrint('CallHistoryLocalDataSource: Deleted call $callId (rows: $count)');
      return count > 0;
    } catch (e) {
      debugPrint('CallHistoryLocalDataSource.deleteCall error: $e');
      return false;
    }
  }

  /// Clear all call history records for a specific user
  Future<bool> clearAllCalls({required String firebaseUid}) async {
    try {
      final db = await _db;
      final count = await db.delete(
        AppDatabase.callHistoryTable,
        where: 'firebaseUid = ?',
        whereArgs: [firebaseUid],
      );

      debugPrint('CallHistoryLocalDataSource: Cleared $count calls for user $firebaseUid');
      return true;
    } catch (e) {
      debugPrint('CallHistoryLocalDataSource.clearAllCalls error: $e');
      return false;
    }
  }
}
