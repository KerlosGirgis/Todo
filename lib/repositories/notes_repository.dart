import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/note.dart';
import '../models/trashed.dart';
import '../services/database_service.dart';
import 'trash_table.dart';

class NotesRepository {
  Database get db => DatabaseService.db;

  static const _trash = TrashTable(TrashKind.note);

  Future<void> insertNote(Note note) {
    return db.insert('Notes', note.toMap());
  }

  Future<List<Note>> getNotes() async {
    List<Map<String, dynamic>> maps = await db.query('Notes', columns: [
      'id',
      'title',
      'body',
      'delta',
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

  Future<void> deleteNote(int id) async {
    await db.delete('Notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateNote(Note item) async {
    await db
        .update('Notes', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> refreshAllNotes(List<Note> notes) async {
    await db.transaction((txn) async {
      await txn.delete('Notes');
      for (var note in notes) {
        await txn.insert('Notes', note.toMap());
      }
    });
  }

  /// Adds [notes], in place of every note there is when [overwrite] is set.
  Future<void> importNotes(List<Note> notes, {required bool overwrite}) async {
    await db.transaction((txn) async {
      if (overwrite) {
        await txn.delete('Notes');
      }
      for (var note in notes) {
        await txn.insert('Notes', note.toMap());
      }
    });
  }

  /// Moves [note] to the trash, with all it says, as it was at [deletedAt],
  /// and gives the entry it's there as.
  Future<Trashed<Note>> moveToTrash(Note note,
      {required DateTime deletedAt}) async {
    final id = await _trash.moveIn(db, 'Notes',
        itemId: note.id, item: note.toMap(), deletedAt: deletedAt);
    return Trashed(id: id, item: note, deletedAt: deletedAt);
  }

  /// The notes in the trash, with all they say, the last deleted first.
  Future<List<Trashed<Note>>> getTrash() => _trash.read(db, Note.fromMap);

  /// Takes the trash's entry [id] out of it, and puts [note] back with the
  /// notes, where it was if no note has its id now. Its id there, or null
  /// when the entry isn't in the trash anymore.
  Future<int?> restoreFromTrash(int id, Note note) =>
      _trash.moveOut(db, 'Notes', id, itemId: note.id, item: note.toMap());

  /// Deletes the trash's entries [ids] for good.
  Future<void> deleteFromTrash(Iterable<int> ids) => _trash.delete(db, ids);
}
