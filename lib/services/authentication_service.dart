import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'key_manager.dart';
import 'lock_manager.dart';

class AuthenticationService {
  final LocalAuthentication _auth = LocalAuthentication();
  final KeyManager _keyService = KeyManager();

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
    );

    if (authenticated) {
      await _keyService.getOrCreateEncryptionKey();
    }

    return authenticated;
  }

  Future<bool> initializeApp() async {
    final LockManager lockManager = LockManager();

    try {
      bool isLockEnabled = await lockManager.isLockEnabled();

      if (isLockEnabled) {
        bool authenticated = await authenticateApp();
        if (!authenticated) {
          return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Initialization Error: $e');
      }
      return false;
    }
  }

}
