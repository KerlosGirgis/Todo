import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/prompts.dart';
import '../core/result.dart';
import '../core/utils/note_document_utils.dart';
import '../models/app_lock.dart';
import '../models/note.dart';
import '../models/note_preview.dart';
import '../models/trashed.dart';
import '../repositories/notes_repository.dart';
import '../services/authentication_service.dart';
import '../services/backup_service.dart';
import '../services/file_service.dart';
import '../services/home_widget_service.dart';
import '../services/lock_service.dart';
import 'backup_flow.dart';
import 'trash_bin.dart';

class NotesViewModel with ChangeNotifier implements TrashOwner<Note> {
  NotesViewModel({
    NotesRepository? repository,
    AuthenticationService? authService,
    LockService? lockService,
    HomeWidgetService? homeWidgetService,
    BackupService? backupService,
    FileService? fileService,
    DateTime Function()? clock,
  }) : _notesRepository = repository ?? NotesRepository(),
       _authService = authService ?? AuthenticationService(),
       _lockService = lockService ?? LockService(),
       _homeWidgetService = homeWidgetService ?? HomeWidgetService(),
       _backups = BackupFlow(
         BackupKind.notes,
         authService: authService,
         backupService: backupService,
         fileService: fileService,
       ),
       _now = clock ?? DateTime.now;

  /// The notes, with all they say.
  List<Note> _notes = [];

  /// The notes as the pages get them: without a locked note's text, which
  /// only its editor gets, once its lock lets the user through.
  List<Note> _shown = [];
  List<Note> get notes => UnmodifiableListView(_shown);

  int get lockedCount => _notes.where((note) => note.locked).length;

  /// The notes in the trash, with all they say, which the pages get
  /// without a locked note's text.
  late final _trash = TrashBin<Note>(
    noun: "note",
    read: () => _notesRepository.getTrash(),
    delete: (ids) => _notesRepository.deleteFromTrash(ids),
    changed: notifyListeners,
    shown: _shownInTrash,
  );

  /// The notes in the trash, the last deleted first, as the trash page gets
  /// them, once [getTrash] has read them in: without a locked note's text.
  @override
  List<Trashed<Note>> get trash => _trash.entries;

  final NotesRepository _notesRepository;
  final AuthenticationService _authService;
  final LockService _lockService;
  final HomeWidgetService _homeWidgetService;

  /// Backing the notes up, and restoring them.
  final BackupFlow _backups;
  final DateTime Function() _now;

  /// The time as the notes go by it, which the pages show them as of: the
  /// clock this was made with, which tests can set.
  DateTime get now => _now();

  /// Whether the note on the widget has been checked since the app started:
  /// see [_checkWidget].
  bool _widgetChecked = false;

  /// Reads in the notes, as the notes page does as it opens. Why they
  /// couldn't be, or null: then they're shown as they were.
  Future<Result?> get() async {
    try {
      _notes = await _notesRepository.getNotes();
    } catch (e) {
      return const Failure("Couldn't read your notes");
    }
    _publish();
    if (!_widgetChecked) {
      _widgetChecked = true;
      await _checkWidget();
    }
    return null;
  }

  /// Reads the notes in again once a change has been saved, or has failed,
  /// to show them as they now are. Should that fail, they're shown as they
  /// were until they're next read in: the change has gone through, or the
  /// user has been told it hasn't, either way.
  Future<void> _reload() => get();

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
  Future<Access<NoteDraft>> edit(
    Note note, {
    required PasswordPrompt askForPassword,
  }) async {
    final unlocked = await _unlock(note, askForPassword);
    return switch (unlocked) {
      Granted(:final value) => Granted(NoteDraft._(this, value)),
      Denied(:final message) => Denied(message),
    };
  }

