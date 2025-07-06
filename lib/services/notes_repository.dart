import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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

  Future<bool> importNotesFromJson(bool overwrite) async {
    List<Note> notes = await getNotes();
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String jsonString = await file.readAsString();
      List<dynamic> data = jsonDecode(jsonString);
      try {
        if (overwrite) {
          await deleteAllNotes();
          for (var noteMap in data) {
            Note note = Note.fromMap(noteMap);
            await insertNote(note);
          }
        } else {
          for (var noteMap in data) {
            Note note = Note.fromMap(noteMap);
            if (notes.any((element) =>
                element.title == note.title &&
                element.body == note.body &&
                element.titleColor == note.titleColor &&
                element.coverColor == note.coverColor &&
                element.protected == note.protected)) {
              continue;
            }
            await insertNote(note);
          }
        }
      } catch (e) {
        deleteAllNotes();
        for (var note in notes) {
          await insertNote(note);
        }
        return false;
      }
      return true;
    } else {
      return false;
    }
  }
}
