import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/result.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/note.dart';
import 'package:todo/models/trashed.dart';
import 'package:todo/repositories/notes_repository.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/backup_service.dart';
import 'package:todo/services/home_widget_service.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/view_model/notes_view_model.dart';

import 'backup_flow_test.dart'
    show
        MemoryFiles,
        appLockPassword,
        backupPassword,
        newBackupPassword,
        noPassword;
import 'user_view_model_test.dart' show CountingLock;

/// The notes table, in memory.
class FakeNotesRepository extends NotesRepository {
  final rows = <Note>[];
  var reads = 0;
  var _nextId = 1;
  bool failUpdates = false;

  /// Whether reading the notes fails, as when the database won't read.
  bool failReads = false;

  Note _withId(Note note) => Note.fromMap({...note.toMap(), 'id': _nextId++});

  @override
  Future<void> insertNote(Note note) async => rows.add(_withId(note));

  @override
  Future<List<Note>> getNotes() async {
    if (failReads) throw StateError("Can't read the notes");
    reads++;
    return List.of(rows);
  }

  @override
  Future<void> updateNote(Note item) async {
    if (failUpdates) throw StateError("Disk full");
    final index = rows.indexWhere((row) => row.id == item.id);
    if (index != -1) rows[index] = item;
  }

  /// The orders the notes were rewritten in, by their titles; and what a
  /// rewrite waits for, if anything, as a slow one would. It fails as an
  /// update does, and numbers the notes afresh from 1, in their new order,
  /// as the real table does once every row has gone.
  final rewrites = <List<String>>[];
  Future<void>? rewriting;

  @override
  Future<void> refreshAllNotes(List<Note> notes) async {
    await rewriting;
    if (failUpdates) throw StateError("Disk full");
    rewrites.add([for (final note in notes) note.title]);
    rows
      ..clear()
      ..addAll([
        for (final (index, note) in notes.indexed)
          Note.fromMap({...note.toMap(), 'id': index + 1}),
      ]);
    _nextId = rows.length + 1;
  }

  @override
  Future<void> importNotes(List<Note> notes, {required bool overwrite}) async {
    if (overwrite) rows.clear();
    rows.addAll(notes.map(_withId));
  }

  /// The trash, the first deleted first. Like the real one, it keeps a note
  /// as backups do, and never gives an entry's id to another.
  final trash = <Trashed<Note>>[];
  var _nextTrashId = 1;

  @override
  Future<Trashed<Note>> moveToTrash(
    Note note, {
    required DateTime deletedAt,
  }) async {
    final index = rows.indexWhere((row) => row.id == note.id);
    if (index == -1) throw StateError("No note ${note.id}");
    rows.removeAt(index);
    final id = _nextTrashId++;
    trash.add(
      Trashed(
        id: id,
        item: Note.fromMap({...note.toMap(), 'id': note.id}),
        deletedAt: deletedAt,
      ),
    );
    return Trashed(id: id, item: note, deletedAt: deletedAt);
  }

  @override
  Future<List<Trashed<Note>>> getTrash() async => trash.reversed.toList();

  /// Back with the id it had when no note has it, among the notes in the
  /// order of their ids, as the table lists them; or else at the end.
  @override
  Future<int?> restoreFromTrash(int id, Note note) async {
    final index = trash.indexWhere((entry) => entry.id == id);
    if (index == -1) return null;
    trash.removeAt(index);
    final free = note.id != null && rows.every((row) => row.id != note.id);
    if (!free) {
      // Past every id there is, as some rows come with their own.
      _nextId = rows.fold(
        _nextId,
        (top, row) => top > row.id! ? top : row.id! + 1,
      );
    }
    final row = Note.fromMap({
      ...note.toMap(),
      'id': free ? note.id : _nextId++,
    });
    final after = rows.indexWhere((each) => each.id! > row.id!);
    rows.insert(after == -1 ? rows.length : after, row);
    return row.id;
  }

  @override
  Future<void> deleteFromTrash(Iterable<int> ids) async {
    final gone = ids.toSet();
    trash.removeWhere((entry) => gone.contains(entry.id));
  }
}

class FakeAuth extends AuthenticationService {
  /// [lockService] is what the App Lock's password is checked against.
  FakeAuth({super.lockService});

