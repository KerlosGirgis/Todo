import 'package:local_auth/local_auth.dart';

class AuthenticationService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      // Check if the device supports biometric authentication
      final isAvailable = await _auth.canCheckBiometrics;
      if (!isAvailable) return false;

      // Attempt biometric authentication
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print('Error during authentication: $e');
      return false;
    }
  }
}
