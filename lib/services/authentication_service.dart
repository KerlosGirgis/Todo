import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'key_manager.dart';
import 'lock_manager.dart';

class AuthenticationService {
  final LocalAuthentication _auth = LocalAuthentication();
  final KeyManager _keyService = KeyManager();

  Future<bool> authenticate() async {
    try {
      // Check if the device supports biometric authentication
      final isAvailable = await _auth.canCheckBiometrics;
      if (!isAvailable) return false;

      // Attempt biometric authentication
      return await _auth.authenticate(
        localizedReason: 'Please authenticate',
        options: const AuthenticationOptions(
          biometricOnly: true,
        ),
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
      options: const AuthenticationOptions(
        biometricOnly: true,
        useErrorDialogs: true,
        stickyAuth: true,
      ),
    );

    if (authenticated) {
      // Trigger key fetching as a security layer.
      await _keyService.getOrCreateEncryptionKey();
    }

    return authenticated;
  }

  Future<bool> initializeApp() async {
    final AuthenticationService authService = AuthenticationService();
    final LockManager lockManager = LockManager();

    try {
      // Check if the lock is enabled.
      bool isLockEnabled = await lockManager.isLockEnabled();

      if (isLockEnabled) {
        // Perform authentication if lock is enabled.
        bool authenticated = await authService.authenticateApp();
        if (!authenticated) {
          return false; // Exit if authentication fails.
        }
      }

      return true; // Proceed to load the app.
    } catch (e) {
      // Log any initialization errors.
      if (kDebugMode) {
        print('Initialization Error: $e');
      }
      return false;
    }
  }

}
