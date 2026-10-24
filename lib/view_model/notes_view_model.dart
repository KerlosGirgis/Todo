import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:todo/core/result.dart';
import 'package:todo/repositories/notes_repository.dart';
import '../core/utils/note_document_utils.dart';
import '../models/app_lock.dart';
import '../models/note.dart';
import '../services/authentication_service.dart';
import '../services/file_service.dart';
import '../services/home_widget_service.dart';
import '../services/lock_service.dart';

/// Asks the user for the App Lock's password, and gives it once they've
/// entered it right, or null if they cancel.
typedef PasswordPrompt = Future<String?> Function();

class NotesViewModel with ChangeNotifier {
  List<Note> _notes = [];
  List<Note> get notes => UnmodifiableListView(_notes);

  int get lockedCount => _notes.where((note) => note.protected == 1).length;

  final NotesRepository _notesRepository = NotesRepository();
  final AuthenticationService _authService = AuthenticationService();
  final LockService _lockService = LockService();
  final HomeWidgetService _homeWidgetService = HomeWidgetService();

  Future<void> get() async {
    _notes = await _notesRepository.getNotes();
    notifyListeners();
  }

  /// The notes that [query] finds: those with it in their title or text. A
  /// locked note's text isn't searched, so a search can't give away what's in
  /// it.
  List<Note> search(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return notes;
    return [
      for (final note in _notes)
        if (note.title.toLowerCase().contains(term) ||
            (note.protected != 1 && note.body.toLowerCase().contains(term)))
          note,
    ];
  }

  /// Shows [note]'s text on the home screen's widget.
  Future<Result> showOnWidget(Note note) async {
    if (note.body.trim().isEmpty) {
      return Info("Write something to show on the widget first");
    }
    try {
      await _homeWidgetService.showNote(note.body);
    } catch (e) {
      return Failure("Sorry, Something went wrong");
    }
    return Info("Note has been added to the widget");
  }

  /// Adds a note with nothing written in it yet.
  Future<void> addNote({
    required String title,
    required String titleColor,
    required String coverColor,
    required bool locked,
  }) async {
    await _notesRepository.insertNote(Note(
      title: title,
      body: "",
      titleColor: titleColor,
      coverColor: coverColor,
      protected: locked ? 1 : 0,
    ));
    get();
  }

  /// Changes [note]'s title, colours and lock, keeping its text.
  Future<void> updateNote(
    Note note, {
    required String title,
    required String titleColor,
    required String coverColor,
    required bool locked,
  }) {
    return _update(Note(
      id: note.id,
      title: title,
      body: note.body,
      delta: note.delta,
      titleColor: titleColor,
      coverColor: coverColor,
      protected: locked ? 1 : 0,
    ));
  }

  /// Saves [document] as [note]'s text, keeping its title, colours and lock,
  /// and returns the note as it's saved.
  Future<Note> updateText(Note note, Document document) async {
    final saved = Note(
      id: note.id,
      title: note.title,
      body: NoteDocumentUtils.toBody(document),
      delta: jsonEncode(document.toDelta().toJson()),
      titleColor: note.titleColor,
      coverColor: note.coverColor,
      protected: note.protected,
    );
    await _update(saved);
    return saved;
  }

  Future<void> _update(Note note) async {
    await _notesRepository.updateNote(note);
    get();
  }

  Future<Result> deleteNote(Note note,
      {required PasswordPrompt askForPassword}) async {
    final isAuthenticated =
        await authenticate(note, askForPassword: askForPassword);
    if(isAuthenticated is Success){
      try{
        await _notesRepository.deleteNote(note.id!);
        get();
        return Info("Note Deleted");
      }
      catch(e){
        return Failure("Couldn't delete the note");
      }

    }
    else{
      return isAuthenticated;
    }
  }

  /// Checks it's the user before a note is locked, as the lock will:
  /// see [_passNoteLock].
  Future<Result> confirmLock({required PasswordPrompt askForPassword}) =>
      _passNoteLock(askForPassword);

  Future<void> syncAfterReorder(int oldIndex, int newIndex) async {
    final oldNote = _notes.removeAt(oldIndex);
    _notes.insert(newIndex, oldNote);
    try {
      // A copy, as the next reorder can move notes in the list while this
      // one is still being written.
      await _notesRepository.refreshAllNotes(List.of(_notes));
    } catch (e) {
      // The order stays as it was in the database.
    }
    // Rewriting the table gives every note a new id, so the notes are read
    // back in: the ids held before would now point at other notes.
    get();
  }

  /// Saves the notes to a file, once the App Lock lets the user through:
  /// with [password], for an app locked with one.
  Future<Result> backup({String? password}) async {
    if (!await _authService.passesAppLock(password: password)) {
      return Failure("Authentication Failed");
    }
    try {
      final bytes = await _notesRepository.exportNotesToJson();
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
      final existingNotes =
          overwrite ? <Note>[] : await _notesRepository.getNotes();
      final newNotes = <Note>[];
      for (final note in importedNotes) {
        final exists = existingNotes.any((e) =>
            e.title == note.title &&
            e.body == note.body &&
            e.delta == note.delta &&
            e.titleColor == note.titleColor &&
            e.coverColor == note.coverColor &&
            e.protected == note.protected);
        if (exists) continue;
        newNotes.add(note);
      }
      try {
        // All or nothing, so a restore that fails part-way through leaves
        // the notes as they were.
        await _notesRepository.importNotes(newNotes, overwrite: overwrite);
      } catch (e) {
        return Failure("Restore failed. Data rolled back.");
      }
      get();
      return Success("Data Restored");
    } catch (e) {
      return Failure("Failed To Restore");
    }
  }

  /// Checks it's the user, for a locked [note]: see [_passNoteLock].
  Future<Result> authenticate(Note note,
      {required PasswordPrompt askForPassword}) async {
    if (note.protected == 1) {
      return _passNoteLock(askForPassword);
    } else {
      return Success("Authenticated");
    }
  }

  /// Checks it's the user, as a locked note does: with their fingerprint, or,
  /// on a phone that can't take one, with the App Lock's password, which
  /// [askForPassword] asks them for.
  Future<Result> _passNoteLock(PasswordPrompt askForPassword) async {
    switch (await _authService.checkFingerprint()) {
      case FingerprintCheck.passed:
        return Success("Authenticated");
      case FingerprintCheck.failed:
        return Failure("Authentication Failed");
      // Not the password, which anyone who knows it could otherwise get to by
      // failing the fingerprint on purpose.
      case FingerprintCheck.lockedOut:
        return Failure("Too many tries. Try your fingerprint again later.");
      case FingerprintCheck.unavailable:
        if (await _lockService.getLock() != AppLock.password) {
          return Failure(
              "Fingerprint isn't available. Set an App Lock password instead.");
        }
        final password = await askForPassword();
        if (password != null &&
            await _authService.passesAppLock(password: password)) {
          return Success("Authenticated");
        }
        return Failure("Authentication Failed");
    }
  }

}
