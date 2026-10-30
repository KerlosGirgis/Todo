import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/services/lock_service.dart';

/// The database's key, as the app made it.
const dbKey =
    "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff";

const storage = FlutterSecureStorage();

/// The database's key as it's kept while the App Lock isn't a password.
Future<String?> unlockedKey() => storage.read(key: 'encryptionKey');

/// A lock whose waits after wrong passwords go by a clock that stands still.
LockService newLock() =>
    LockService.withClock(() async => (boot: 1, sinceBoot: Duration.zero));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({
        'encryptionKey': dbKey,
      }));

  test("a password lock keeps the database's key only locked with it",
      () async {
    await newLock().enableLock(password: "1234", key: dbKey);
    expect(await newLock().getLock(), AppLock.password);
    expect(await unlockedKey(), isNull);
    expect(await storage.read(key: 'lockPassword'), isNot(contains(dbKey)));

    final wrong = await newLock().checkPassword("0000");
    expect(wrong.matched, isFalse);
    expect(wrong.key, isNull);
    final right = await newLock().checkPassword("1234");
    expect(right.matched, isTrue);
    expect(right.key, dbKey);
  });

  test("a new password locks the key, which the old one no longer opens",
      () async {
    await newLock().enableLock(password: "1234", key: dbKey);
    await newLock().enableLock(password: "4321", key: dbKey);
    expect((await newLock().checkPassword("1234")).matched, isFalse);
    expect((await newLock().checkPassword("4321")).key, dbKey);
    expect(await unlockedKey(), isNull);
  });

  test("turning the lock off keeps the key as it is again", () async {
    await newLock().enableLock(password: "1234", key: dbKey);
    await newLock().disableLock(key: dbKey);
    expect(await newLock().getLock(), AppLock.off);
    expect(await unlockedKey(), dbKey);
    expect(await storage.read(key: 'lockPassword'), isNull);
  });

  test("the fingerprint lock keeps the key as it is", () async {
    await newLock().enableLock(password: "1234", key: dbKey);
    await newLock().enableLock(key: dbKey);
    expect(await newLock().getLock(), AppLock.fingerprint);
    expect(await unlockedKey(), dbKey);
    expect(await storage.read(key: 'lockPassword'), isNull);
  });

  test(
      "a copy of the key left by a change that didn't finish goes once the "
      "password unlocks it", () async {
    await newLock().enableLock(password: "1234", key: dbKey);
    // As turning the lock off does first, before the app was closed.
    await storage.write(key: 'encryptionKey', value: dbKey);
    expect((await newLock().checkPassword("1234")).key, dbKey);
    expect(await unlockedKey(), isNull);
  });

  /// Saves "1234" as passwords were saved before they locked the database's
  /// key: a hash, beside the key as it is.
  Future<String> saveOldPassword() async {
    final salt = List<int>.generate(16, (i) => i);
    final hash = pbkdf2(utf8.encode("1234"), salt, 10);
    final saved =
        "pbkdf2-sha256:10:${base64.encode(salt)}:${base64.encode(hash)}";
    await storage.write(key: 'lockToken', value: "token");
    await storage.write(key: 'lockPassword', value: saved);
    return saved;
  }

  test("a password saved before it locked the key locks it once it's right",
      () async {
    await saveOldPassword();

    expect((await newLock().checkPassword("0000")).matched, isFalse);
    expect(await unlockedKey(), dbKey);
    final right = await newLock().checkPassword("1234");
    expect(right.matched, isTrue);
    expect(right.key, dbKey);
    expect(await unlockedKey(), isNull);
    expect(await storage.read(key: 'lockPassword'), startsWith("lock-key:"));
    expect((await newLock().checkPassword("1234")).key, dbKey);
  });

  test(
      "a password saved before it locked the key still opens the app when "
      "the phone can't lock the key yet", () async {
    final saved = await saveOldPassword();
    final lock = LockService.withClock(
      () async => (boot: 1, sinceBoot: Duration.zero),
      keyFromPassword: (password, salt, iterations) async =>
          throw StateError("Keystore unavailable"),
    );
    final check = await lock.checkPassword("1234");
    expect(check.matched, isTrue);
    expect(check.key, dbKey);
    expect(await unlockedKey(), dbKey);
    expect(await storage.read(key: 'lockPassword'), saved);
  });

  test("a try that has to wait unlocks nothing, even with the password",
      () async {
    await newLock().enableLock(password: "1234", key: dbKey);
    for (var i = 0; i < 5; i++) {
      await newLock().checkPassword("0000");
    }
    final check = await newLock().checkPassword("1234");
    expect(check.matched, isFalse);
    expect(check.wait, const Duration(seconds: 30));
    expect(check.key, isNull);
  });
}
