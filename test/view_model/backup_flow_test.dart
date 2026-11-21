import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/prompts.dart';
import 'package:todo/core/result.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/backup_service.dart';
import 'package:todo/services/file_service.dart';
import 'package:todo/view_model/backup_flow.dart';

/// The App Lock as a test has it: [pass] is what letting the user through
/// comes to, or null when they cancel.
class FakeAppLock extends AuthenticationService {
  FakeAppLock([this.pass = (passed: true, password: null)]);

  AppLockPass? pass;

  @override
  Future<AppLockPass?> passAppLock(PasswordPrompt askForPassword) async => pass;
}

/// Files in memory: the last one saved, and the one the user picks next.
class MemoryFiles extends FileService {
  ({Uint8List bytes, String name})? saved;

  /// Where a file is saved, or null when the user chooses nowhere.
  String? savedTo = "content://downloads/1";
  Uint8List? picked;
  var picks = 0;

  @override
  Future<String?> saveFile(Uint8List bytes, String fileName) async {
    saved = (bytes: bytes, name: fileName);
    return savedTo;
  }

  @override
  Future<Uint8List?> pickJsonFile() async {
    picks++;
    return picked;
  }
}

/// A new backup password, given twice: [password], or none when the user
/// cancels.
NewBackupPasswordPrompt newBackupPassword(String? password) =>
    ({required int minLength, required lock}) async =>
        password != null && await lock(password) is Success;

/// A backup's password: [password], or none when the user cancels.
BackupPasswordPrompt backupPassword(String? password) =>
    (open) async => password != null && await open(password) is Success;

Future<String?> noPassword() async => null;

void main() {
  late FakeAppLock appLock;
  late MemoryFiles files;

  setUp(() {
    appLock = FakeAppLock();
    files = MemoryFiles();
  });

  BackupFlow flow(BackupKind kind) => BackupFlow(
    kind,
    authService: appLock,
    backupService: BackupService.inDart(iterations: 1000),
    fileService: files,
  );

  Future<Result?> backUp(
    BackupFlow flow,
    Future<Access<List<Map<String, Object?>>>> Function(String? password)
    records,
  ) => flow.backUp(
    askForPassword: noPassword,
    askForBackupPassword: newBackupPassword("correct horse"),
    records: records,
  );

  test("backs up the records to a file only their password opens", () async {
    final tasks = flow(BackupKind.tasks);
    final result = await backUp(
      tasks,
      (_) async => Granted([
        {'title': "Call"},
      ]),
    );
    expect((result as Success).message, "Backup Created");
    expect(files.saved!.name, "todo.json");

    files.picked = files.saved!.bytes;
    List<dynamic>? read;
    final restored = await tasks.restore(
      askForBackupPassword: backupPassword("correct horse"),
      putBack: (records) async {
        read = records;
        return const Success("Data Restored");
      },
    );
    expect((restored as Success).message, "Data Restored");
    expect(read, [
      {'title': "Call"},
    ]);
  });

  test("hands the records the App Lock's password, and stops where they say "
      "why not", () async {
    appLock.pass = (passed: true, password: "1234");
    String? given;
    final result = await backUp(flow(BackupKind.notes), (password) async {
      given = password;
      return const Denied("Authentication failed");
    });
    expect((result as Failure).message, "Authentication failed");
    expect(given, "1234");
    expect(files.saved, isNull);
  });

  test("says so when the App Lock keeps the user out, and nothing when they "
      "cancel", () async {
    var read = 0;
    Future<Access<List<Map<String, Object?>>>> records(String? _) async {
      read++;
      return const Granted([]);
    }

    appLock.pass = (passed: false, password: null);
    final refused = await backUp(flow(BackupKind.tasks), records);
    expect((refused as Failure).message, "Authentication failed");
    appLock.pass = null;
    expect(await backUp(flow(BackupKind.tasks), records), isNull);
    expect(read, 0);
  });

  test("says so when nowhere is chosen for the file, and nothing when the "
      "backup's password is cancelled", () async {
    files.savedTo = null;
    final nowhere = await backUp(
      flow(BackupKind.notes),
      (_) async => const Granted([]),
    );
    expect((nowhere as Info).message, "You didn't choose a directory");
    expect(files.saved!.name, "notes.json");

    final cancelled = await flow(BackupKind.notes).backUp(
      askForPassword: noPassword,
      askForBackupPassword: newBackupPassword(null),
      records: (_) async => const Granted([]),
    );
    expect(cancelled, isNull);
  });

  test(
    "says what it couldn't back up when the records can't be read",
    () async {
      final result = await backUp(
        flow(BackupKind.notes),
        (_) async => throw StateError("Disk error"),
      );
      expect((result as Failure).message, "Couldn't back up the notes");
    },
  );

  group('restoring', () {
    test("says so when no file is chosen", () async {
      final result = await flow(BackupKind.tasks).restore(
        askForBackupPassword: backupPassword("correct horse"),
        putBack: (_) async => const Success("Data Restored"),
      );
      expect((result as Info).message, "You didn't choose a file");
    });

    test("turns away a backup of the other kind", () async {
      await backUp(flow(BackupKind.notes), (_) async => const Granted([]));
      files.picked = files.saved!.bytes;
      final result = await flow(BackupKind.tasks).restore(
        askForBackupPassword: backupPassword("correct horse"),
        putBack: (_) async => const Success("Data Restored"),
      );
      expect(
        (result as Failure).message,
        "That's a backup of notes, not tasks",
      );
    });

    test("says nothing when the password is cancelled, and so when the "
        "records can't be put back", () async {
      await backUp(flow(BackupKind.tasks), (_) async => const Granted([]));
      files.picked = files.saved!.bytes;
      final cancelled = await flow(BackupKind.tasks).restore(
        askForBackupPassword: backupPassword(null),
        putBack: (_) async => const Success("Data Restored"),
      );
      expect(cancelled, isNull);

      final failed = await flow(BackupKind.tasks).restore(
        askForBackupPassword: backupPassword("correct horse"),
        putBack: (_) async => throw StateError("Disk full"),
      );
      expect((failed as Failure).message, "Couldn't restore the backup");
    });
  });
}
