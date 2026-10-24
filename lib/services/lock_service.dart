import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_lock.dart';

/// What checking a password against the App Lock's found: whether it was the
/// one, and, after too many that weren't, how long until another can be
/// tried.
typedef PasswordCheck = ({bool matched, Duration wait});

class LockService {
  final _storage = const FlutterSecureStorage();

  static const _lockKey = 'lockToken';

  /// The App Lock's password, for an app locked with one: salted and
  /// stretched, never as it was typed.
  static const _passwordKey = 'lockPassword';

  /// How many wrong passwords have been tried since the last right one.
  static const _failuresKey = 'lockFailures';

  /// When another password can be tried, after too many wrong ones, in
  /// milliseconds since the epoch.
  static const _retryAtKey = 'lockRetryAt';

  /// How many wrong passwords can be tried in a row before each one after
  /// has to wait [_retryWait].
  static const _freeTries = 5;
  static const _retryWait = Duration(seconds: 30);

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
  /// in a row, each next try has to wait, even across restarts of the app, so
  /// that passwords can't be guessed one after another.
  Future<PasswordCheck> checkPassword(String password) async {
    final now = DateTime.now();
    final wait = await _retryWaitLeft(now);
    if (wait > Duration.zero) return (matched: false, wait: wait);

    final saved = await _storage.read(key: _passwordKey);
    if (saved != null && await _matches(password, saved)) {
      await _forgetFailures();
      return (matched: true, wait: Duration.zero);
    }
    final failures =
        (int.tryParse(await _storage.read(key: _failuresKey) ?? '') ?? 0) + 1;
    await _storage.write(key: _failuresKey, value: '$failures');
    if (failures < _freeTries) return (matched: false, wait: Duration.zero);
    await _retryAfter(now.add(_retryWait));
    return (matched: false, wait: _retryWait);
  }

  /// How long until another password can be tried.
  Future<Duration> _retryWaitLeft(DateTime now) async {
    final retryAt = int.tryParse(await _storage.read(key: _retryAtKey) ?? '');
    if (retryAt == null) return Duration.zero;
    final wait = DateTime.fromMillisecondsSinceEpoch(retryAt).difference(now);
    if (wait <= _retryWait) return wait;
    // Longer than a wait can be, as the clock has been turned back since. The
    // wait starts again from now, rather than lasting until the clock catches
    // up.
    await _retryAfter(now.add(_retryWait));
    return _retryWait;
  }

  Future<void> _retryAfter(DateTime time) => _storage.write(
      key: _retryAtKey, value: '${time.millisecondsSinceEpoch}');

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
