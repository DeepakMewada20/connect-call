import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../models/favorite_contact_model.dart';

class FavoriteContactsLocalDataSource {
  final AppDatabase _appDatabase;

  FavoriteContactsLocalDataSource({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase.instance;

  Future<Database> get _db => _appDatabase.database;

  /// Inserts or replaces a favorite contact for the user.
  Future<int> insertFavorite(FavoriteContactModel favorite) async {
    try {
      final db = await _db;
      final rowId = await db.insert(
        AppDatabase.favoriteContactsTable,
        favorite.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('FavoriteContactsLocalDataSource: Inserted favorite for ${favorite.remoteUserId} (row: $rowId)');
      return rowId;
    } catch (e) {
      debugPrint('FavoriteContactsLocalDataSource.insertFavorite error: $e');
      rethrow;
    }
  }

  /// Removes a favorite contact by remoteUserId for the scoped user.
  Future<int> deleteFavorite({
    required String firebaseUid,
    required String remoteUserId,
  }) async {
    try {
      final db = await _db;
      final rows = await db.delete(
        AppDatabase.favoriteContactsTable,
        where: 'firebaseUid = ? AND remoteUserId = ?',
        whereArgs: [firebaseUid, remoteUserId],
      );
      debugPrint('FavoriteContactsLocalDataSource: Deleted favorite $remoteUserId (rows: $rows)');
      return rows;
    } catch (e) {
      debugPrint('FavoriteContactsLocalDataSource.deleteFavorite error: $e');
      rethrow;
    }
  }

  /// Checks whether a remote user is favorited.
  Future<bool> isFavorite({
    required String firebaseUid,
    required String remoteUserId,
  }) async {
    try {
      final db = await _db;
      final maps = await db.query(
        AppDatabase.favoriteContactsTable,
        where: 'firebaseUid = ? AND remoteUserId = ?',
        whereArgs: [firebaseUid, remoteUserId],
        limit: 1,
      );
      return maps.isNotEmpty;
    } catch (e) {
      debugPrint('FavoriteContactsLocalDataSource.isFavorite error: $e');
      return false;
    }
  }

  /// Returns all favorite contacts for a given user ordered by most recently added.
  Future<List<FavoriteContactModel>> getFavorites({
    required String firebaseUid,
  }) async {
    try {
      final db = await _db;
      final maps = await db.query(
        AppDatabase.favoriteContactsTable,
        where: 'firebaseUid = ?',
        whereArgs: [firebaseUid,],
        orderBy: 'createdAt DESC',
      );
      return maps.map((m) => FavoriteContactModel.fromSqliteMap(m)).toList();
    } catch (e) {
      debugPrint('FavoriteContactsLocalDataSource.getFavorites error: $e');
      return [];
    }
  }

  /// Clears all favorites for the scoped user.
  Future<int> clearFavorites({required String firebaseUid}) async {
    try {
      final db = await _db;
      final rows = await db.delete(
        AppDatabase.favoriteContactsTable,
        where: 'firebaseUid = ?',
        whereArgs: [firebaseUid],
      );
      debugPrint('FavoriteContactsLocalDataSource: Cleared $rows favorites for $firebaseUid');
      return rows;
    } catch (e) {
      debugPrint('FavoriteContactsLocalDataSource.clearFavorites error: $e');
      rethrow;
    }
  }
}
