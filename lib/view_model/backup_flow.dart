import '../core/prompts.dart';
import '../core/result.dart';
import '../services/authentication_service.dart';
import '../services/backup_service.dart';
import '../services/file_service.dart';

/// Backing the tasks or the notes up to a file, and restoring them from
/// one: what their view models share, from the App Lock and the backup's
/// own password to the file, and what's said of how it went. What's backed
/// up, and how it's put back, are the view model's.
class BackupFlow {
  BackupFlow(
    this.kind, {
    AuthenticationService? authService,
    BackupService? backupService,
    FileService? fileService,
  }) : _authService = authService ?? AuthenticationService(),
       _backupService = backupService ?? BackupService(),
       _fileService = fileService ?? FileService();

  /// What the backups hold.
  final BackupKind kind;

  final AuthenticationService _authService;
  final BackupService _backupService;
  final FileService _fileService;

  /// The name a backup is first offered to be saved under.
  String get _fileName => switch (kind) {
    BackupKind.tasks => 'todo.json',
    BackupKind.notes => 'notes.json',
  };

  /// Saves the [records] to a file locked with a new password that
  /// [askForBackupPassword] gets from the user, once the App Lock lets them
  /// through: with [askForPassword], for an app locked with a password.
  /// [records] gets that password, when one was given, which was checked as
  /// it was entered, so it needn't be again, and can deny the backup, saying
  /// why. Null if the user cancels.
  Future<Result?> backUp({
    required PasswordPrompt askForPassword,
    required NewBackupPasswordPrompt askForBackupPassword,
    required Future<Access<List<Map<String, Object?>>>> Function(
      String? password,
    )
    records,
  }) async {
    final pass = await _authService.passAppLock(askForPassword);
    if (pass == null) return null;
    if (!pass.passed) return const Failure("Authentication failed");
    try {
      switch (await records(pass.password)) {
        case Denied(:final message):
          return Failure(message);
        case Granted(value: final records):
          final file = await _backupService.write(
            records,
            kind: kind,
            askForPassword: askForBackupPassword,
          );
          if (file == null) return null;
          final path = await _fileService.saveFile(file, _fileName);
          if (path == null || path.isEmpty) {
            return const Info("You didn't choose a directory");
          }
          return const Success("Backup Created");
      }
    } catch (e) {
      return Failure("Couldn't back up the ${kind.name}");
    }
  }

  /// Reads the records of a backup file the user picks, once
  /// [askForBackupPassword] gets the password it's locked with, for
  /// [putBack] to put back, which says how that went. Null if the user
  /// cancels.
  Future<Result?> restore({
    required BackupPasswordPrompt askForBackupPassword,
    required Future<Result> Function(List<dynamic> records) putBack,
  }) async {
    try {
      final bytes = await _fileService.pickJsonFile();
      if (bytes == null) return const Info("You didn't choose a file");
      final records = await _backupService.read(
        bytes,
        kind: kind,
        askForPassword: askForBackupPassword,
      );
      if (records == null) return null;
      return await putBack(records);
    } on WrongBackupKindException catch (e) {
      return Failure("That's a backup of ${e.kind.name}, not ${kind.name}");
    } catch (e) {
      return const Failure("Couldn't restore the backup");
    }
  }
}
