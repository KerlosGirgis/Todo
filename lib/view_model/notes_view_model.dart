import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:todo/core/result.dart';
import 'package:todo/repositories/notes_repository.dart';
import '../core/prompts.dart';
import '../core/utils/note_document_utils.dart';
import '../models/app_lock.dart';
import '../models/note.dart';
import '../models/note_preview.dart';
import '../services/authentication_service.dart';
import '../services/backup_service.dart';
import '../services/file_service.dart';
import '../services/home_widget_service.dart';
import '../services/lock_service.dart';

class NotesViewModel with ChangeNotifier {
  NotesViewModel({
    NotesRepository? repository,
    AuthenticationService? authService,
    LockService? lockService,
    HomeWidgetService? homeWidgetService,
    BackupService? backupService,
    FileService? fileService,
  })  : _notesRepository = repository ?? NotesRepository(),
        _authService = authService ?? AuthenticationService(),
        _lockService = lockService ?? LockService(),
        _homeWidgetService = homeWidgetService ?? HomeWidgetService(),
        _backupService = backupService ?? BackupService(),
        _fileService = fileService ?? FileService();

  /// The notes, with all they say.
  List<Note> _notes = [];

  /// The notes as the pages get them: without a locked note's text, which
  /// only its editor gets, once its lock lets the user through.
  List<Note> _shown = [];
  List<Note> get notes => UnmodifiableListView(_shown);

  int get lockedCount => _notes.where((note) => note.locked).length;

  final NotesRepository _notesRepository;
  final AuthenticationService _authService;
  final LockService _lockService;
  final HomeWidgetService _homeWidgetService;
  final BackupService _backupService;
  final FileService _fileService;

  /// Whether the note on the widget has been checked since the app started:
  /// see [_checkWidget].
  bool _widgetChecked = false;

  Future<void> get() async {
    _notes = await _notesRepository.getNotes();
    _publish();
    if (!_widgetChecked) {
      _widgetChecked = true;
      await _checkWidget();
    }
  }

  /// Shows the pages the notes as they are now.
  void _publish() {
    _shown = [
      for (final note in _notes) note.locked ? note.withoutText() : note,
    ];
    notifyListeners();
  }

  /// Puts [saved] in place of the note it's a newer copy of, without reading
  /// all the notes in again.
  void _replace(Note saved) {
    final index = _notes.indexWhere((note) => note.id == saved.id);
    if (index == -1) return;
    _notes[index] = saved;
    _publish();
  }

  /// [note], one of [notes], with all it says, or null when it's gone.
  Note? _full(Note note) =>
      _notes.where((each) => each.id == note.id).firstOrNull;

  /// The notes that [query] finds: those with it in their title or text. A
  /// locked note's text isn't searched, so a search can't give away what's in
  /// it.
  List<Note> search(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return notes;
    return [
      for (final note in _shown)
        if (note.title.toLowerCase().contains(term) ||
            (!note.locked && note.body.toLowerCase().contains(term)))
          note,
    ];
  }

  /// The start of [note]'s text as its card shows it, or null for a locked
  /// note, as nothing of what it says is shown.
  NotePreview? previewOf(Note note) =>
      note.locked ? null : NoteDocumentUtils.preview(note);

  /// A form for a new note.
  NoteDraft newDraft() => NoteDraft._(this, null);

  /// A form that changes [note]'s title, colours and lock, once its lock lets
  /// the user through: see [_passNoteLock].
  Future<Access<NoteDraft>> edit(Note note,
      {required PasswordPrompt askForPassword}) async {
    final unlocked = await _unlock(note, askForPassword);
    return switch (unlocked) {
      Granted(:final value) => Granted(NoteDraft._(this, value)),
      Denied(:final message) => Denied(message),
    };
  }

  /// [note], open to be read and written, once its lock lets the user
  /// through: see [_passNoteLock].
  Future<Access<NoteEditorViewModel>> open(Note note,
      {required PasswordPrompt askForPassword}) async {
    final unlocked = await _unlock(note, askForPassword);
    return switch (unlocked) {
      Granted(:final value) => Granted(NoteEditorViewModel._(this, value)),
      Denied(:final message) => Denied(message),
    };
  }

  /// [note] with all it says, once its lock lets the user through.
  Future<Access<Note>> _unlock(Note note, PasswordPrompt askForPassword) async {
    final full = _full(note);
    if (full == null) return const Denied("Couldn't find the note");
    final result = await _authenticate(full, askForPassword: askForPassword);
    if (result is Failure) return Denied(result.message);
    // As it is now, in case the notes were read in again meanwhile.
    final unlocked = _full(note);
    if (unlocked == null) return const Denied("Couldn't find the note");
    return Granted(unlocked);
  }

