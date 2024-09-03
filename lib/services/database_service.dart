import 'package:sqflite/sqflite.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/user_profile.dart';

import '../models/note.dart';

class DatabaseService {
  late Database db;
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> openDb() async {
    var databasesPath = await getDatabasesPath();
    String path = '${databasesPath}Database.db';
    db = await openDatabase(path, version: 1, onCreate: _onCreate);
    return db;
  }

  _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE ToDo(
      id INTEGER PRIMARY KEY,
      title TEXT,
      desc TEXT,
      status INTEGER,
      date TEXT,
      time TEXT
    )
    ''');
    await db.execute('''
    CREATE TABLE User(
      id INTEGER PRIMARY KEY,
      firstName TEXT,
      lastName TEXT,
      pic TEXT,
      theme INTEGER
    )
    ''');
    await db.execute('''
    CREATE TABLE Notes(
      id INTEGER PRIMARY KEY,
      title TEXT,
      body TEXT,
      titleColor,
      coverColor
    )
    ''');
  }

  Future<void> insertItem(TodoItem item) {
    return db.insert('ToDo', item.toMap());
  }
  Future<void> insertNote(Note note) {
    return db.insert('Notes', note.toMap());
  }

  Future<void> insertUser(UserProfile user) {
    return db.insert('User', user.toMap());
  }

  Future<List<TodoItem>> getItems() async {
    List<Map<String, dynamic>> maps = await db.query('ToDo',
        columns: ['id', 'title', 'desc', 'status', 'date', 'time']);
    List<TodoItem> items = [];
    if (maps.isNotEmpty) {
      for (var element in maps) {
        items.add(TodoItem.fromMap(element));
      }
    }
    return items;
  }
  Future<List<Note>> getNotes() async {
    List<Map<String, dynamic>> maps = await db.query('Notes',
        columns: ['id', 'title', 'body','titleColor','coverColor']);
    List<Note> items = [];
    if (maps.isNotEmpty) {
      for (var element in maps) {
        items.add(Note.fromMap(element));
      }
    }
    return items;
  }

  Future<List<UserProfile>> getUser() async {
    List<Map<String, dynamic>> maps = await db.query('User',
        columns: ['id', 'firstName', 'lastName', 'pic', 'theme']);
    List<UserProfile> items = [];
    if (maps.isNotEmpty) {
      for (var element in maps) {
        items.add(UserProfile.fromMap(element));
      }
    }
    return items;
  }

  Future<void> deleteItem(int id) async {
    await db.delete('ToDo', where: 'id = ?', whereArgs: [id]);
  }
  Future<void> deleteNote(int id) async {
    await db.delete('Notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllItems() async {
    await db.delete('ToDo');
  }
  Future<void> deleteAllNotes() async {
    await db.delete('Notes');
  }

  Future<void> updateItem(TodoItem item) async {
    await db
        .update('ToDo', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }
  Future<void> updateNote(Note item) async {
    await db
        .update('Notes', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> updateUser(UserProfile item) async {
    await db
        .update('User', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }
}
