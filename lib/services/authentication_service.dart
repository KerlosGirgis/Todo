import 'package:flutter/services.dart';

import '../core/prompts.dart';
import '../models/app_lock.dart';
import 'lock_service.dart';

/// What came of asking for the user's fingerprint.
enum FingerprintCheck {
  passed,

  /// The user cancelled, or their fingerprint didn't match.
  failed,

  /// Too many fingerprints didn't match, so the sensor won't take another
  /// for a while.
  lockedOut,

  /// The phone can't take a fingerprint: it has no sensor, none set up, or
  /// the sensor isn't working.
  unavailable,
}

/// What came of letting the user through the App Lock: whether they got
/// through, and the password they gave, for an app locked with one.
typedef AppLockPass = ({bool passed, String? password});

class AuthenticationService {
  AuthenticationService({LockService? lockService})
      : _lockService = lockService ?? LockService();

  /// The app's own Android code for the fingerprint, which takes only
  /// Android's strongest biometrics, rather than also the weaker ones, such
  /// as a face unlock that a photo can fool, as the local_auth plugin did. A
  /// phone with nothing stronger set up still uses the weaker ones.
  static const _channel = MethodChannel('com.k.todo/biometrics');

  final LockService _lockService;

  Future<bool> authenticate() async =>
      await checkFingerprint() == FingerprintCheck.passed;

  /// Asks for the user's fingerprint, saying why with [reason].
  Future<FingerprintCheck> checkFingerprint(
      {String reason = 'Please authenticate'}) async {
    try {
      return switch (await _channel
          .invokeMethod<String>('authenticate', {'reason': reason})) {
        'passed' => FingerprintCheck.passed,
        'lockedOut' => FingerprintCheck.lockedOut,
        'unavailable' => FingerprintCheck.unavailable,
        _ => FingerprintCheck.failed,
      };
    } catch (e) {
      return FingerprintCheck.failed;
    }
  }

  Future<bool> authenticateApp() async =>
      await checkFingerprint(
          reason: 'Authenticate to access your To-Do app') ==
      FingerprintCheck.passed;

  /// Whether the App Lock lets the user through, as it does when the app
  /// opens: straight away when the app isn't locked, or with their
  /// fingerprint, or [password], whichever it's locked with. Not when the
  /// lock can't be checked.
  Future<bool> passesAppLock({String? password}) async {
    try {
      return switch (await _lockService.getLock()) {
        AppLock.off => true,
        AppLock.fingerprint => await authenticate(),
        AppLock.password => password != null &&
            (await _lockService.checkPassword(password)).matched,
      };
    } catch (e) {
      return false;
    }
  }

  /// Lets the user through the App Lock, as [passesAppLock] does, asking
  /// them with [askForPassword] for the password of an app locked with one.
  /// Null if they cancel.
  Future<AppLockPass?> passAppLock(PasswordPrompt askForPassword) async {
    if (await _lockService.getLock() != AppLock.password) {
      return (passed: await passesAppLock(), password: null);
    }
    final password = await askForPassword();
    if (password == null) return null;
    return (passed: await passesAppLock(password: password), password: password);
  }
}
