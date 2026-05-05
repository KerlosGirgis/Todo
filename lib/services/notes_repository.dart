import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/note.dart';
import 'database_service.dart';

class NotesRepository {
  final Database db = DatabaseService.db;

  Future<void> insertNote(Note note) {
    return db.insert('Notes', note.toMap());
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

  Future<void> deleteNote(int id) async {
    await db.delete('Notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllNotes() async {
    await db.delete('Notes');
  }

  Future<void> updateNote(Note item) async {
    await db
        .update('Notes', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<Uint8List> exportNotesToJson() async {
    final notes = await getNotes();
    final jsonString =
    jsonEncode(notes.map((note) => note.toMap()).toList());

    return utf8.encode(jsonString);
  }
}
