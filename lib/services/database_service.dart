import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:todo/services/key_service.dart';


class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  static Database? _db;

  final secureStorage = const FlutterSecureStorage();
  static const int _databaseVersion = 4;

  Future<Database> openDb() async {
    var databasesPath = await getDatabasesPath();
    String path = '$databasesPath/Database.db';
    String? dbKey = await KeyService().getOrCreateEncryptionKey();
    _db = await openDatabase(path,
        password: dbKey, version: _databaseVersion, onCreate: _onCreate,onUpgrade: _onUpgrade);
    return _db!;
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
      notification INTEGER
    )
    ''');
    await db.execute('''
    CREATE TABLE User(
      id INTEGER PRIMARY KEY,
      name TEXT,
      pic TEXT,
      theme INTEGER,
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
      tasksDescSize REAL
    )
    ''');
    await db.execute('''
    CREATE TABLE Notes(
      id INTEGER PRIMARY KEY,
      title TEXT,
      body TEXT,
      titleColor TEXT,
      coverColor TEXT,
      protected INTEGER
    )
    ''');
  }
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
  }

  static Database get db => _db!;
}
