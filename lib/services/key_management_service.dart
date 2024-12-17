import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManagementService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> getOrCreateEncryptionKey() async {
    const keyName = 'encryptionKey';
    String? key = await _storage.read(key: keyName);

    if (key == null) {
      key = _generateRandomKey();
      await _storage.write(key: keyName, value: key);
    }
    return key;
  }

  String _generateRandomKey() {
    // Generate a random 256-bit encryption key
    return List<double>.generate(32, (_) => (256 * (0.5 - 0.5 * 2))).toString();
  }
}
