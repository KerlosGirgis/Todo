import 'package:sqflite/sqflite.dart';
import 'package:todo/models/todo_item.dart';

class DatabaseService {
  late Database db;
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> openDb() async
  {
    var databasesPath = await getDatabasesPath();
    String path = '${databasesPath}Database.db';
    db = await openDatabase(path, version: 1, onCreate: _onCreate);
    return db;
  }
  _onCreate(Database db, int version) async
  {
    await db.execute('''
    CREATE TABLE ToDo(
      id INTEGER PRIMARY KEY,
      title TEXT,
      desc TEXT,
      status INTEGER
    )
    ''');
  }

  Future<void> insertItem(TodoItem item)
  {
    return db.insert('ToDo', item.toMap());
  }

  Future<List<TodoItem>> getItems() async {

    List<Map<String,dynamic>> maps = await db.query('ToDo', columns: ['id', 'title', 'desc','status']);
    List<TodoItem> items = [];
    if (maps.isNotEmpty) {
      for (var element in maps) {
        items.add(TodoItem.fromMap(element));
      }
    }
    return items;
  }

  Future<void> deleteItem(int id) async
  {
    await db.delete('ToDo', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateItem(TodoItem item) async
  {
    await db.update('ToDo', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }


}