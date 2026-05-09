import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class LockService {
  final _storage = const FlutterSecureStorage();

  Future<void> enableLock() async {
    const lockKey = 'lockToken';
    final token = _generateToken();
    await _storage.write(key: lockKey, value: token);
  }

  Future<bool> isLockEnabled() async {
    const lockKey = 'lockToken';
    final token = await _storage.read(key: lockKey);
    return token != null;
  }

  Future<void> disableLock() async {
    const lockKey = 'lockToken';
    await _storage.delete(key: lockKey);
  }

  String _generateToken() {
    final data = utf8.encode(DateTime.now().toIso8601String());
    return sha256.convert(data).toString();
  }
}
