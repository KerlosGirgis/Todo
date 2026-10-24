import 'package:local_auth/local_auth.dart';

import '../models/app_lock.dart';
import 'key_service.dart';
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
  final LocalAuthentication _auth = LocalAuthentication();
  final KeyService _keyService = KeyService();
  final LockService _lockService = LockService();

  Future<bool> authenticate() async =>
      await checkFingerprint() == FingerprintCheck.passed;

  Future<FingerprintCheck> checkFingerprint() async {
    try {
      if ((await _auth.getAvailableBiometrics()).isEmpty) {
        return FingerprintCheck.unavailable;
      }
      final passed = await _auth.authenticate(
        localizedReason: 'Please authenticate',
        biometricOnly: true,
      );
      return passed ? FingerprintCheck.passed : FingerprintCheck.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          FingerprintCheck.unavailable,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          FingerprintCheck.lockedOut,
        _ => FingerprintCheck.failed,
      };
    } catch (e) {
      return FingerprintCheck.failed;
    }
  }

  Future<bool> authenticateApp() async {
    bool canAuthenticate = await _auth.canCheckBiometrics;
    if (!canAuthenticate) return false;

    bool authenticated = await _auth.authenticate(
      localizedReason: 'Authenticate to access your To-Do app',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );

    if (authenticated) {
      await _keyService.getOrCreateEncryptionKey();
    }

    return authenticated;
  }

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
