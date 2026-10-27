import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/note.dart';
import '../services/database_service.dart';

class NotesRepository {
  Database get db => DatabaseService.db;

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
}
