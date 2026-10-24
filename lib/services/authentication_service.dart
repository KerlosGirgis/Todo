import 'package:flutter/services.dart';

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

class AuthenticationService {
  /// The app's own Android code for the fingerprint, which takes only
  /// Android's strongest biometrics, rather than also the weaker ones, such
  /// as a face unlock that a photo can fool, as the local_auth plugin did. A
  /// phone with nothing stronger set up still uses the weaker ones.
  static const _channel = MethodChannel('com.k.todo/biometrics');

  final LockService _lockService = LockService();

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
  /// fingerprint, or [password], whichever it's locked with.
  Future<bool> passesAppLock({String? password}) async {
    return switch (await _lockService.getLock()) {
      AppLock.off => true,
      AppLock.fingerprint => await authenticate(),
      AppLock.password => password != null &&
          (await _lockService.checkPassword(password)).matched,
    };
  }
}
