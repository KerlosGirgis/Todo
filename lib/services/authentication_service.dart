import 'package:flutter/services.dart';

import '../core/prompts.dart';
import '../core/result.dart';
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
/// through, and the password they gave, for an app locked with one, which
/// passed the check as they entered it.
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
  Future<FingerprintCheck> checkFingerprint({
    String reason = 'Please authenticate',
  }) async {
    try {
      return switch (await _channel.invokeMethod<String>('authenticate', {
        'reason': reason,
      })) {
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
      await checkFingerprint(reason: 'Authenticate to access your To-Do app') ==
      FingerprintCheck.passed;

  /// Whether the App Lock lets the user through without a password, as it
  /// does when the app opens: straight away when the app isn't locked, or
  /// with their fingerprint. Not for an app locked with a password, which
  /// [passAppLock] asks for, nor when the lock can't be checked.
  Future<bool> passesAppLock() async {
    try {
      return switch (await _lockService.getLock()) {
        AppLock.off => true,
        AppLock.fingerprint => await authenticate(),
        AppLock.password => false,
      };
    } catch (e) {
      return false;
    }
  }

  /// Lets the user through the App Lock, as [passesAppLock] does, or, for
  /// an app locked with a password, with the one [askForPassword] gets from
  /// them, which tries each one they enter with [checkPassword]: so it's
  /// checked the once, as it's entered, and not again after. Only the one
  /// that passed gets through, whatever the prompt gives. Null if they
  /// cancel. Not when the lock can't be checked.
  Future<AppLockPass?> passAppLock(PasswordPrompt askForPassword) async {
    final AppLock lock;
    try {
      lock = await _lockService.getLock();
    } catch (e) {
      return (passed: false, password: null);
    }
    if (lock != AppLock.password) {
      return (passed: await passesAppLock(), password: null);
    }
    String? passed;
    final password = await askForPassword((password) async {
      final result = await checkPassword(password);
      if (result is Success) passed = password;
      return result;
    });
    if (password == null) return null;
    if (password != passed) return (passed: false, password: null);
    return (passed: true, password: password);
  }

  /// Checks [password] against the App Lock's, as the dialogs that ask for
  /// it do with each one the user enters: why it won't do, if it won't.
  Future<Result> checkPassword(String password) async {
    try {
      return resultOf(await _lockService.checkPassword(password));
    } catch (e) {
      return const Failure(uncheckable);
    }
  }

  /// What's said of a password that couldn't be checked, as when the
  /// phone's secure storage fails.
  static const uncheckable = "Couldn't check the password";

  /// What's said of [check], a password checked against the App Lock's:
  /// "Unlocked", or why the password won't do.
  static Result resultOf(PasswordCheck check) {
    if (check.matched) return const Success("Unlocked");
    if (check.wait > Duration.zero) {
      return Failure("Too many tries. Try again in ${_inWords(check.wait)}.");
    }
    return const Failure("Wrong password");
  }

  /// [wait], rounded up to whole seconds, minutes or hours, as "1 minute".
  static String _inWords(Duration wait) {
    String count(int n, String unit) => "$n $unit${n == 1 ? "" : "s"}";
    final seconds = (wait.inMilliseconds / 1000).ceil();
    if (seconds < 60) return count(seconds, "second");
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return count(minutes, "minute");
    return count((minutes / 60).ceil(), "hour");
  }
}