  /// [note], open to be read and written, once its lock lets the user
  /// through: see [_passNoteLock].
  Future<Access<NoteEditorViewModel>> open(
    Note note, {
    required PasswordPrompt askForPassword,
  }) async {
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
    final (titleColor, coverColor, locked) = (
      draft.titleColor,
      draft.coverColor,
      draft.locked,
    );
    if (title.isEmpty) return Info("Give the note a title");
    try {
      if (note == null) {
        await _notesRepository.insertNote(
          Note(
            title: title,
            titleColor: titleColor,
            coverColor: coverColor,
            locked: locked,
          ),
        );
        await _reload();
        return Info("Note Added");
      }
      await _notesRepository.updateNote(
        note.copyWith(
          title: title,
          titleColor: titleColor,
          coverColor: coverColor,
          locked: locked,
        ),
      );
      if (locked) await _takeOffWidget(note.id);
      await _reload();
      return Info("Note Updated");
    } catch (e) {
      return const Unsaved("Couldn't save the note");
    }
  }

  /// Saves [content], delta ops, as [note]'s text, keeping its title, colours
  /// and lock, and returns the note as it's saved.
  Future<Note> _saveContent(
    Note note,
    List<Map<String, dynamic>> content,
  ) async {
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
      return Failure("Couldn't show the note on the widget");
    }
    return Info("Note Shown on Widget");
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

  /// Moves [note] to the trash, where it waits to be put back or deleted for
  /// good, once its lock lets the user through, as deleting a locked note
  /// always has, and takes it off the widget. Says so with a [Deleted],
  /// whose undo puts it back; or why it couldn't be moved.
  Future<Result> _moveToTrash(
    Note note, {
    required PasswordPrompt askForPassword,
  }) async {
    final unlocked = await _authenticate(note, askForPassword: askForPassword);
    if (unlocked is! Success) return unlocked;
    final Trashed<Note> trashed;
    try {
      trashed = await _notesRepository.moveToTrash(note, deletedAt: _now());
    } catch (e) {
      return const Failure("Couldn't delete the note");
    }
    await _takeOffWidget(note.id);
    await _reload();
    await _trash.reload();
    // Without a locked note's text, as the pages get the trash.
    final entry = _shownInTrash(trashed);
    return Deleted("Note moved to Trash", undo: () => restoreFromTrash(entry));
  }

  /// Reads in the notes in the trash.
  @override
  Future<Result?> getTrash() => _trash.load();

  /// [entry] as the pages get it: without a locked note's text.
  static Trashed<Note> _shownInTrash(Trashed<Note> entry) =>
      entry.item.locked ? entry.withItem(entry.item.withoutText()) : entry;

  /// Puts the note [entry] holds back with the notes, where it was when it
  /// can. A locked note comes back locked, so it doesn't take the lock.
  @override
  Future<Result> restoreFromTrash(Trashed<Note> entry) async {
    final int? id;
    try {
      final full = await _trash.full(entry);
      id = full == null
          ? null
          : await _notesRepository.restoreFromTrash(full.id, full.item);
    } catch (e) {
      return _trash.unrestorable;
    }
    await _trash.reload();
    await _reload();
    if (id == null) return _trash.gone;
    return _trash.restored;
  }

  /// Puts every note in the trash back with the notes.
  @override
  Future<Result> restoreAllFromTrash() async {
    final (:back, :all) = await _trash.putBackAll(
      (entry) async =>
          await _notesRepository.restoreFromTrash(entry.id, entry.item) != null,
    );
    await _reload();
    return _trash.restoredAll(back, all: all);
  }

  /// Deletes the note [entry] holds for good, once its lock lets the user
  /// through, as deleting a locked note always has: see [_passNoteLock].
  @override
  Future<Result> deleteForever(
    Trashed<Note> entry, {
    PasswordPrompt? askForPassword,
  }) => _trash.deleteForever(
    entry,
    permit: (full) async {
      final unlocked = await _authenticate(
        full.item,
        askForPassword: askForPassword ?? _noPassword,
      );
      return unlocked is Success ? null : unlocked;
    },
  );

