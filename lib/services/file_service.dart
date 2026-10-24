
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

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

  /// What's in a JSON file the user picks, or null if they don't pick one.
  Future<Uint8List?> pickJsonFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (file == null) return null;

    // readAsBytes works for content:// URIs too, where file.path is null.
    return file.readAsBytes();
  }
}
