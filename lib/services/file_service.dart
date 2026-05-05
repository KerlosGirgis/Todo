
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/note.dart';
import '../models/todo_item.dart';

class FileService {
  Future<String?> saveFile(Uint8List bytes, String fileName) async {
    return await FilePicker.saveFile(
      dialogTitle: 'Select backup location',
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<List<TodoItem>?> pickAndReadTodos() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null) return null;

    final file = File(result.files.single.path!);
    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString);

    return data.map<TodoItem>((e) => TodoItem.fromMap(e)).toList();
  }

  Future<List<Note>?> pickAndReadNotes() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null) return null;

    final file = File(result.files.single.path!);
    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString);

    return data.map<Note>((e) => Note.fromMap(e)).toList();
  }
}