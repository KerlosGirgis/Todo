import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/todo_item.dart';
import '../services/database_service.dart';

class TasksRepository{

  Database get db => DatabaseService.db;

  Future<int> insertItem(TodoItem item) {
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

  Future<void> updateItem(TodoItem item) async {
    await db
        .update('ToDo', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> refreshAllItems(List<TodoItem> items) async {
    await db.transaction((txn) async {
      await txn.delete('ToDo');
      for (var item in items) {
        await txn.insert('ToDo', item.toMap());
      }
    });
  }

  /// Adds [items], in place of every task there is when [overwrite] is set.
  Future<void> importItems(List<TodoItem> items,
      {required bool overwrite}) async {
    await db.transaction((txn) async {
      if (overwrite) {
        await txn.delete('ToDo');
      }
      for (var item in items) {
        await txn.insert('ToDo', item.toMap());
      }
    });
  }

}