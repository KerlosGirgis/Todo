import 'package:local_auth/local_auth.dart';

import '../models/app_lock.dart';
import 'key_service.dart';
import 'lock_service.dart';

class AuthenticationService {
  final LocalAuthentication _auth = LocalAuthentication();
  final KeyService _keyService = KeyService();
  final LockService _lockService = LockService();

  Future<bool> authenticate() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      if (!isAvailable) return false;

      return await _auth.authenticate(
        localizedReason: 'Please authenticate',
          biometricOnly: true,
      );
    } catch (e) {
      return false;
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
