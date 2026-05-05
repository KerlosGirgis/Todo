import 'package:home_widget/home_widget.dart';
import 'package:todo/core/result.dart';
import 'package:todo/services/notes_repository.dart';
import '../models/note.dart';
import '../services/authentication_service.dart';
import 'package:flutter/material.dart';
import '../services/file_service.dart';
import '../services/lock_manager.dart';

class NotesViewModel with ChangeNotifier {
  List<Note> notes = [];
  late Note tempNote;
  final NotesRepository notesRepository = NotesRepository();
  final AuthenticationService authService = AuthenticationService();

  Future<void> get() async {
    notes = await notesRepository.getNotes();
    notifyListeners();
  }

  void updateAndroidWidget(String note) {
    HomeWidget.saveWidgetData("note", note);
    HomeWidget.updateWidget(
      androidName: "Note",
    );
  }

  Future<void> addNote(Note note) async {
    await notesRepository.insertNote(note);
    get();
  }

  Future<void> updateNote(Note note) async {
    await notesRepository.updateNote(note);
    get();
  }

  Future<void> deleteNote(int id) async {
    await notesRepository.deleteNote(id);
    get();
  }
  void newTempNote(){
    tempNote = Note(title: "", body: "", titleColor: "FFFFFF", coverColor: "1E1E1E", protected: 0);
    notifyListeners();
  }

  void clearTempNote(){
    tempNote = Note(title: "", body: "", titleColor: "FFFFFF", coverColor: "1E1E1E", protected: 0);
  }

  void setTempNoteTitle(String title){
    tempNote.title=title;
    notifyListeners();
  }
  void setTempNoteTitleColor(String titleColor){
    tempNote.titleColor=titleColor;
    notifyListeners();
  }
  void setTempNoteCoverColor(String coverColor){
    tempNote.coverColor=coverColor;
    notifyListeners();
  }

  Future<Result> toggleTempNoteProtection() async {

    if (tempNote.protected == 0) {
      bool isBioAvailable = await authService.authenticate();
      if (isBioAvailable) {
        tempNote.protected=1;
        notifyListeners();
        return Success("Fingerprint Enabled");
      } else{
        return Failure("Authentication Failed");
      }
    } else{
      tempNote.protected=0;
      notifyListeners();
      return Info("Fingerprint Disabled");
    }
  }

  Future<void> syncAfterReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final oldNote = notes.removeAt(oldIndex);
    notes.insert(newIndex, oldNote);
    await notesRepository.deleteAllNotes();
    for (var note in notes) {
      await notesRepository.insertNote(note);
    }
    get();
  }

  Future<Result> backup() async {
    if (await LockManager().isLockEnabled()) {
      final isAuth = await AuthenticationService().authenticate();
      if (!isAuth) {
        return Failure("Authentication Failed");
      }
    }
    try {
      final bytes = await notesRepository.exportNotesToJson();
      final outputPath = await FileService().saveFile(bytes, 'notes.json');
      if (outputPath == null || outputPath.isEmpty) {
        return Info("You didn't choose a directory");
      }
      return Success("Backup Created");
    } catch (e) {
      return Failure("Backup Failed");
    }
  }

  Future<Result> restore(bool overwrite) async {
    try {
      final fileService = FileService();
      final importedNotes = await fileService.pickAndReadNotes();
      if (importedNotes == null) {
        return Info("You didn't choose a file");
      }
      final oldNotes = await notesRepository.getNotes();
      try {
        if (overwrite) {
          await notesRepository.deleteAllNotes();
        }
        final existingNotes = overwrite ? [] : oldNotes;
        for (final note in importedNotes) {
          final exists = existingNotes.any((e) =>
              e.title == note.title &&
              e.body == note.body &&
              e.titleColor == note.titleColor &&
              e.coverColor == note.coverColor &&
              e.protected == note.protected);
          if (exists) continue;
          await notesRepository.insertNote(note);
        }
        get();
        return Success("Data Restored");
      } catch (e) {
        await _rollback(oldNotes);
        return Failure("Restore failed. Data rolled back.");
      }
    } catch (e) {
      return Failure("Failed To Restore");
    }
  }

  Future<void> _rollback(List<Note> oldNotes) async {
    await notesRepository.deleteAllNotes();

    for (final note in oldNotes) {
      await notesRepository.insertNote(note);
    }
  }

  Future<Result> authenticate(Note note) async {
    if (note.protected == 1) {
      bool isAuthenticated = await authService.authenticate();
      if (isAuthenticated) {
        return Success("Authenticated");
      } else {
        return Failure("Authentication Failed");
      }
    } else {
      return Success("Authenticated");
    }
  }

}