  FingerprintCheck fingerprint = FingerprintCheck.passed;
  var fingerprintsAsked = 0;

  @override
  Future<FingerprintCheck> checkFingerprint({
    String reason = 'Please authenticate',
  }) async {
    fingerprintsAsked++;
    return fingerprint;
  }
}

class FakeLock extends LockService {
  FakeLock() : super.withClock(() => throw StateError("No waits"));

  /// Whether what the app is locked with can't be read, as when the phone's
  /// secure storage fails.
  bool unreadable = false;

  @override
  Future<AppLock> getLock() async {
    if (unreadable) throw StateError("Can't read the lock");
    return AppLock.off;
  }
}

class FakeHomeWidget extends HomeWidgetService {
  int? id;
  String? text;

  @override
  Future<({int? id, String? text})> shownNote() async => (id: id, text: text);

  @override
  Future<void> showNote(int noteId, String text) async {
    id = noteId;
    this.text = text;
  }

  @override
  Future<void> clearNote() async => id = text = null;

  @override
  Future<void> followNote(int noteId) async => id = noteId;
}

/// A formatted note's text: a heading, then a line of plain text.
const formatted = [
  {'insert': 'Plans'},
  {
    'insert': '\n',
    'attributes': {'header': 1},
  },
  {'insert': 'Walk by the river\n'},
];

