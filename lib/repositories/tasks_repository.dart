import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/task_tree.dart';
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
      'parent',
      'folded',
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

  /// Saves each of [items] over the row with its id, all of them or, if that
  /// fails, none.
  Future<void> updateItems(Iterable<TodoItem> items) async {
    await db.transaction((txn) async {
      for (final item in items) {
        await txn.update('ToDo', item.toMap(),
            where: 'id = ?', whereArgs: [item.id]);
      }
    });
  }

  /// Lists the tasks as [items] has them, in its order. Every one of them
  /// gets a new id.
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

  /// Moves [branch], a task with the tasks in it, to the trash, as they
  /// were at [deletedAt], and gives the entry they're there as.
  Future<Trashed<TaskBranch>> moveToTrash(TaskBranch branch,
      {required DateTime deletedAt}) async {
    final id = await _trash.moveIn(db, 'ToDo',
        itemId: branch.task.id,
        alongWith: [for (final subtask in branch.subtasks) subtask.id],
        item: branch.toMap(),
        deletedAt: deletedAt);
    return Trashed(id: id, item: branch, deletedAt: deletedAt);
  }

  /// The tasks in the trash, each with the tasks in it, the last deleted
  /// first.
  Future<List<Trashed<TaskBranch>>> getTrash() =>
      _trash.read(db, TaskBranch.fromMap);

  /// Takes the trash's entry [id] out of it, and puts [branch] back on the
  /// list: its task and the tasks in it, where they were if no task has any
  /// of their ids now. Its task's id there, or null when the entry isn't in
  /// the trash anymore.
  Future<int?> restoreFromTrash(int id, TaskBranch branch) =>
      _trash.moveOut(db, 'ToDo', id,
          itemId: branch.task.id,
          item: branch.task.toMap(),
          alongWith: [
            for (final subtask in branch.subtasks)
              {...subtask.toMap(), 'id': subtask.id},
          ]);

  /// Deletes the trash's entries [ids] for good.
  Future<void> deleteFromTrash(Iterable<int> ids) => _trash.delete(db, ids);
}