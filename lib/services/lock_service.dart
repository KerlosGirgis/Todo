import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart'
    show AesGcm, SecretBox, SecretBoxAuthenticationError, SecretKey;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_lock.dart';
import 'device_service.dart';
import 'key_service.dart';

/// What checking a password against the App Lock's found: whether it was the
/// one, and the database's key, which only it unlocks; or, after too many
/// that weren't, how long until another can be tried.
typedef PasswordCheck = ({bool matched, Duration wait, String? key});

/// Makes the key that locks the database's key from [password]: PBKDF2,
/// salted with [salt], over [iterations] rounds, for 32 bytes.
typedef KeyFromPassword = Future<List<int>> Function(
    String password, List<int> salt, int iterations);

class LockService {
  LockService()
      : _bootTime = DeviceService().bootTime,
        _keyFromPassword = _keyFromPasswordOnPhone,
        _iterations = 100000;

  /// For tests, whose waits go by [bootTime], a clock of their own, and
  /// which have no phone to make keys from passwords on, so make them in
  /// Dart, over as few [iterations] as they can wait for.
  @visibleForTesting
  LockService.withClock(Future<BootTime> Function() bootTime,
      {int iterations = 1000,
      KeyFromPassword keyFromPassword = keyFromPasswordInDart})
      : _bootTime = bootTime,
        _keyFromPassword = keyFromPassword,
        _iterations = iterations;

  final _storage = const FlutterSecureStorage();
  final _keys = KeyService();

  /// The phone's clock since it started, which the waits after wrong
  /// passwords go by, as turning the phone's clock forward can't hurry it.
  final Future<BootTime> Function() _bootTime;

  final KeyFromPassword _keyFromPassword;

  /// Rounds of PBKDF2 a new password is stretched with, so that even on the
  /// phone each guess at it takes a while. Each locked key keeps the count
  /// it was made with, so the count can go up without locking anyone out.
  final int _iterations;

  static const _lockKey = 'lockToken';

  static final _changes = StreamController<AppLock>.broadcast();

  /// What the app is locked with, each time it changes, from whichever
  /// [LockService] changes it.
  Stream<AppLock> get changes => _changes.stream;

  /// For an app locked with a password: the database's key, locked with a
  /// key made from the password, which is never kept as it was typed.
  static const _passwordKey = 'lockPassword';

  /// How many wrong passwords have been tried since the last right one.
  static const _failuresKey = 'lockFailures';

  /// When another password can be tried, after too many wrong ones: by the
  /// phone's clock since it started, as `<boot>:<milliseconds>`.
  static const _retryAtKey = 'lockRetryAt';

  /// How many wrong passwords can be tried in a row before each one after
  /// has to wait.
  static const _freeTries = 5;

