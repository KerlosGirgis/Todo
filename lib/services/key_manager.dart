import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManager {
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
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256))
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