  /// Deletes every note in the trash for good, once the note lock lets the
  /// user through, while any of them is locked.
  @override
  Future<Result> emptyTrash({PasswordPrompt? askForPassword}) => _trash.empty(
    permit: (entries) async {
      if (!entries.any((entry) => entry.item.locked)) return null;
      final unlocked = await _passNoteLock(askForPassword ?? _noPassword);
      return unlocked is Success ? null : unlocked;
    },
  );

  /// No password, for a lock asked for without a way to ask for one.
  static Future<String?> _noPassword(
    Future<Result> Function(String password) check,
  ) async => null;

  /// The reorders being saved, which go one at a time, in order; and how
  /// many there have been, as only the last one's order needs saving: it's
  /// the order the notes are in.
  Future<void> _reordering = Future.value();
  var _reorders = 0;

  /// Moves the note at [oldIndex] among [notes] to [newIndex], straight
  /// away, as that's where it was dropped, then saves the notes in their new
  /// order. Why it couldn't be saved, or null; then the notes go back as
  /// they were.
  Future<Result?> syncAfterReorder(int oldIndex, int newIndex) {
    final count = _notes.length;
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= count ||
        newIndex < 0 ||
        newIndex >= count) {
      return Future.value();
    }
    _notes.insert(newIndex, _notes.removeAt(oldIndex));
    _publish();
    // As they are now, as the next reorder can move them while this one is
    // still being saved.
    final order = List.of(_notes);
    final reorder = ++_reorders;
    final saving = _reordering.then((_) async {
      // A later one saves this one's order along with its own.
      if (reorder != _reorders) return null;
      return _saveOrder(order, latest: () => reorder == _reorders);
    });
    _reordering = saving;
    return saving;
  }

  /// Saves the notes in [order], then reads them back in, the widget's note
  /// too: rewriting the table gives every note a new id, and the ids held
  /// before would now point at other notes. Not while [latest] says another
  /// reorder has come since, though, as reading them in would undo it
  /// meanwhile: that one reads them in once it's saved.
  Future<Result?> _saveOrder(
    List<Note> order, {
    required bool Function() latest,
  }) async {
    final onWidget = await _noteOnWidget();
    Result? result;
    try {
      await _notesRepository.refreshAllNotes(order);
    } catch (e) {
      // The order stays as it was in the database, which the notes go back
      // to as they're read in.
      result = const Failure("Couldn't move the note");
    }
    if (!latest()) return null;
    await _reload();
    if (onWidget != null) await _followOnWidget(onWidget);
    return result;
  }

  /// Saves the notes to a file locked with a password that
  /// [askForBackupPassword] gets from the user, once the App Lock lets them
  /// through, with [askForPassword] for an app locked with a password, and
  /// while any note is locked, once its lock does too. Null if the user
  /// cancels.
  Future<Result?> backup({
    required PasswordPrompt askForPassword,
    required NewBackupPasswordPrompt askForBackupPassword,
  }) => _backups.backUp(
    askForPassword: askForPassword,
    askForBackupPassword: askForBackupPassword,
    records: (password) async {
      final notes = await _notesRepository.getNotes();
      // Locked notes go into the file with all they say, so it takes their
      // lock, as opening one does: the App Lock may be off, or a password,
      // which a locked note won't take while the fingerprint works. An app
      // locked with the fingerprint has just asked for it, and the password
      // just given, checked as it was entered, is the one a locked note
      // falls back on without it.
      if (notes.any((note) => note.locked) &&
          await _lockService.getLock() != AppLock.fingerprint) {
        switch (await _passNoteLock(
          _noPassword,
          passwordGiven: password != null,
        )) {
          case Failure(:final message) || Info(:final message):
            return Denied(message);
          case Success():
            break;
        }
      }
      return Granted([for (final note in notes) note.toMap()]);
    },
  );

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
    final List<Note> currentNotes;
    try {
      currentNotes = await _notesRepository.getNotes();
    } catch (e) {
      return const Failure("Couldn't restore the backup");
    }
    if (overwrite && currentNotes.any((note) => note.locked)) {
      final unlocked = await _passNoteLock(askForPassword);
      if (unlocked is! Success) return unlocked;
    }
    return _backups.restore(
      askForBackupPassword: askForBackupPassword,
      putBack: (records) async {
        final importedNotes = records
            .map<Note>((e) => Note.fromMap(e))
            .toList();
        final existingNotes = overwrite ? <Note>[] : currentNotes;
        final newNotes = [
          for (final note in importedNotes)
            if (!existingNotes.any((each) => _sameNote(each, note))) note,
        ];
        try {
          // All or nothing, so a restore that fails part-way through leaves
          // the notes as they were.
          await _notesRepository.importNotes(newNotes, overwrite: overwrite);
        } catch (e) {
          return const Failure(
            "Couldn't restore the backup. Nothing was changed.",
          );
        }
        // Replacing the notes deleted the one on the widget, whichever it
        // was.
        if (overwrite) await _clearWidget();
        await _reload();
        return const Success("Data Restored");
      },
    );
  }

  /// Checks it's the user, for a locked [note]: see [_passNoteLock].
  Future<Result> _authenticate(
    Note note, {
    required PasswordPrompt askForPassword,
  }) async {
    if (note.locked) {
      return _passNoteLock(askForPassword);
    } else {
      return Success("Authenticated");
    }
  }

  /// Checks it's the user, as a locked note does: with their fingerprint, or,
  /// on a phone that can't take one, with the App Lock's password, which
  /// [askForPassword] asks them for, checking each one they enter; or which
  /// they've just given, when [passwordGiven], to back the notes up, as the
  /// App Lock asked for it and checked it then.
  Future<Result> _passNoteLock(
    PasswordPrompt askForPassword, {
    bool passwordGiven = false,
  }) async {
    switch (await _authService.checkFingerprint()) {
      case FingerprintCheck.passed:
        return Success("Authenticated");
      case FingerprintCheck.failed:
        return Failure("Authentication failed");
      // Not the password, which anyone who knows it could otherwise get to by
      // failing the fingerprint on purpose.
      case FingerprintCheck.lockedOut:
        return Failure("Too many tries. Try your fingerprint again later.");
      case FingerprintCheck.unavailable:
        final AppLock lock;
        try {
          lock = await _lockService.getLock();
        } catch (e) {
          // Not without telling which password to ask for.
          return Failure("Authentication failed");
        }
        if (lock != AppLock.password) {
          return Failure(
            "Fingerprint isn't available. Set an App Lock password instead.",
          );
        }
        if (passwordGiven) return Success("Authenticated");
        final pass = await _authService.passAppLock(askForPassword);
        if (pass?.passed ?? false) return Success("Authenticated");
        return Failure("Authentication failed");
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
    final luminance = _luminance(color);
    return (luminance + 0.05) * (luminance + 0.05) <= 0.15;
  }

  /// [color]'s relative luminance, from 0 for black to 1 for white, as WCAG
  /// 2.0 has it, and Flutter's `Color.computeLuminance`.
  static double _luminance(int color) {
    double linear(int channel) {
      final value = channel / 255;
      return value <= 0.03928
          ? value / 12.92
          : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * linear(color >> 16 & 0xff) +
        0.7152 * linear(color >> 8 & 0xff) +
        0.0722 * linear(color & 0xff);
  }

  /// Locks the note, once its lock lets the user through, as it will each
  /// time the note opens, or unlocks it, which the note's lock let them do
  /// as they opened it to change it. Why the note couldn't be locked, or
  /// null.
  Future<Result?> setLocked(
    bool locked, {
    required PasswordPrompt askForPassword,
  }) async {
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

  /// How long the writing pauses, with auto-save off, before it's told
  /// whether there's anything to save: nothing, should it be back as it was
  /// saved.
  static const settleDelay = Duration(milliseconds: 300);

  final NotesViewModel _notes;
  Note _note;

  /// The note as it was last saved.
  Note get note => _note;

  /// The note's text as it opened, with its formatting, as Quill delta ops,
  /// for the editor to start from.
  final List<Map<String, dynamic>> content;

  /// The text as it was last taken from the editor, and as it was last
  /// saved, as JSON.
  late List<Map<String, dynamic>> _edited;
  late String _editedJson;
  late String _savedJson;

  /// Gives the editor's text as it is now, as delta ops, once it's changed
  /// since it was last taken: see [edit]. Null till it changes again.
  List<Map<String, dynamic>> Function()? _pending;

  final _unsaved = ValueNotifier(false);

  /// Whether there are changes since the note was last saved.
  ValueListenable<bool> get unsaved => _unsaved;

  final _failures = StreamController<String>.broadcast();

  /// Why a save didn't go through, each time one doesn't.
  Stream<String> get failures => _failures.stream;

  Timer? _autoSave;
  Timer? _settle;

  /// The saves in hand, which go one at a time, in order.
  Future<void> _saving = Future.value();
  bool _disposed = false;

  /// Takes note that the editor's text has changed: [content] gives it as
  /// delta ops. They're asked for once the writing pauses, or the note's
  /// saved, rather than on each key, as making them over a long note would
  /// hold up the writing. With [autoSave] on, the note's saved then.
  void edit(
    List<Map<String, dynamic>> Function() content, {
    required bool autoSave,
  }) {
    _pending = content;
    _unsaved.value = true;
    _autoSave?.cancel();
    _settle?.cancel();
    _autoSave = autoSave ? Timer(autoSaveDelay, save) : null;
    _settle = autoSave ? null : Timer(settleDelay, _settleWriting);
  }

  /// Takes the editor's text, if it's changed since it was last taken.
  void _take() {
    final content = _pending;
    if (content == null) return;
    _pending = null;
    _edited = content();
    _editedJson = jsonEncode(_edited);
  }

  /// Once the writing pauses, with auto-save off: whether there's anything
  /// to save after all.
  void _settleWriting() {
    _settle = null;
    _take();
    if (!_disposed) _unsaved.value = _editedJson != _savedJson;
  }

  /// Saves the text as it is now.
  Future<void> save() {
    _autoSave?.cancel();
    _autoSave = null;
    _settle?.cancel();
    _settle = null;
    // As it is now, whatever's written while it saves.
    _take();
    return _saving = _saving.then((_) => _write());
  }

  /// Saves straight away what would be saved once the writing paused, as
  /// when the app is put away.
  Future<void> flush() => _autoSave == null ? _saving : save();

  Future<void> _write() async {
    final (content, json) = (_edited, _editedJson);
    if (json != _savedJson) {
      try {
        _note = await _notes._saveContent(_note, content);
        _savedJson = json;
      } catch (e) {
        if (!_disposed) {
          _failures.add("Couldn't save the note");
        }
      }
    }
    // Still unsaved if it was written in while it saved, or since.
    if (!_disposed) {
      _unsaved.value = _pending != null || _editedJson != _savedJson;
    }
  }

  /// Shows the note's saved text on the home screen's widget.
  Future<Result> showOnWidget() => _notes._showOnWidget(_note);

  /// Moves the note to the trash, once its lock lets the user through, with
  /// [askForPassword] for the App Lock's password on a phone that can't take
  /// a fingerprint. What's still to be saved, as the editor would save it
  /// as it closes, goes with it. Says so with a [Deleted], whose undo puts
  /// it back; or why it couldn't be moved.
  Future<Result> delete({required PasswordPrompt askForPassword}) async {
    await flush();
    final result = await _notes._moveToTrash(
      _note,
      askForPassword: askForPassword,
    );
    if (result is Deleted) {
      _autoSave?.cancel();
      _autoSave = null;
      _settle?.cancel();
      _settle = null;
    }
    return result;
  }

  /// Saves what's waiting to be saved, then lets the editor go. Before the
  /// editor goes itself, as what's waiting is taken from it.
  void dispose() {
    _disposed = true;
    _settle?.cancel();
    _settle = null;
    flush().whenComplete(() {
      _pending = null;
      _unsaved.dispose();
      _failures.close();
    });
  }
}
