import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/prompts.dart';
import '../core/result.dart';

/// What a backup holds, which a backup of the other kind can't be restored
/// as.
enum BackupKind { tasks, notes }

/// A backup of the other [BackupKind] than the one being restored.
class WrongBackupKindException implements Exception {
  const WrongBackupKindException(this.kind);

  /// What the backup holds.
  final BackupKind kind;
}

/// Turns a password into a backup's key: PBKDF2-HMAC-SHA256 of [password],
/// salted with [salt], over [iterations] rounds, for 32 bytes.
typedef _Stretch = Future<List<int>> Function(
    String password, List<int> salt, int iterations);

/// Backup files: the user's tasks or notes as JSON, locked with a password
/// they choose, as a file can end up anywhere once it's out of the app.
///
/// A file is a JSON object of its `format`, `version` and `kind`, then the
/// `salt` and `iterations` of the PBKDF2-HMAC-SHA256 that stretches the
/// password into an AES-256-GCM key, and the `data` that key encrypted: the
/// nonce, the records and the tag, in base64. The format, version and kind
/// are authenticated along with the records, so changing them leaves the
/// file unopenable.
class BackupService {
  BackupService()
      : iterations = 600000,
        _stretch = _stretchOnPhone;

  /// For tests, which have no phone to stretch passwords on, so do it in
  /// Dart, over as few [iterations] as they can wait for.
  @visibleForTesting
  BackupService.inDart({required this.iterations}) : _stretch = _stretchInDart;

  /// The fewest characters a backup's password can have: more than the App
  /// Lock's, as a backup file can be tried against away from the app, as fast
  /// as a computer can go, with no wait between tries.
  static const minPasswordLength = 8;

  /// Rounds of PBKDF2 a new backup's password is stretched with, as OWASP
  /// advises for PBKDF2-HMAC-SHA256. Each file keeps the count it was made
  /// with, so the count can go up without leaving older files unreadable.
  final int iterations;

  final _Stretch _stretch;

  /// The most rounds a file can ask for, far more than the app makes, so
  /// that a file made to take hours to open is turned away instead.
  static const _maxIterations = 2000000;

  static const _format = 'todo-backup';
  static const _version = 1;

  static const _channel = MethodChannel('com.k.todo/backup');

  /// [records], as a backup file of [kind], locked with a new password that
  /// [askForPassword] gets from the user. Null if they cancel.
  Future<Uint8List?> write(List<Map<String, Object?>> records,
      {required BackupKind kind,
      required NewBackupPasswordPrompt askForPassword}) async {
    Uint8List? file;
    final locked = await askForPassword(
      minLength: minPasswordLength,
      lock: (password) async {
        if (password.length < minPasswordLength) {
          return const Failure("Use at least $minPasswordLength characters");
        }
        try {
          file = await _seal(records, kind: kind, password: password);
          return const Success("Backup Encrypted");
        } catch (e) {
          return const Failure("Couldn't encrypt the backup");
        }
      },
    );
    return locked ? file : null;
  }

  Future<Uint8List> _seal(List<Map<String, Object?>> records,
      {required BackupKind kind, required String password}) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final box = await _encrypt(utf8.encode(jsonEncode(records)),
        await _stretch(password, salt, iterations), _header(kind));
    return utf8.encode(jsonEncode({
      'format': _format,
      'version': _version,
      'kind': kind.name,
      'salt': base64.encode(salt),
      'iterations': iterations,
      'data': base64.encode(box.concatenation()),
    }));
  }

  /// The records in [bytes], a backup file of [kind]: straight away for one
  /// from before backups were locked, or once [askForPassword] gets the
  /// password of one that is. Null if the user cancels.
  ///
  /// Throws a [WrongBackupKindException] for a backup of the other kind, and
  /// a [FormatException] for a file that isn't a backup.
  Future<List<dynamic>?> read(Uint8List bytes,
      {required BackupKind kind,
      required BackupPasswordPrompt askForPassword}) async {
    final file = jsonDecode(utf8.decode(bytes));
    // From before backups were locked: the records as they were.
    if (file is List) return file;
    if (file is! Map<String, dynamic> ||
        file['format'] != _format ||
        file['version'] != _version) {
      throw const FormatException("Not a backup");
    }
    final fileKind = BackupKind.values.asNameMap()[file['kind']];
    if (fileKind == null) throw const FormatException("Not a backup");
    if (fileKind != kind) throw WrongBackupKindException(fileKind);
    final salt = base64.decode(file['salt'] as String);
    final iterations = file['iterations'] as int;
    if (iterations < 1 || iterations > _maxIterations) {
      throw const FormatException("Too many rounds to open");
    }
    final cipher = AesGcm.with256bits();
    final box = SecretBox.fromConcatenation(
      base64.decode(file['data'] as String),
      nonceLength: cipher.nonceLength,
      macLength: cipher.macAlgorithm.macLength,
    );
    List<int>? json;
    final opened = await askForPassword((password) async {
      try {
        json = await _decrypt(
            box, await _stretch(password, salt, iterations), _header(kind));
        return const Success("Backup Unlocked");
      } on SecretBoxAuthenticationError {
        // Or the file's been changed since, which can't be told apart.
        return const Failure("Wrong password");
      } catch (e) {
        return const Failure("Couldn't open the backup");
      }
    });
    if (!opened) return null;
    return jsonDecode(utf8.decode(json!)) as List;
  }

  /// What's authenticated along with a file's records.
  static List<int> _header(BackupKind kind) =>
      utf8.encode('$_format/$_version/${kind.name}');

  // AES-GCM in the background, as a big backup would hold up the page.
  static Future<SecretBox> _encrypt(
          List<int> json, List<int> key, List<int> header) =>
      Isolate.run(() => AesGcm.with256bits()
          .encrypt(json, secretKey: SecretKey(key), aad: header));

  static Future<List<int>> _decrypt(
          SecretBox box, List<int> key, List<int> header) =>
      Isolate.run(() => AesGcm.with256bits()
          .decrypt(box, secretKey: SecretKey(key), aad: header));

  static Future<List<int>> _stretchOnPhone(
          String password, List<int> salt, int iterations) async =>
      (await _channel.invokeMethod<Uint8List>('pbkdf2', {
        'password': password,
        'salt': Uint8List.fromList(salt),
        'iterations': iterations,
      }))!;

  static Future<List<int>> _stretchInDart(
      String password, List<int> salt, int iterations) async {
    final key = await DartPbkdf2(
      macAlgorithm: DartHmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    return key.extractBytes();
  }
}
