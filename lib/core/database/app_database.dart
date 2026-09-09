import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// AppDatabase manages the local SQLite database lifecycle for ConnectCall.
class AppDatabase {
  static const String databaseName = 'connect_call.db';
  static const int databaseVersion = 2;
  static const String callHistoryTable = 'call_history';
  static const String favoriteContactsTable = 'favorite_contacts';

  static AppDatabase? _instance;
  Database? _database;

  // Optional custom database instance or factory (e.g. for testing)
  final Database? _injectedDatabase;
  final DatabaseFactory? _injectedFactory;

  AppDatabase({Database? database, DatabaseFactory? databaseFactory})
      : _injectedDatabase = database,
        _injectedFactory = databaseFactory;

  /// Global singleton instance
  static AppDatabase get instance => _instance ??= AppDatabase();

  /// Reset or set global instance (primarily for tests)
  static void setInstance(AppDatabase? instance) {
    _instance = instance;
  }

  /// Returns the open database instance, initializing it if necessary.
  Future<Database> get database async {
    if (_injectedDatabase != null) {
      return _injectedDatabase;
    }
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final factory = _injectedFactory ?? databaseFactory;
    final databasesPath = await factory.getDatabasesPath();
    final dbPath = p.join(databasesPath, databaseName);

    debugPrint('AppDatabase: Opening SQLite database at $dbPath');

    return await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  /// Helper to create call_history table and its index
  static Future<void> createCallHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $callHistoryTable (
        id TEXT PRIMARY KEY,
        firebaseUid TEXT NOT NULL,
        remoteUserId TEXT,
        contactName TEXT,
        phoneNumber TEXT,
        zegoUserId TEXT,
        callerId TEXT NOT NULL,
        callerName TEXT NOT NULL,
        callerPhoto TEXT,
        calleeId TEXT NOT NULL,
        calleeName TEXT NOT NULL,
        calleePhoto TEXT,
        callType TEXT NOT NULL,
        direction TEXT NOT NULL,
        status TEXT NOT NULL,
        startedAt INTEGER NOT NULL,
        endedAt INTEGER,
        durationSeconds INTEGER DEFAULT 0,
        createdAt INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_call_history_user_created 
      ON $callHistoryTable (firebaseUid, createdAt DESC);
    ''');
  }

  /// Helper to create favorite_contacts table and its index
  static Future<void> createFavoriteContactsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $favoriteContactsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebaseUid TEXT NOT NULL,
        remoteUserId TEXT NOT NULL,
        contactName TEXT,
        phoneNumber TEXT,
        createdAt INTEGER NOT NULL,
        UNIQUE(firebaseUid, remoteUserId)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_favorite_contacts_user 
      ON $favoriteContactsTable (firebaseUid, createdAt DESC);
    ''');
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('AppDatabase: Creating database tables (version: $version)');
    await createCallHistoryTable(db);
    await createFavoriteContactsTable(db);
  }

  /// Handle database schema migrations
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('AppDatabase: Upgrading database from $oldVersion to $newVersion');
    if (oldVersion < 2) {
      await createFavoriteContactsTable(db);
    }
  }

  /// Close the database
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
