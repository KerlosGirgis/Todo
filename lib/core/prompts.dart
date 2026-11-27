import 'result.dart';

/// Asks the user for the App Lock's password, trying each one they enter
/// with [check], which says why one won't do, until one does, and gives
/// that one, or null if they cancel. [check] is the view model's, so the
/// password is checked the once, as it's entered, by what it's for.
typedef PasswordPrompt = Future<String?> Function(
  Future<Result> Function(String password) check,
);

/// Asks the user for a new password for the App Lock, of at least
/// [minLength] characters, twice, so that a typo can't lock them out, and
/// gives it, or null if they cancel.
typedef NewPasswordPrompt = Future<String?> Function({required int minLength});

/// Asks the user for a new password for a backup, of at least [minLength]
/// characters, twice, so that a typo can't lock them out of it, then locks
/// the backup with it using [lock], and tells whether it did, or false if
/// they cancel.
typedef NewBackupPasswordPrompt = Future<bool> Function({
  required int minLength,
  required Future<Result> Function(String password) lock,
});

/// Asks the user for the password a backup was locked with, trying each one
/// they enter with [open], and tells whether one opened it, or false if they
/// cancel.
typedef BackupPasswordPrompt = Future<bool> Function(
  Future<Result> Function(String password) open,
);