  /// Adds the note [draft] has, or saves the changes to the one it's for.
  /// Locking a note takes it off the widget.
  Future<Result> _save(NoteDraft draft) async {
    // All of it now, as the form may close before the note is saved.
    final note = draft.note;
    final title = draft.title.trim();
    final (titleColor, coverColor, locked) =
        (draft.titleColor, draft.coverColor, draft.locked);
    if (title.isEmpty) return Info("Give the note a title");
    try {
      if (note == null) {
        await _notesRepository.insertNote(Note(
          title: title,
          titleColor: titleColor,
          coverColor: coverColor,
          locked: locked,
        ));
        await get();
        return Info("Note Added");
      }
      await _notesRepository.updateNote(note.copyWith(
        title: title,
        titleColor: titleColor,
        coverColor: coverColor,
        locked: locked,
      ));
      if (locked) await _takeOffWidget(note.id);
      await get();
      return Info("Note Updated");
    } catch (e) {
      return Failure("Couldn't save the note");
    }
  }

  /// Saves [content], delta ops, as [note]'s text, keeping its title, colours
  /// and lock, and returns the note as it's saved.
  Future<Note> _saveContent(
      Note note, List<Map<String, dynamic>> content) async {
    final saved = NoteDocumentUtils.withContent(note, content);
    await _notesRepository.updateNote(saved);
    _replace(saved);
    return saved;
  }

