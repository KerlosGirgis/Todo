import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'key_service.dart';
import 'lock_service.dart';

class AuthenticationService {
  final LocalAuthentication _auth = LocalAuthentication();
  final KeyService _keyService = KeyService();

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

  Future<bool> initializeApp() async {
    final LockService lockManager = LockService();

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
