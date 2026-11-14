import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:todo/services/key_service.dart';


class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  static Database? _db;

  /// The key the database is open with, which a change of App Lock locks
  /// with its password, or keeps as it is.
  static String? _key;
  String? get key => _key;

  final secureStorage = const FlutterSecureStorage();
  static const int _databaseVersion = 9;

  /// Opens the database with [key], which the App Lock's password unlocked,
  /// or else with the key kept as it is, or a new one for a new database.
  Future<Database> openDb({String? key}) async {
    var databasesPath = await getDatabasesPath();
    String path = '$databasesPath/Database.db';
    final keys = KeyService();
    final dbKey = key ?? await keys.unlockedKey() ?? await _newKey(path, keys);
    _db = await openDatabase(path,
        password: dbKey, version: _databaseVersion, onCreate: _onCreate,onUpgrade: _onUpgrade);
    _key = dbKey;
    return _db!;
  }

  /// A key for a new database. Not for one that's there already, without its
  /// key: another one would never open it.
  Future<String> _newKey(String path, KeyService keys) async {
    if (await databaseExists(path)) {
      throw StateError("The database's key is missing");
    }
    final key = KeyService.newKey();
    await keys.keepUnlocked(key);
    return key;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE ToDo(
      id INTEGER PRIMARY KEY,
      title TEXT,
      desc TEXT,
      status INTEGER,
      date TEXT,
      time TEXT,
      uuid TEXT,
      notification INTEGER,
      since TEXT,
      doneDays TEXT,
      parent TEXT,
      folded INTEGER
    )
    ''');
    await db.execute('''
    CREATE TABLE User(
      id INTEGER PRIMARY KEY,
      name TEXT,
      pic TEXT,
      theme INTEGER,
      amoled INTEGER DEFAULT 0,
      autoSave INTEGER,
      casual INTEGER,
      verse INTEGER,
      count INTEGER,
      finished INTEGER,
      unFinished INTEGER,
      notesTextSize REAL,
      startPage INTEGER,
      descLines INTEGER,
      notesTitleSize REAL,
      tasksTitleSize REAL,
      tasksDescSize REAL,
      tasksView INTEGER DEFAULT 0
    )
    ''');
    await db.execute('''
    CREATE TABLE Notes(
      id INTEGER PRIMARY KEY,
      title TEXT,
      body TEXT,
      delta TEXT,
      titleColor TEXT,
      coverColor TEXT,
      protected INTEGER
    )
    ''');
    await db.execute(_createTrash);
  }

  /// The trash, where deleted tasks and notes wait until they're put back or
  /// deleted for good. Each entry is one task or note, its kind "task" or
  /// "note", kept as backups keep it, in JSON; with the id it had, so it can
  /// go back where it was, and when it was deleted, as ISO 8601. Its ids are
  /// never used again, so an Undo for an entry deleted for good since can't
  /// put back another.
  static const _createTrash = '''
    CREATE TABLE IF NOT EXISTS Trash(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kind TEXT,
      itemId INTEGER,
      item TEXT,
      deletedAt TEXT
    )
    ''';
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE User ADD COLUMN notesTextSize REAL DEFAULT 1');
    }
    if(oldVersion < 3){
      await db.execute('ALTER TABLE User ADD COLUMN startPage INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE User ADD COLUMN descLines INTEGER DEFAULT 2');
    }
    if(oldVersion < 4){
      await db.execute('ALTER TABLE User ADD COLUMN notesTitleSize REAL DEFAULT 1');
      await db.execute('ALTER TABLE User ADD COLUMN tasksTitleSize REAL DEFAULT 1');
      await db.execute('ALTER TABLE User ADD COLUMN tasksDescSize REAL DEFAULT 1');
    }
    if(oldVersion < 5){
      await db.execute('ALTER TABLE Notes ADD COLUMN delta TEXT');
    }
    if (oldVersion < 6) {
      // They may be there already: an older build that opens the database
      // puts its version back, but leaves the columns.
      final columns = {
        for (final column in await db.rawQuery('PRAGMA table_info(ToDo)'))
          column['name'],
      };
      if (!columns.contains('since')) {
        await db.execute('ALTER TABLE ToDo ADD COLUMN since TEXT');
      }
      if (!columns.contains('doneDays')) {
        await db.execute('ALTER TABLE ToDo ADD COLUMN doneDays TEXT');
      }
      // The daily tasks there are count their days from today, as nothing
      // says how earlier ones went.
      await db.execute("UPDATE ToDo SET since = date('now', 'localtime') "
          "WHERE notification = 2 AND (since IS NULL OR since = '')");
    }
    if (oldVersion < 7) {
      final columns = {
        for (final column in await db.rawQuery('PRAGMA table_info(User)'))
          column['name'],
      };
      if (!columns.contains('amoled')) {
        await db.execute(
            'ALTER TABLE User ADD COLUMN amoled INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 8) {
      // It may be there already, from before an older build put the
      // version back.
      await db.execute(_createTrash);
    }
    if (oldVersion < 9) {
      // A task's parent is the uuid of the task it's a subtask of, which a
      // reorder doesn't change, as it does the ids. The tasks there are
      // have none: they're all tasks of their own.
      final tasks = await _columns(db, 'ToDo');
      if (!tasks.contains('parent')) {
        await db.execute('ALTER TABLE ToDo ADD COLUMN parent TEXT');
      }
      if (!tasks.contains('folded')) {
        await db.execute('ALTER TABLE ToDo ADD COLUMN folded INTEGER');
      }
      if (!(await _columns(db, 'User')).contains('tasksView')) {
        await db
            .execute('ALTER TABLE User ADD COLUMN tasksView INTEGER DEFAULT 0');
      }
    }
  }

  /// The names of [table]'s columns. Ones a newer version added may be
  /// there already: an older build that opens the database puts its version
  /// back, but leaves the columns.
  static Future<Set<Object?>> _columns(Database db, String table) async => {
        for (final column in await db.rawQuery('PRAGMA table_info($table)'))
          column['name'],
      };

  static Database get db => _db!;
}
