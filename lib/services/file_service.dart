
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/note.dart';
import '../models/todo_item.dart';

class FileService {
  Future<String?> saveFile(Uint8List bytes, String fileName) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Select backup location',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
    );
    return uri?.toString();
  }

  Future<List<TodoItem>?> pickAndReadTodos() async {
    final data = await _pickAndDecodeJson();
    if (data == null) return null;

    return data.map<TodoItem>((e) => TodoItem.fromMap(e)).toList();
  }

  Future<List<Note>?> pickAndReadNotes() async {
    final data = await _pickAndDecodeJson();
    if (data == null) return null;

    return data.map<Note>((e) => Note.fromMap(e)).toList();
  }

  Future<dynamic> _pickAndDecodeJson() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (file == null) return null;

    // readAsBytes works for content:// URIs too, where file.path is null.
    final bytes = await file.readAsBytes();
    return jsonDecode(utf8.decode(bytes));
  }
}