  /// Shows [note]'s text on the home screen's widget, where anyone can read
  /// it, so never a locked note's.
  Future<Result> _showOnWidget(Note note) async {
    if (note.locked) {
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
      a.locked == b.locked;

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
        if (note == null || note.locked) {
          await _homeWidgetService.clearNote();
        }
        return;
      }
      final notes = _notes.where((note) => note.body == shown.text);
      if (notes.any((note) => note.locked)) {
        await _homeWidgetService.clearNote();
      } else if (notes.firstOrNull case final note?) {
        await _homeWidgetService.followNote(note.id!);
      }
    } catch (e) {
      // The widget's own trouble.
    }
  }

  /// Deletes [note], once its lock lets the user through.
  Future<Result> _delete(Note note,
      {required PasswordPrompt askForPassword}) async {
    final isAuthenticated =
        await _authenticate(note, askForPassword: askForPassword);
    if(isAuthenticated is Success){
      try{
        await _notesRepository.deleteNote(note.id!);
        await _takeOffWidget(note.id);
        await get();
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
      if (notes.any((note) => note.locked) &&
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
      if (overwrite && currentNotes.any((note) => note.locked)) {
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
      await get();
      return Success("Data Restored");
    } on WrongBackupKindException {
      return Failure("That's a backup of tasks, not notes");
    } catch (e) {
      return Failure("Failed To Restore");
    }
  }

  /// Checks it's the user, for a locked [note]: see [_passNoteLock].
  Future<Result> _authenticate(Note note,
      {required PasswordPrompt askForPassword}) async {
    if (note.locked) {
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

/// A note as its form has it, being added or having its title, colours and
/// lock changed, with the form's rules: a plain title follows the cover,
/// and locking the note takes its lock.
class NoteDraft with ChangeNotifier {
  NoteDraft._(this._notes, this.note)
      : _title = note?.title ?? "",
        _titleColor = note?.titleColor ?? Note.defaultTitleColor,
        _coverColor = note?.coverColor ?? Note.defaultCoverColor,
        _locked = note?.locked ?? false;

  final NotesViewModel _notes;

  /// The note being changed, with all it says, or null for a new one.
  final Note? note;

  bool get adding => note == null;

  String _title;
  String get title => _title;

  /// The colours, as 0xAARRGGBB.
  int _titleColor;
  int get titleColor => _titleColor;
  int _coverColor;
  int get coverColor => _coverColor;
  bool _locked;
  bool get locked => _locked;

  /// The title colours that aren't colours, which follow the cover.
  static const _white = 0xFFFFFFFF;
  static const _graphite = 0xFF1E1E1E;
  static const _black = 0xFF000000;

  /// Whether there's a title to save the note with.
  bool get canSave => _title.trim().isNotEmpty;

  void setTitle(String title) {
    final could = canSave;
    _title = title;
    if (canSave != could) notifyListeners();
  }

  /// Sets the cover's colour. A white, graphite or black title follows it,
  /// so it stays readable; a colourful one was picked on purpose, and stays.
  void setCoverColor(int color) {
    _coverColor = color;
    if (_titleColor == _white ||
        _titleColor == _graphite ||
        _titleColor == _black) {
      _titleColor = _isDark(color) ? _white : _graphite;
    }
    notifyListeners();
  }

  void setTitleColor(int color) {
    _titleColor = color;
    notifyListeners();
  }

  /// Whether white reads better than black on [color], as the note's card
  /// decides the colour of its text, after ThemeData.estimateBrightnessForColor.
  static bool _isDark(int color) {
    final luminance = Color(color).computeLuminance();
    return (luminance + 0.05) * (luminance + 0.05) <= 0.15;
  }

  /// Locks the note, once its lock lets the user through, as it will each
  /// time the note opens, or unlocks it, which the note's lock let them do
  /// as they opened it to change it. Why the note couldn't be locked, or
  /// null.
  Future<Result?> setLocked(bool locked,
      {required PasswordPrompt askForPassword}) async {
    if (locked && !_locked) {
      final result = await _notes._passNoteLock(askForPassword);
      if (result is! Success) return result;
    }
    _locked = locked;
    notifyListeners();
    return null;
  }

  /// Adds the note, or saves the changes to the one it's for.
  Future<Result> save() => _notes._save(this);
}

/// A note open in its editor, with all it says: its text, saved as it's
/// written while the user has auto-save on, and what can be done with the
/// note there.
class NoteEditorViewModel {
  NoteEditorViewModel._(this._notes, this._note)
      : content = NoteDocumentUtils.contentOf(_note) {
    _edited = content;
    _editedJson = _savedJson = jsonEncode(content);
  }

  /// How long the writing pauses before it's saved.
  static const autoSaveDelay = Duration(milliseconds: 500);

  final NotesViewModel _notes;
  Note _note;

  /// The note as it was last saved.
  Note get note => _note;

  /// The note's text as it opened, with its formatting, as Quill delta ops,
  /// for the editor to start from.
  final List<Map<String, dynamic>> content;

  /// The text as it's been written, and as it was last saved, as JSON.
  late List<Map<String, dynamic>> _edited;
  late String _editedJson;
  late String _savedJson;

  final _unsaved = ValueNotifier(false);

  /// Whether there are changes since the note was last saved.
  ValueListenable<bool> get unsaved => _unsaved;

  final _failures = StreamController<String>.broadcast();

  /// Why a save didn't go through, each time one doesn't.
  Stream<String> get failures => _failures.stream;

  Timer? _autoSave;

  /// The saves in hand, which go one at a time, in order.
  Future<void> _saving = Future.value();
  bool _disposed = false;

  /// Takes [content], the editor's text as delta ops, as it's written. With
  /// [autoSave] on, it's saved once the writing pauses.
  void edit(List<Map<String, dynamic>> content, {required bool autoSave}) {
    _edited = content;
    _editedJson = jsonEncode(content);
    _unsaved.value = _editedJson != _savedJson;
    _autoSave?.cancel();
    _autoSave =
        autoSave && _unsaved.value ? Timer(autoSaveDelay, save) : null;
  }

  /// Saves the text as it is now.
  Future<void> save() {
    _autoSave?.cancel();
    _autoSave = null;
    return _saving = _saving.then((_) => _write());
  }

  /// Saves straight away what would be saved once the writing paused, as
  /// when the app is put away.
  Future<void> flush() => _autoSave == null ? _saving : save();

  Future<void> _write() async {
    final (content, json) = (_edited, _editedJson);
    if (json == _savedJson) return;
    try {
      _note = await _notes._saveContent(_note, content);
      _savedJson = json;
    } catch (e) {
      if (!_disposed) {
        _failures.add("Sorry, Something went wrong, note not saved");
      }
    }
    // Still unsaved if it was written in while it saved.
    if (!_disposed) _unsaved.value = _editedJson != _savedJson;
  }

  /// Shows the note's saved text on the home screen's widget.
  Future<Result> showOnWidget() => _notes._showOnWidget(_note);

  /// Deletes the note, once its lock lets the user through, with
  /// [askForPassword] for the App Lock's password on a phone that can't take
  /// a fingerprint.
  Future<Result> delete({required PasswordPrompt askForPassword}) async {
    final result = await _notes._delete(_note, askForPassword: askForPassword);
    if (result is! Failure) {
      _autoSave?.cancel();
      _autoSave = null;
    }
    return result;
  }

  /// Saves what's waiting to be saved, then lets the editor go.
  void dispose() {
    _disposed = true;
    flush().whenComplete(() {
      _unsaved.dispose();
      _failures.close();
    });
  }
}
