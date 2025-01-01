import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/user_profile.dart';
import 'package:crypto/crypto.dart';
import 'package:todo/provider/tasks_provider.dart';

import '../models/note.dart';
import 'notification.dart';

class DatabaseService {
  late Database db;
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  final secureStorage = const FlutterSecureStorage();

  String generateStrongKey({int length = 32}) {
    final Random random = Random.secure();
    final List<int> values =
        List<int>.generate(length, (i) => random.nextInt(256));

    // Optional: Hash the random bytes to further strengthen the key
    final Digest key = sha256.convert(values);

    return base64Url.encode(key.bytes);
  }

  Future<void> storeEncryptionKey() async {
    String? key = await secureStorage.read(key: 'dbKey');
    if (key == null) {
      key = generateStrongKey(); // Your function to generate a secure key
      await secureStorage.write(key: 'dbKey', value: key);
    }
  }

  Future<String?> getEncryptionKey() async {
    return await secureStorage.read(key: 'dbKey');
  }

  Future<Database> openDb() async {
    var databasesPath = await getDatabasesPath();
    String path = '${databasesPath}Database.db';
    String? dbKey = await getEncryptionKey();
    db = await openDatabase(path,
        password: dbKey, version: 1, onCreate: _onCreate);
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
      unFinished INTEGER
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
    List<Map<String, dynamic>> maps = await db.query('ToDo', columns: [
      'id',
      'title',
      'desc',
      'status',
      'date',
      'time',
      'uuid',
      'notification'
    ]);
    List<TodoItem> items = [];
    if (maps.isNotEmpty) {
      for (var element in maps) {
        items.add(TodoItem.fromMap(element));
      }
    }
    return items;
  }

  Future<List<Note>> getNotes() async {
    List<Map<String, dynamic>> maps = await db.query('Notes', columns: [
      'id',
      'title',
      'body',
      'titleColor',
      'coverColor',
      'protected'
    ]);
    List<Note> items = [];
    if (maps.isNotEmpty) {
      for (var element in maps) {
        items.add(Note.fromMap(element));
      }
    }
    return items;
  }

  Future<List<UserProfile>> getUser() async {
    List<Map<String, dynamic>> maps = await db.query('User', columns: [
      'id',
      'name',
      'pic',
      'theme',
      'autoSave',
      'casual',
      'verse',
      'count',
      'finished',
      'unFinished'
    ]);
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

  // Export Notes to JSON
  Future<bool> exportNotesToJson() async {
    List<Note> notes = await getNotes();
    String jsonString = jsonEncode(notes.map((note) => note.toMap()).toList());
    Uint8List bytes = utf8.encode(jsonString);

    String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select location to save Notes JSON file',
        fileName: 'notes.json',
        bytes: bytes);

    if (outputPath != null) {
      if (outputPath.isEmpty) {
        return false;
      } else {
        return true;
      }
    } else {
      return false;
    }
  }

  Future<bool> exportToDoToJson() async {
    List<TodoItem> items = await getItems();
    String jsonString = jsonEncode(items.map((item) => item.toMap()).toList());
    Uint8List bytes = utf8.encode(jsonString);

    String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select location to save ToDo JSON file',
        fileName: 'todo.json',
        bytes: bytes);

    if (outputPath != null) {
      if (outputPath.isEmpty) {
        return false;
      } else {
        return true;
      }
    } else {
      return false;
    }
  }

  // Import Notes from JSON
  Future<bool> importNotesFromJson() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String jsonString = await file.readAsString();
      List<dynamic> data = jsonDecode(jsonString);

      for (var noteMap in data) {
        Note note = Note.fromMap(noteMap);
        await insertNote(note);
      }
      return true;
    } else {
      return false;
    }
  }

  Future<bool> importToDoFromJson() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String jsonString = await file.readAsString();
      List<dynamic> data = jsonDecode(jsonString);

      for (var itemMap in data) {
        TodoItem item = TodoItem.fromMap(itemMap);
        await insertItem(item);
        if(item.notification==1){
          if (item.time.isNotEmpty) {
            DateTime scheduledTime =
            TasksProvider().stringToDateTime(item.date, item.time);
            if (scheduledTime.isAfter(DateTime.now()) && item.status == 0) {
              NotificationService.scheduleNotification(
                item.uuid.hashCode,
                "Don't Forget Your Task!",
                item.title,
                scheduledTime,
              );
            }
          }
        }
      }
      return true;
    } else {
      return false;
    }
  }
}
