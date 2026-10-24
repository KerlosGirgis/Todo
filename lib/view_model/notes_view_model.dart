import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:todo/core/result.dart';
import 'package:todo/repositories/notes_repository.dart';
import '../core/prompts.dart';
import '../core/utils/note_document_utils.dart';
import '../models/app_lock.dart';
import '../models/note.dart';
import '../services/authentication_service.dart';
import '../services/backup_service.dart';
import '../services/file_service.dart';
import '../services/home_widget_service.dart';
import '../services/lock_service.dart';

class NotesViewModel with ChangeNotifier {
  List<Note> _notes = [];
  List<Note> get notes => UnmodifiableListView(_notes);

  int get lockedCount => _notes.where((note) => note.protected == 1).length;

  final NotesRepository _notesRepository = NotesRepository();
  final AuthenticationService _authService = AuthenticationService();
  final LockService _lockService = LockService();
  final HomeWidgetService _homeWidgetService = HomeWidgetService();
  final BackupService _backupService = BackupService();
  final FileService _fileService = FileService();

  /// Whether the note on the widget has been checked since the app started:
  /// see [_checkWidget].
  bool _widgetChecked = false;

  Future<void> get() async {
    _notes = await _notesRepository.getNotes();
    notifyListeners();
    if (!_widgetChecked) {
      _widgetChecked = true;
      await _checkWidget();
    }
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

  /// Shows [note]'s text on the home screen's widget, where anyone can read
  /// it, so never a locked note's.
  Future<Result> showOnWidget(Note note) async {
    if (note.protected == 1) {
      return Info("Locked notes can't go on the widget");
    }
    if (note.body.trim().isEmpty) {
      return Info("Write something to show on the widget first");
    }
    try {
      await _homeWidgetService.showNote(note.id!, note.body);
    } catch (e) {
      return Failure("Sorry, Something went wrong");
    }
    return Info("Note has been added to the widget");
  }

  /// Takes the note with [id] off the widget, if it's the one there: a
  /// locked note's text has no place on the home screen, nor a deleted one's.
  Future<void> _takeOffWidget(int? id) async {
    try {
      if (id != null && (await _homeWidgetService.shownNote()).id == id) {
        await _homeWidgetService.clearNote();
      }
    } catch (e) {
      // The widget's own trouble, which the note's change goes ahead without.
    }
  }

  /// The note on the widget, as it is now, if it's one of the notes.
  Future<Note?> _noteOnWidget() async {
    try {
      final id = (await _homeWidgetService.shownNote()).id;
      return _notes.where((note) => id != null && note.id == id).firstOrNull;
    } catch (e) {
      return null;
    }
  }

  /// Has the widget keep track of [shown], the note it showed before the
  /// notes were all written again, by its new id, found by what it says.
  Future<void> _followOnWidget(Note shown) async {
    final note = _notes.where((note) => _sameNote(note, shown)).firstOrNull;
    if (note == null) return _clearWidget();
    try {
      await _homeWidgetService.followNote(note.id!);
    } catch (e) {
      // The widget's own trouble.
    }
  }

  /// Takes whatever note is there off the widget.
  Future<void> _clearWidget() async {
    try {
      await _homeWidgetService.clearNote();
    } catch (e) {
      // The widget's own trouble.
    }
  }

  /// Whether [a] and [b] say the same, in the same colours and lock.
  static bool _sameNote(Note a, Note b) =>
      a.title == b.title &&
      a.body == b.body &&
      a.delta == b.delta &&
      a.titleColor == b.titleColor &&
      a.coverColor == b.coverColor &&
      a.protected == b.protected;

  /// Makes sure the widget shows no locked note's text, nor a deleted one's,
  /// as the notes are first read in: in case a change to its note didn't get
  /// to the widget, or its note was put there before the widget kept track
  /// of which, and has to be found by its text instead.
  Future<void> _checkWidget() async {
    try {
      final shown = await _homeWidgetService.shownNote();
      if (shown.text == null) return;
      if (shown.id case final id?) {
        final note = _notes.where((note) => note.id == id).firstOrNull;
        if (note == null || note.protected == 1) {
          await _homeWidgetService.clearNote();
        }
        return;
      }
      final notes = _notes.where((note) => note.body == shown.text);
      if (notes.any((note) => note.protected == 1)) {
        await _homeWidgetService.clearNote();
      } else if (notes.firstOrNull case final note?) {
        await _homeWidgetService.followNote(note.id!);
      }
    } catch (e) {
      // The widget's own trouble.
    }
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

  /// Changes [note]'s title, colours and lock, keeping its text. Locking it
  /// takes it off the widget.
  Future<void> updateNote(
    Note note, {
    required String title,
    required String titleColor,
    required String coverColor,
    required bool locked,
  }) async {
    await _update(Note(
      id: note.id,
      title: title,
      body: note.body,
      delta: note.delta,
      titleColor: titleColor,
      coverColor: coverColor,
      protected: locked ? 1 : 0,
    ));
    if (locked) await _takeOffWidget(note.id);
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
        await _takeOffWidget(note.id);
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
    final onWidget = await _noteOnWidget();
    try {
      // A copy, as the next reorder can move notes in the list while this
      // one is still being written.
      await _notesRepository.refreshAllNotes(List.of(_notes));
    } catch (e) {
      // The order stays as it was in the database.
    }
    // Rewriting the table gives every note a new id, so the notes are read
    // back in: the ids held before would now point at other notes. The
    // widget's too.
    await get();
    if (onWidget != null) await _followOnWidget(onWidget);
  }

  /// Saves the notes to a file locked with a password that
  /// [askForBackupPassword] gets from the user, once the App Lock lets them
  /// through, with [password] for an app locked with one, and while any note
  /// is locked, once its lock does too. Null if the user cancels.
  Future<Result?> backup({
    String? password,
    required NewBackupPasswordPrompt askForBackupPassword,
  }) async {
    if (!await _authService.passesAppLock(password: password)) {
      return Failure("Authentication Failed");
    }
    try {
      final notes = await _notesRepository.getNotes();
      // Locked notes go into the file with all they say, so it takes their
      // lock, as opening one does: the App Lock may be off, or a password,
      // which a locked note won't take while the fingerprint works. An app
      // locked with the fingerprint has just asked for it, and the password
      // just given is the one a locked note falls back on without it.
      if (notes.any((note) => note.protected == 1) &&
          await _lockService.getLock() != AppLock.fingerprint) {
        final unlocked = await _passNoteLock(() async => password);
        if (unlocked is! Success) return unlocked;
      }
      final file = await _backupService.write(
        [for (final note in notes) note.toMap()],
        kind: BackupKind.notes,
        askForPassword: askForBackupPassword,
      );
      if (file == null) return null;
      final outputPath = await _fileService.saveFile(file, 'notes.json');
      if (outputPath == null || outputPath.isEmpty) {
        return Info("You didn't choose a directory");
      }
      return Success("Backup Created");
    } catch (e) {
      return Failure("Backup Failed");
    }
  }

  /// Adds the notes from a backup file the user picks, once
  /// [askForBackupPassword] gets the password it's locked with, in place of
  /// every note there is when [overwrite] is set. Replacing locked notes
  /// takes their lock first, as deleting one does, with [askForPassword] for
  /// the App Lock's password on a phone that can't take a fingerprint. Null
  /// if the user cancels.
  Future<Result?> restore(
    bool overwrite, {
    required PasswordPrompt askForPassword,
    required BackupPasswordPrompt askForBackupPassword,
  }) async {
    try {
      final currentNotes = await _notesRepository.getNotes();
      if (overwrite && currentNotes.any((note) => note.protected == 1)) {
        final unlocked = await _passNoteLock(askForPassword);
        if (unlocked is! Success) return unlocked;
      }
      final bytes = await _fileService.pickJsonFile();
      if (bytes == null) {
        return Info("You didn't choose a file");
      }
      final records = await _backupService.read(bytes,
          kind: BackupKind.notes, askForPassword: askForBackupPassword);
      if (records == null) return null;
      final importedNotes = records.map<Note>((e) => Note.fromMap(e)).toList();
      final existingNotes = overwrite ? <Note>[] : currentNotes;
      final newNotes = <Note>[];
      for (final note in importedNotes) {
        final exists = existingNotes.any((e) => _sameNote(e, note));
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
      // Replacing the notes deleted the one on the widget, whichever it was.
      if (overwrite) await _clearWidget();
      get();
      return Success("Data Restored");
    } on WrongBackupKindException {
      return Failure("That's a backup of tasks, not notes");
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
