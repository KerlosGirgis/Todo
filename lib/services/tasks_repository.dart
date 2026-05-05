import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/todo_item.dart';
import 'database_service.dart';

class TasksRepository{

  final Database db = DatabaseService.db;

  Future<void> insertItem(TodoItem item) {
    return db.insert('ToDo', item.toMap());
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

  Future<void> deleteItem(int id) async {
    await db.delete('ToDo', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllItems() async {
    await db.delete('ToDo');
  }

  Future<void> updateItem(TodoItem item) async {
    await db
        .update('ToDo', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<Uint8List> exportToDoToJson() async {
    List<TodoItem> items = await getItems();
    String jsonString =
    jsonEncode(items.map((item) => item.toMap()).toList());
    return utf8.encode(jsonString);
  }

}