import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/trashed.dart';

/// The table deleted tasks and notes wait in, until they're put back or
/// deleted for good, which the tasks' and the notes' repositories share.
class TrashTable {
  const TrashTable(this.kind);

  static const name = 'Trash';

  /// Which of the trash's entries are this repository's.
  final TrashKind kind;

  /// Moves the row with [itemId] from [table] to the trash, where it's kept
  /// as [item], and gives the trash's id for it. The rows with the ids
  /// [alongWith] go with it, as a task's subtasks do: [item] holds them too.
  /// Throws when there's no row [itemId], as it's been deleted already.
  Future<int> moveIn(Database db, String table,
      {required int? itemId,
      Iterable<int?> alongWith = const [],
      required Map<String, Object?> item,
      required DateTime deletedAt}) {
    return db.transaction((txn) async {
      final deleted =
          await txn.delete(table, where: 'id = ?', whereArgs: [itemId]);
      if (deleted == 0) throw StateError("There's no row $itemId to delete");
      for (final id in alongWith) {
        await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      }
      return txn.insert(
        name,
        Trashed.toRow(
            kind: kind, itemId: itemId, item: item, deletedAt: deletedAt),
      );
    });
  }

  /// The entries, the last deleted first, read by [fromMap]. One that can't
  /// be read is left out.
  Future<List<Trashed<T>>> read<T>(
      Database db, T Function(Map<String, dynamic> map) fromMap) async {
    final rows = await db.query(name,
        where: 'kind = ?', whereArgs: [kind.name], orderBy: 'id DESC');
    return [
      for (final row in rows)
        if (Trashed.fromRow(row, fromMap) case final entry?) entry,
    ];
  }

  /// Takes the entry [id] out of the trash and puts [item] back in [table],
  /// with the id it had, [itemId], when no row has it now. Rows are listed
  /// in the order of their ids, so it goes back where it was; otherwise it
  /// goes at the end. The rows [alongWith] go back after it, as a task's
  /// subtasks do, each with the `id` it has when they're all free, or else
  /// at the end with [item], in their order. The id [item] has there, or
  /// null when the entry isn't in the trash anymore: put back or deleted for
  /// good already.
  Future<int?> moveOut(Database db, String table, int id,
      {required int? itemId,
      required Map<String, Object?> item,
      List<Map<String, Object?>> alongWith = const []}) {
    return db.transaction((txn) async {
      final taken = await txn.delete(name,
          where: 'id = ? AND kind = ?', whereArgs: [id, kind.name]);
      if (taken == 0) return null;
      final rows = [
        {...item, 'id': itemId},
        ...alongWith,
      ];
      var free = true;
      for (final row in rows) {
        final rowId = row['id'];
        free = rowId != null &&
            (await txn.query(table,
                    columns: ['id'], where: 'id = ?', whereArgs: [rowId]))
                .isEmpty;
        if (!free) break;
      }
      int? first;
      for (final row in rows) {
        final rowId =
            await txn.insert(table, free ? row : ({...row}..remove('id')));
        first ??= rowId;
      }
      return first;
    });
  }

  /// Deletes the entries [ids] for good, all of them or, if that fails,
  /// none.
  Future<void> delete(Database db, Iterable<int> ids) {
    return db.transaction((txn) async {
      for (final id in ids) {
        await txn.delete(name,
            where: 'id = ? AND kind = ?', whereArgs: [id, kind.name]);
      }
    });
  }
}