void main() {
  late FakeNotesRepository repository;
  late FakeAuth auth;
  late FakeLock lock;
  late FakeHomeWidget homeWidget;
  late NotesViewModel notes;

  setUp(() async {
    repository = FakeNotesRepository();
    auth = FakeAuth();
    lock = FakeLock();
    homeWidget = FakeHomeWidget();
    notes = NotesViewModel(
      repository: repository,
      authService: auth,
      lockService: lock,
      homeWidgetService: homeWidget,
    );
    repository.rows.addAll([
      Note(
        id: 1,
        title: "Open",
        body: "Plans\nWalk by the river",
        delta: jsonEncode(formatted),
      ),
      const Note(id: 2, title: "Diary", body: "secret", locked: true),
    ]);
    await notes.get();
  });

  Note shown(String title) =>
      notes.notes.singleWhere((note) => note.title == title);

  test(
    "says so when the notes can't be read in, and shows them as they were",
    () async {
      repository.failReads = true;
      expect(
        (await notes.get() as Failure).message,
        "Couldn't read your notes",
      );
      expect(notes.notes.map((note) => note.title), ["Open", "Diary"]);
    },
  );

  group('locked notes', () {
    test("reach the pages without their text", () {
      expect(shown("Diary").body, "");
      expect(shown("Diary").delta, isNull);
      expect(shown("Open").body, "Plans\nWalk by the river");
    });

    test("have no preview, and aren't found by their text", () {
      expect(notes.previewOf(shown("Diary")), isNull);
      expect(notes.previewOf(shown("Open"))!.lines, hasLength(2));
      expect(notes.search("secret"), isEmpty);
      expect(notes.search("diary").single.title, "Diary");
    });

    test(
      "open with all they say once the fingerprint lets the user in",
      () async {
        final access = await notes.open(
          shown("Diary"),
          askForPassword: noPassword,
        );
        final editor = (access as Granted<NoteEditorViewModel>).value;
        expect(editor.note.body, "secret");
        expect(editor.content, [
          {'insert': 'secret\n'},
        ]);
        expect(auth.fingerprintsAsked, 1);
      },
    );

    test("don't open when the fingerprint doesn't", () async {
      auth.fingerprint = FingerprintCheck.failed;
      final access = await notes.edit(
        shown("Diary"),
        askForPassword: noPassword,
      );
      expect((access as Denied).message, "Authentication failed");
    });

    test(
      "don't open without a fingerprint when the App Lock can't be read",
      () async {
        auth.fingerprint = FingerprintCheck.unavailable;
        lock.unreadable = true;
        var asked = 0;
        final access = await notes.open(
          shown("Diary"),
          askForPassword: (check) async {
            asked++;
            return "1234";
          },
        );
        expect((access as Denied).message, "Authentication failed");
        expect(asked, 0);
      },
    );

    test("open without asking when they're not locked", () async {
      final access = await notes.open(
        shown("Open"),
        askForPassword: noPassword,
      );
      expect(access, isA<Granted<NoteEditorViewModel>>());
      expect(auth.fingerprintsAsked, 0);
    });

    test("keep their text when their title is changed", () async {
      final draft = ((await notes.edit(
        shown("Diary"),
        askForPassword: noPassword,
      )) as Granted<NoteDraft>).value..setTitle("Journal");
      expect(await draft.save(), isA<Info>());
      final saved = repository.rows.singleWhere((note) => note.id == 2);
      expect(saved.title, "Journal");
      expect(saved.body, "secret");
      expect(saved.locked, isTrue);
    });
  });

  group('reordering', () {
    setUp(() async {
      repository.rows.add(const Note(id: 3, title: "Shop", body: "Milk"));
      await notes.get();
    });

    List<String> titles(Iterable<Note> notes) => [
      for (final note in notes) note.title,
    ];

    test("shows the new order straight away, then saves it", () async {
      final gate = Completer<void>();
      repository.rewriting = gate.future;
      final moving = notes.syncAfterReorder(2, 0);
      expect(titles(notes.notes), ["Shop", "Open", "Diary"]);

      gate.complete();
      expect(await moving, isNull);
      expect(titles(notes.notes), ["Shop", "Open", "Diary"]);
      expect(titles(repository.rows), ["Shop", "Open", "Diary"]);
    });

    test("says so when it can't be saved, and the notes go back", () async {
      repository.failUpdates = true;
      final result = await notes.syncAfterReorder(2, 0);
      expect((result as Failure).message, "Couldn't move the note");
      expect(titles(notes.notes), ["Open", "Diary", "Shop"]);
    });

    test(
      "keeps one made while another is being saved where it was dropped",
      () async {
        final gate = Completer<void>();
        repository.rewriting = gate.future;
        final first = notes.syncAfterReorder(2, 0);
        // The first is being written as the second is made, on the notes
        // as they show.
        await Future<void>.delayed(Duration.zero);
        final second = notes.syncAfterReorder(2, 1);
        expect(titles(notes.notes), ["Shop", "Diary", "Open"]);

        gate.complete();
        expect(await first, isNull);
        expect(await second, isNull);
        expect(titles(notes.notes), ["Shop", "Diary", "Open"]);
        expect(titles(repository.rows), ["Shop", "Diary", "Open"]);
        expect(repository.rewrites, [
          ["Shop", "Open", "Diary"],
          ["Shop", "Diary", "Open"],
        ]);
      },
    );

    test("made together are saved once, as they leave the notes", () async {
      await Future.wait([
        notes.syncAfterReorder(2, 0),
        notes.syncAfterReorder(2, 1),
      ]);
      expect(repository.rewrites, [
        ["Shop", "Diary", "Open"],
      ]);
    });

    test("keep the widget on its note, whose id changes", () async {
      homeWidget
        ..id = 1
        ..text = "Plans\nWalk by the river";
      await notes.syncAfterReorder(2, 0);
      expect(shown("Open").id, 2);
      expect(homeWidget.id, 2);
    });
  });

  group('NoteDraft', () {
    test("says nothing was saved when the note couldn't be", () async {
      final draft = (await notes.edit(
        shown("Open"),
        askForPassword: noPassword,
      ) as Granted<NoteDraft>).value..setTitle("Weekend");
      repository.failUpdates = true;
      expect(await draft.save(), isA<Unsaved>());
      expect(shown("Open").title, "Open");
    });

    test("a new note is a white title on graphite", () {
      final draft = notes.newDraft();
      expect(draft.adding, isTrue);
      expect(draft.titleColor, Note.defaultTitleColor);
      expect(draft.coverColor, Note.defaultCoverColor);
      expect(draft.canSave, isFalse);
    });

    test("a plain title follows the cover, so it stays readable", () {
      final draft = notes.newDraft()..setCoverColor(0xFFFFCC00);
      expect(draft.titleColor, 0xFF1E1E1E);
      draft.setCoverColor(0xFF5856D6);
      expect(draft.titleColor, 0xFFFFFFFF);
    });

    test("tells a dark cover from a light one as Flutter's colours do", () {
      final draft = notes.newDraft();
      for (var red = 0; red < 256; red += 15) {
        for (var green = 0; green < 256; green += 15) {
          for (var blue = 0; blue < 256; blue += 15) {
            final cover = 0xFF000000 | red << 16 | green << 8 | blue;
            draft.setCoverColor(cover);
            final luminance = Color(cover).computeLuminance();
            final dark = (luminance + 0.05) * (luminance + 0.05) <= 0.15;
            expect(
              draft.titleColor,
              dark ? 0xFFFFFFFF : 0xFF1E1E1E,
              reason: cover.toRadixString(16),
            );
          }
        }
      }
    });

    test("a colourful title stays as it was picked", () {
      final draft = notes.newDraft()
        ..setTitleColor(0xFFFF3B30)
        ..setCoverColor(0xFFFFFFFF);
      expect(draft.titleColor, 0xFFFF3B30);
    });

    test("locking takes the note's lock first", () async {
      auth.fingerprint = FingerprintCheck.failed;
      final draft = notes.newDraft();
      final refused = await draft.setLocked(true, askForPassword: noPassword);
      expect((refused as Failure).message, "Authentication failed");
      expect(draft.locked, isFalse);
      auth.fingerprint = FingerprintCheck.passed;
      expect(await draft.setLocked(true, askForPassword: noPassword), isNull);
      expect(draft.locked, isTrue);
    });

    test("unlocking a note opened to be changed asks nothing more", () async {
      final draft = ((await notes.edit(
        shown("Diary"),
        askForPassword: noPassword,
      )) as Granted<NoteDraft>).value;
      auth.fingerprintsAsked = 0;
      expect(await draft.setLocked(false, askForPassword: noPassword), isNull);
      expect(draft.locked, isFalse);
      expect(auth.fingerprintsAsked, 0);
    });

    test("adds a note with what the form has", () async {
      final draft = notes.newDraft()
        ..setTitle("  Ideas ")
        ..setCoverColor(0xFF34C759);
      expect((await draft.save() as Info).message, "Note Added");
      expect(shown("Ideas").coverColor, 0xFF34C759);
    });

    test("locking a note takes it off the widget", () async {
      homeWidget
        ..id = 1
        ..text = "Plans";
      final draft = ((await notes.edit(
        shown("Open"),
        askForPassword: noPassword,
      )) as Granted<NoteDraft>).value;
      await draft.setLocked(true, askForPassword: noPassword);
      await draft.save();
      expect(homeWidget.id, isNull);
      expect(shown("Open").body, "");
    });
  });

  group('trash', () {
    /// Moves the note titled [title] to the trash, from its editor.
    Future<Trashed<Note>> trash(String title) async {
      final editor = ((await notes.open(
        shown(title),
        askForPassword: noPassword,
      )) as Granted<NoteEditorViewModel>).value;
      expect(await editor.delete(askForPassword: noPassword), isA<Deleted>());
      // The last deleted, which the trash lists first.
      return notes.trash.first;
    }

    List<String> titles() => [for (final note in notes.notes) note.title];

    test("hides a locked note's text, as the pages do", () async {
      final trashed = await trash("Diary");
      expect(trashed.item.body, isEmpty);
      expect(notes.trash.single.item.locked, isTrue);
      expect(notes.trash.single.item.body, isEmpty);
      expect(repository.trash.single.item.body, "secret");
    });

    test("puts a note back where it was, a locked one still locked, "
        "without its lock", () async {
      final trashed = await trash("Open");
      await trash("Diary");
      final asked = auth.fingerprintsAsked;
      expect(await notes.restoreFromTrash(trashed), isA<Success>());
      expect(titles(), ["Open"]);
      expect(await notes.restoreFromTrash(notes.trash.single), isA<Success>());
      expect(titles(), ["Open", "Diary"]);
      expect(repository.rows.last.body, "secret");
      expect(repository.rows.last.locked, isTrue);
      expect(shown("Diary").body, isEmpty);
      expect(auth.fingerprintsAsked, asked);
      expect(notes.trash, isEmpty);
    });

    test("puts a note back once, however often it's asked", () async {
      final trashed = await trash("Open");
      await notes.restoreFromTrash(trashed);
      expect(await notes.restoreFromTrash(trashed), isA<Info>());
      expect(titles(), ["Open", "Diary"]);
    });

    test("puts every note back", () async {
      await trash("Diary");
      await trash("Open");
      final result = await notes.restoreAllFromTrash();
      expect((result as Success).message, "2 Notes Restored");
      expect(titles(), ["Open", "Diary"]);
    });

    test("deletes a note for good", () async {
      final trashed = await trash("Open");
      expect(
        await notes.deleteForever(trashed, askForPassword: noPassword),
        isA<Info>(),
      );
      expect(notes.trash, isEmpty);
      expect(repository.trash, isEmpty);
    });

    test(
      "deletes a locked note for good only once its lock lets the user",
      () async {
        await trash("Diary");
        final entry = notes.trash.single;
        auth.fingerprint = FingerprintCheck.failed;
        expect(
          await notes.deleteForever(entry, askForPassword: noPassword),
          isA<Failure>(),
        );
        expect(repository.trash, hasLength(1));
        auth.fingerprint = FingerprintCheck.passed;
        expect(
          await notes.deleteForever(entry, askForPassword: noPassword),
          isA<Info>(),
        );
        expect(repository.trash, isEmpty);
      },
    );

    test("empties the trash once the lock lets the user, with a locked note "
        "in it", () async {
      await trash("Open");
      await trash("Diary");
      auth.fingerprint = FingerprintCheck.failed;
      expect(
        await notes.emptyTrash(askForPassword: noPassword),
        isA<Failure>(),
      );
      expect(repository.trash, hasLength(2));
      auth.fingerprint = FingerprintCheck.passed;
      final asked = auth.fingerprintsAsked;
      final result = await notes.emptyTrash(askForPassword: noPassword);
      expect((result as Info).message, "2 Notes Deleted Forever");
      expect(auth.fingerprintsAsked, asked + 1);
      expect(repository.trash, isEmpty);
    });

    test(
      "empties the trash without the lock when no note in it is locked",
      () async {
        await trash("Open");
        final asked = auth.fingerprintsAsked;
        expect(await notes.emptyTrash(askForPassword: noPassword), isA<Info>());
        expect(auth.fingerprintsAsked, asked);
        expect(notes.trash, isEmpty);
      },
    );
  });

  group('backups', () {
    late MemoryFiles files;
    late NotesViewModel backingUp;

    setUp(() {
      // The App Lock is off.
      FlutterSecureStorage.setMockInitialValues({});
      files = MemoryFiles();
      backingUp = NotesViewModel(
        repository: repository,
        authService: auth,
        lockService: lock,
        homeWidgetService: homeWidget,
        backupService: BackupService.inDart(iterations: 1000),
        fileService: files,
      );
    });

    test("take a locked note's lock before it goes into the file, with all "
        "it says", () async {
      auth.fingerprint = FingerprintCheck.failed;
      final refused = await backingUp.backup(
        askForPassword: noPassword,
        askForBackupPassword: newBackupPassword("correct horse"),
      );
      expect((refused as Failure).message, "Authentication failed");
      expect(files.saved, isNull);

      auth.fingerprint = FingerprintCheck.passed;
      final result = await backingUp.backup(
        askForPassword: noPassword,
        askForBackupPassword: newBackupPassword("correct horse"),
      );
      expect((result as Success).message, "Backup Created");
      final records = await BackupService.inDart(iterations: 1000).read(
        files.saved!.bytes,
        kind: BackupKind.notes,
        askForPassword: backupPassword("correct horse"),
      );
      expect(
        [for (final record in records!) Note.fromMap(record).body],
        ["Plans\nWalk by the river", "secret"],
      );
    });

    test("restored in place of locked notes take their lock first, and "
        "added to the notes add none twice", () async {
      // A backup from before backups were locked: the open note, as it is,
      // and a new one.
      files.picked = utf8.encode(
        jsonEncode([
          repository.rows.first.toMap(),
          const Note(title: "Shopping", body: "Milk").toMap(),
        ]),
      );
      auth.fingerprint = FingerprintCheck.failed;
      final refused = await backingUp.restore(
        true,
        askForPassword: noPassword,
        askForBackupPassword: backupPassword(null),
      );
      expect((refused as Failure).message, "Authentication failed");
      expect(files.picks, 0);
      expect(repository.rows.map((note) => note.title), ["Open", "Diary"]);

      final added = await backingUp.restore(
        false,
        askForPassword: noPassword,
        askForBackupPassword: backupPassword(null),
      );
      expect((added as Success).message, "Data Restored");
      expect(repository.rows.map((note) => note.title), [
        "Open",
        "Diary",
        "Shopping",
      ]);
    });
  });

  group("on a phone without a fingerprint, with a password App Lock, "
      "locked notes", () {
    late CountingLock appLock;
    late NotesViewModel locked;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      appLock = CountingLock();
      await appLock.enableLock(password: "1234", key: "database key");
      locked = NotesViewModel(
        repository: repository,
        authService: FakeAuth(lockService: appLock)
          ..fingerprint = FingerprintCheck.unavailable,
        lockService: appLock,
        homeWidgetService: homeWidget,
        backupService: BackupService.inDart(iterations: 1000),
        fileService: MemoryFiles(),
      );
      await locked.get();
    });

    Note diary() => locked.notes.singleWhere((note) => note.title == "Diary");

    test("open with the App Lock's password, each one entered checked the "
        "once", () async {
      final tried = <String>[];
      final access = await locked.open(
        diary(),
        askForPassword: (check) async {
          for (final password in ["0000", "1234"]) {
            tried.add(password);
            if (await check(password) is Success) return password;
          }
          return null;
        },
      );
      final editor = (access as Granted<NoteEditorViewModel>).value;
      expect(editor.note.body, "secret");
      expect(tried, ["0000", "1234"]);
      expect(appLock.checks, 2);
    });

    test("don't open for a password the check didn't pass, whatever the "
        "prompt gives", () async {
      final access = await locked.edit(
        diary(),
        askForPassword: (check) async => "1234",
      );
      expect((access as Denied).message, "Authentication failed");
      expect(appLock.checks, 0);
    });

    test("go into a backup on the App Lock's password, checked the once for "
        "the App Lock and their lock both", () async {
      final result = await locked.backup(
        askForPassword: appLockPassword("1234"),
        askForBackupPassword: newBackupPassword("correct horse"),
      );
      expect((result as Success).message, "Backup Created");
      expect(appLock.checks, 1);
    });
  });

  group('NoteEditorViewModel', () {
    Future<NoteEditorViewModel> openNote(String title) async =>
        ((await notes.open(
          shown(title),
          askForPassword: noPassword,
        )) as Granted<NoteEditorViewModel>).value;

    const edited = [
      {'insert': 'Plans for Sunday\n'},
    ];

    testWidgets("auto-saves once the writing pauses", (tester) async {
      final editor = await openNote("Open");
      editor.edit(
        () => [
          {'insert': 'Plans for\n'},
        ],
        autoSave: true,
      );
      await tester.pump(const Duration(milliseconds: 300));
      editor.edit(() => edited, autoSave: true);
      expect(editor.unsaved.value, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.rows.first.body, "Plans\nWalk by the river");
      await tester.pump(NoteEditorViewModel.autoSaveDelay);
      expect(repository.rows.first.body, "Plans for Sunday");
      expect(repository.rows.first.delta, jsonEncode(edited));
      expect(editor.unsaved.value, isFalse);
    });

    testWidgets("saves only when asked with auto-save off", (tester) async {
      final editor = await openNote("Open");
      editor.edit(() => edited, autoSave: false);
      await tester.pump(const Duration(seconds: 2));
      expect(repository.rows.first.body, "Plans\nWalk by the river");
      expect(editor.unsaved.value, isTrue);
      await editor.save();
      await tester.pump();
      expect(repository.rows.first.body, "Plans for Sunday");
      expect(editor.unsaved.value, isFalse);
    });

    testWidgets("saves what's waiting as it closes", (tester) async {
      final editor = await openNote("Open");
      editor
        ..edit(() => edited, autoSave: true)
        ..dispose();
      await tester.pump();
      expect(repository.rows.first.body, "Plans for Sunday");
    });

    testWidgets("puts the saved note in the list without reading them all", (
      tester,
    ) async {
      final editor = await openNote("Open");
      final reads = repository.reads;
      editor.edit(() => edited, autoSave: false);
      await editor.save();
      await tester.pump();
      expect(repository.reads, reads);
      expect(shown("Open").body, "Plans for Sunday");
      expect(editor.note.body, "Plans for Sunday");
    });

    testWidgets(
      "has nothing unsaved once it's written back as it was, as the writing "
      "pauses",
      (tester) async {
        final editor = await openNote("Open");
        editor.edit(() => edited, autoSave: false);
        expect(editor.unsaved.value, isTrue);
        editor.edit(() => editor.content, autoSave: false);
        await tester.pump(NoteEditorViewModel.settleDelay);
        expect(editor.unsaved.value, isFalse);
      },
    );

    testWidgets(
      "takes the text from the editor once the writing pauses, not on each "
      "key",
      (tester) async {
        final editor = await openNote("Open");
        var taken = 0;
        List<Map<String, dynamic>> text() {
          taken++;
          return edited;
        }

        for (var key = 0; key < 20; key++) {
          editor.edit(text, autoSave: true);
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(taken, 0);
        await tester.pump(NoteEditorViewModel.autoSaveDelay);
        expect(taken, 1);
        expect(repository.rows.first.body, "Plans for Sunday");
      },
    );

    test("says when a save fails", () async {
      final editor = await openNote("Open");
      final failures = <String>[];
      final subscription = editor.failures.listen(failures.add);
      repository.failUpdates = true;
      editor.edit(() => edited, autoSave: false);
      await editor.save();
      await Future<void>.delayed(Duration.zero);
      expect(failures, ["Couldn't save the note"]);
      expect(editor.unsaved.value, isTrue);
      await subscription.cancel();
    });

    test(
      "shows the saved text on the widget, but not a locked note's",
      () async {
        final open = await openNote("Open");
        expect(await open.showOnWidget(), isA<Info>());
        expect(homeWidget.text, "Plans\nWalk by the river");
        final diary = await openNote("Diary");
        expect(
          (await diary.showOnWidget() as Info).message,
          "Locked notes can't go on the widget",
        );
      },
    );

    test("moves the note to the trash, and takes it off the widget", () async {
      final editor = await openNote("Open");
      await editor.showOnWidget();
      final result = await editor.delete(askForPassword: noPassword);
      expect((result as Deleted).message, "Note moved to Trash");
      expect(repository.rows.map((note) => note.title), ["Diary"]);
      expect(notes.notes.map((note) => note.title), ["Diary"]);
      expect(notes.trash.single.item.body, "Plans\nWalk by the river");
      expect(homeWidget.id, isNull);
    });

    test("deleting it comes with an Undo that puts it back", () async {
      final editor = await openNote("Open");
      final result = await editor.delete(askForPassword: noPassword);
      expect(await (result as Deleted).undo(), isA<Success>());
      expect(notes.notes.map((note) => note.title), ["Open", "Diary"]);
      expect(notes.trash, isEmpty);
    });

    test(
      "puts what's waiting to be saved in the trash with the note",
      () async {
        final editor = await openNote("Open");
        editor.edit(() => edited, autoSave: true);
        await editor.delete(askForPassword: noPassword);
        expect(repository.trash.single.item.body, "Plans for Sunday");
        expect(repository.trash.single.item.delta, jsonEncode(edited));
      },
    );

    test("keeps a locked note where it is when its lock says no", () async {
      final editor = await openNote("Diary");
      auth.fingerprint = FingerprintCheck.failed;
      expect(await editor.delete(askForPassword: noPassword), isA<Failure>());
      expect(repository.rows.map((note) => note.title), ["Open", "Diary"]);
      expect(repository.trash, isEmpty);
    });

    test("moves the note to the trash though the notes can't be read in "
        "after it", () async {
      final editor = await openNote("Open");
      repository.failReads = true;
      expect(await editor.delete(askForPassword: noPassword), isA<Deleted>());

      repository.failReads = false;
      await notes.get();
      expect(notes.notes.map((note) => note.title), ["Diary"]);
      expect(notes.trash.single.item.title, "Open");
    });
  });
}
