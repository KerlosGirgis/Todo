import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/todo_item.dart';
import '../models/trashed.dart';
import '../services/database_service.dart';
import 'trash_table.dart';

class TasksRepository{

  Database get db => DatabaseService.db;

  static const _trash = TrashTable(TrashKind.task);

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
      'notification',
      'since',
      'doneDays',
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

  /// Moves [item] to the trash, as it was at [deletedAt], and gives the
  /// entry it's there as.
  Future<Trashed<TodoItem>> moveToTrash(TodoItem item,
      {required DateTime deletedAt}) async {
    final id = await _trash.moveIn(db, 'ToDo',
        itemId: item.id, item: item.toMap(), deletedAt: deletedAt);
    return Trashed(id: id, item: item, deletedAt: deletedAt);
  }

  /// The tasks in the trash, the last deleted first.
  Future<List<Trashed<TodoItem>>> getTrash() => _trash.read(db, TodoItem.fromMap);

  /// Takes the trash's entry [id] out of it, and puts [item] back on the
  /// list, where it was if no task has its id now. Its id there, or null
  /// when the entry isn't in the trash anymore.
  Future<int?> restoreFromTrash(int id, TodoItem item) =>
      _trash.moveOut(db, 'ToDo', id, itemId: item.id, item: item.toMap());

  /// Deletes the trash's entries [ids] for good.
  Future<void> deleteFromTrash(Iterable<int> ids) => _trash.delete(db, ids);
}