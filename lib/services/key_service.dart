import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The database's key, which SQLCipher encrypts it with: 32 random bytes as
/// hex, kept in the phone's secure storage as it is while the App Lock isn't
/// a password. While it is, the key is kept only locked with the password,
/// by [LockService], so that without it the database can't be read, even by
/// someone who can read the app's storage, as on a rooted phone.
class KeyService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _keyName = 'encryptionKey';

  /// The key as it's kept while the App Lock isn't a password, or null while
  /// it is, or before there's a database.
  Future<String?> unlockedKey() => _storage.read(key: _keyName);

  /// Keeps [key] as it is, for the database to open with straight away.
  Future<void> keepUnlocked(String key) =>
      _storage.write(key: _keyName, value: key);

  /// Stops keeping the key as it is, once the App Lock's password locks it.
  Future<void> forgetUnlocked() => _storage.delete(key: _keyName);

  /// A key for a new database.
  static String newKey() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256))
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