  /// How long each try waits after [_freeTries] wrong ones: longer after
  /// each wrong one, up to an hour a try, so that even a four-digit password
  /// takes over a year to guess.
  static const _waits = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(hours: 1),
  ];

  /// The app's own Android code, which makes keys from passwords.
  static const _channel = MethodChannel('com.k.todo/lock');

  /// What locks the database's key, and [_header], which it authenticates
  /// along with the key.
  static final _cipher = AesGcm.with256bits();
  static final _header = utf8.encode('todo-lock/1');

  Future<AppLock> getLock() async {
    if (await _storage.read(key: _lockKey) == null) return AppLock.off;
    return await _storage.read(key: _passwordKey) == null
        ? AppLock.fingerprint
        : AppLock.password;
  }

  /// Locks the app with [password], or with the user's fingerprint without
  /// one. [key] is the database's: the password locks it, so that only the
  /// password opens the database; with the fingerprint, it's kept as it is.
  Future<void> enableLock({String? password, required String key}) async {
    // Should the app be closed part way through, there's always a way left
    // to the database's key: it's kept as it's to be first, then the lock
    // goes on, then the key's other copy goes. The password goes before the
    // lock too, so the app can't be left locked with the fingerprint instead.
    if (password == null) {
      await _keys.keepUnlocked(key);
      await _storage.delete(key: _passwordKey);
    } else {
      final locked = await _lock(key, password);
      // Checked before it takes the place of whatever kept the key before,
      // so that a password that wouldn't unlock it never can.
      if (await _unlock(password, locked) != key) {
        throw StateError("The password didn't lock the database's key");
      }
      await _storage.write(key: _passwordKey, value: locked);
    }
    await _forgetFailures();
    await _storage.write(key: _lockKey, value: _generateToken());
    if (password != null) await _keys.forgetUnlocked();
    _changes.add(password == null ? AppLock.fingerprint : AppLock.password);
  }

  /// Turns the App Lock off, keeping [key], the database's, as it is, for
  /// the app to open with from now on.
  Future<void> disableLock({required String key}) async {
    // The key first, so that it's never left locked with a password that's
    // gone.
    await _keys.keepUnlocked(key);
    await _storage.delete(key: _lockKey);
    await _storage.delete(key: _passwordKey);
    await _forgetFailures();
    _changes.add(AppLock.off);
  }

  /// Checks [password] against the App Lock's, which unlocks the database's
  /// key when it's right. After [_freeTries] wrong ones in a row, each next
  /// try has to wait, longer and longer, even across restarts of the app or
  /// the phone, so that passwords can't be guessed one after another.
  Future<PasswordCheck> checkPassword(String password) async {
    final failures =
        int.tryParse(await _storage.read(key: _failuresKey) ?? '') ?? 0;
    final wait = await _retryWaitLeft(failures);
    if (wait > Duration.zero) return (matched: false, wait: wait, key: null);

    final saved = await _storage.read(key: _passwordKey);
    final key = saved == null ? null : await _unlockSaved(password, saved);
    if (key != null) {
      await _forgetFailures();
      return (matched: true, wait: Duration.zero, key: key);
    }
    await _storage.write(key: _failuresKey, value: '${failures + 1}');
    if (failures + 1 < _freeTries) {
      return (matched: false, wait: Duration.zero, key: null);
    }
    final next = _waitAfter(failures + 1);
    await _retryAfter(await _bootTime(), next);
    return (matched: false, wait: next, key: null);
  }

  /// The database's key, if [password] is the one [saved] was made with;
  /// null if it isn't. Once the password's known to unlock the key, no copy
  /// of the key is kept as it is: one from before the password locked it, or
  /// from a change of lock that didn't finish.
  Future<String?> _unlockSaved(String password, String saved) async {
    if (!saved.startsWith('pbkdf2-sha256:')) {
      final key = await _unlock(password, saved);
      if (key != null) await _keys.forgetUnlocked();
      return key;
    }
    // A password saved before passwords locked the database's key, which
    // was kept as it is till now: checked as it was saved, then it locks the
    // key, once it's sure to unlock it again, as in [enableLock].
    if (!await _matches(password, saved)) return null;
    final key = await _keys.unlockedKey();
    if (key == null) return null;
    try {
      final locked = await _lock(key, password);
      if (await _unlock(password, locked) == key) {
        await _storage.write(key: _passwordKey, value: locked);
        await _keys.forgetUnlocked();
      }
    } catch (e) {
      // Not this time, which doesn't keep the user out: the key stays as it
      // is, and the password as it was, till it's next checked.
    }
    return key;
  }

  /// [key], the database's, locked with [password], as
  /// `lock-key:<iterations>:<salt>:<locked key>`: the nonce, the key and the
  /// tag from AES-256-GCM, under a key made from the password.
  Future<String> _lock(String key, String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final box = await _cipher.encrypt(
      utf8.encode(key),
      secretKey: SecretKey(await _keyFromPassword(password, salt, _iterations)),
      aad: _header,
    );
    return 'lock-key:$_iterations:${base64.encode(salt)}:'
        '${base64.encode(box.concatenation())}';
  }

  /// The database's key in [locked], made by [_lock], if [password] is the
  /// one it was locked with; null if it isn't.
  Future<String?> _unlock(String password, String locked) async {
    if (locked.split(':')
        case ['lock-key', final iterations, final salt, final box]) {
      final secretKey = SecretKey(await _keyFromPassword(
          password, base64.decode(salt), int.parse(iterations)));
      try {
        return utf8.decode(await _cipher.decrypt(
          SecretBox.fromConcatenation(
            base64.decode(box),
            nonceLength: _cipher.nonceLength,
            macLength: _cipher.macAlgorithm.macLength,
          ),
          secretKey: secretKey,
          aad: _header,
        ));
      } on SecretBoxAuthenticationError {
        return null;
      }
    }
    return null;
  }

  /// How long a try waits after [failures] wrong passwords in a row.
  static Duration _waitAfter(int failures) =>
      _waits[(failures - _freeTries).clamp(0, _waits.length - 1)];

  /// How long until another password can be tried, after [failures] wrong
  /// ones.
  Future<Duration> _retryWaitLeft(int failures) async {
    final retryAt = await _storage.read(key: _retryAtKey);
    if (retryAt == null) return Duration.zero;
    final now = await _bootTime();
    final wait = _waitAfter(failures);
    if (retryAt.split(':') case [final boot, final milliseconds]
        when int.tryParse(boot) == now.boot &&
            int.tryParse(milliseconds) != null) {
      final left =
          Duration(milliseconds: int.parse(milliseconds)) - now.sinceBoot;
      if (left <= wait) return left;
    }
    // The phone has restarted since, which starts its clock again, so how
    // much of the wait is left can't be told: it starts again too, in full,
    // so that a restart can't cut it short. As does a wait saved before waits
    // went by this clock, or one longer than it could be.
    await _retryAfter(now, wait);
    return wait;
  }

  Future<void> _retryAfter(BootTime now, Duration wait) => _storage.write(
      key: _retryAtKey,
      value: '${now.boot}:${(now.sinceBoot + wait).inMilliseconds}');

  Future<void> _forgetFailures() async {
    await _storage.delete(key: _failuresKey);
    await _storage.delete(key: _retryAtKey);
  }

  String _generateToken() {
    final data = utf8.encode(DateTime.now().toIso8601String());
    return sha256.convert(data).toString();
  }

  /// Whether [password] is the one [saved] was made from, as passwords were
  /// saved before they locked the database's key:
  /// `pbkdf2-sha256:<iterations>:<salt>:<hash>`.
  static Future<bool> _matches(String password, String saved) async {
    if (saved.split(':')
        case ['pbkdf2-sha256', final iterations, final salt, final hash]) {
      final expected = base64.decode(hash);
      final actual =
          await _stretch(password, base64.decode(salt), int.parse(iterations));
      if (actual.length != expected.length) return false;
      // Every byte is compared, however early they differ, so that how long
      // it takes gives nothing away.
      var difference = 0;
      for (var i = 0; i < actual.length; i++) {
        difference |= actual[i] ^ expected[i];
      }
      return difference == 0;
    }
    return false;
  }

  /// [pbkdf2] in the background, as it's slow on purpose.
  static Future<Uint8List> _stretch(
          String password, List<int> salt, int iterations) =>
      Isolate.run(() => pbkdf2(utf8.encode(password), salt, iterations));

  /// The key [password] makes on the phone, in its own code: PBKDF2, several
  /// times as fast there as in Dart, then an HMAC whose key the phone's
  /// keystore keeps and never lets out, so that a password can only be
  /// guessed on the phone itself, and slowly, not on a copy of its data.
  static Future<List<int>> _keyFromPasswordOnPhone(
          String password, List<int> salt, int iterations) async =>
      (await _channel.invokeMethod<Uint8List>('keyFromPassword', {
        'password': password,
        'salt': Uint8List.fromList(salt),
        'iterations': iterations,
      }))!;

  /// The same in Dart, for tests, with an HMAC key of its own in place of
  /// the phone's.
  @visibleForTesting
  static Future<List<int>> keyFromPasswordInDart(
          String password, List<int> salt, int iterations) async =>
      Hmac(sha256, utf8.encode('phone'))
          .convert(pbkdf2(utf8.encode(password), salt, iterations))
          .bytes;
}

/// PBKDF2 with HMAC-SHA256 (RFC 8018), for a key of one block: 32 bytes.
@visibleForTesting
Uint8List pbkdf2(List<int> password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, password);
  var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final key = Uint8List.fromList(block);
  for (var i = 1; i < iterations; i++) {
    block = hmac.convert(block).bytes;
    for (var j = 0; j < key.length; j++) {
      key[j] ^= block[j];
    }
  }
  return key;
}
