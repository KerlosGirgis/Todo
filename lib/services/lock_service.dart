import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_lock.dart';
import 'device_service.dart';

/// What checking a password against the App Lock's found: whether it was the
/// one, and, after too many that weren't, how long until another can be
/// tried.
typedef PasswordCheck = ({bool matched, Duration wait});

class LockService {
  LockService() : _bootTime = DeviceService().bootTime;

  /// For tests, whose waits go by [bootTime], a clock of their own.
  @visibleForTesting
  LockService.withClock(Future<BootTime> Function() bootTime)
      : _bootTime = bootTime;

  final _storage = const FlutterSecureStorage();

  /// The phone's clock since it started, which the waits after wrong
  /// passwords go by, as turning the phone's clock forward can't hurry it.
  final Future<BootTime> Function() _bootTime;

  static const _lockKey = 'lockToken';

  /// The App Lock's password, for an app locked with one: salted and
  /// stretched, never as it was typed.
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

  /// Rounds of PBKDF2 a password is stretched with, so that a hash read out
  /// of storage would be slow to guess from. Each hash keeps the count it was
  /// made with, so the count can go up without locking anyone out.
  static const _iterations = 20000;

  Future<AppLock> getLock() async {
    if (await _storage.read(key: _lockKey) == null) return AppLock.off;
    return await _storage.read(key: _passwordKey) == null
        ? AppLock.fingerprint
        : AppLock.password;
  }

  /// Locks the app with [password], or with the user's fingerprint without
  /// one.
  Future<void> enableLock({String? password}) async {
    // The password before the lock, so that an app closed in between can't
    // be left locked with the fingerprint instead.
    if (password == null) {
      await _storage.delete(key: _passwordKey);
    } else {
      await _storage.write(key: _passwordKey, value: await _hash(password));
    }
    await _forgetFailures();
    await _storage.write(key: _lockKey, value: _generateToken());
  }

  Future<void> disableLock() async {
    await _storage.delete(key: _lockKey);
    await _storage.delete(key: _passwordKey);
    await _forgetFailures();
  }

  /// Checks [password] against the App Lock's. After [_freeTries] wrong ones
  /// in a row, each next try has to wait, longer and longer, even across
  /// restarts of the app or the phone, so that passwords can't be guessed one
  /// after another.
  Future<PasswordCheck> checkPassword(String password) async {
    final failures =
        int.tryParse(await _storage.read(key: _failuresKey) ?? '') ?? 0;
    final wait = await _retryWaitLeft(failures);
    if (wait > Duration.zero) return (matched: false, wait: wait);

    final saved = await _storage.read(key: _passwordKey);
    if (saved != null && await _matches(password, saved)) {
      await _forgetFailures();
      return (matched: true, wait: Duration.zero);
    }
    await _storage.write(key: _failuresKey, value: '${failures + 1}');
    if (failures + 1 < _freeTries) {
      return (matched: false, wait: Duration.zero);
    }
    final next = _waitAfter(failures + 1);
    await _retryAfter(await _bootTime(), next);
    return (matched: false, wait: next);
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

  /// [password], salted and stretched, after what it takes to check another
  /// against it: `pbkdf2-sha256:<iterations>:<salt>:<hash>`.
  static Future<String> _hash(String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final hash = await _stretch(password, salt, _iterations);
    return 'pbkdf2-sha256:$_iterations:'
        '${base64.encode(salt)}:${base64.encode(hash)}';
  }

  /// Whether [password] is the one [saved] was made from by [_hash].
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
