import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:todo/core/result.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/avatar.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/repositories/user_repository.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/database_service.dart';
import 'package:todo/services/device_service.dart';
import 'package:todo/services/image_service.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/services/verse_service.dart';
import 'package:todo/view_model/auth_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';

/// The profile table, in memory.
class FakeUserRepository extends UserRepository {
  final rows = <UserProfile>[];
  var updates = 0;

  /// Whether adding the profile fails, or saving it does, as when the disk
  /// is full.
  bool failInserts = false;
  bool failUpdates = false;

  @override
  Future<void> insertUser(UserProfile user) async {
    if (failInserts) throw StateError("Disk full");
    rows.add(UserProfile.fromMap({...user.toMap(), 'id': 1}));
  }

  @override
  Future<List<UserProfile>> getUser() async => List.of(rows);

  @override
  Future<void> updateUser(UserProfile item) async {
    if (failUpdates) throw StateError("Disk full");
    updates++;
    rows[0] = item;
  }
}

/// A gallery whose photo the user picks is [picked], or none for backing
/// out. It keeps each photo deleted, with the avatar the saved profile had
/// as it went.
class FakeImages extends ImageService {
  FakeImages(this._profile);

  final FakeUserRepository _profile;
  String? picked;
  final deleted = <(String, Avatar)>[];

  /// Whether deleting a photo fails.
  bool failDeletes = false;

  @override
  Future<String?> pickProfilePicture() async => picked;

  @override
  Future<void> deletePhoto(String path) async {
    if (failDeletes) throw const FileSystemException("Busy");
    deleted.add((path, _profile.rows.single.avatar));
  }
}

class FakeDevice extends DeviceService {
  bool? hidden;

  @override
  Future<void> hideFromRecents(bool hidden) async => this.hidden = hidden;
}

/// A lock whose waits after wrong passwords go by a clock that stands still.
LockService newLock() =>
    LockService.withClock(() async => (boot: 1, sinceBoot: Duration.zero));

/// A lock that can't be read, as when the phone's secure storage fails.
class UnreadableLock extends LockService {
  UnreadableLock()
    : super.withClock(() async => (boot: 1, sinceBoot: Duration.zero));

  @override
  Future<AppLock> getLock() async => throw StateError("Can't read the lock");
}

/// The database's key, as the app made it.
const dbKey =
    "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff";

/// The database's key as it's kept while the App Lock isn't a password.
Future<String?> unlockedKey() =>
    const FlutterSecureStorage().read(key: 'encryptionKey');

class _NoDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The database, open with [dbKey].
class FakeDatabase implements DatabaseService {
  /// The key the app opened it with, which the App Lock's password unlocked,
  /// or null for the one kept as it is.
  String? openedWith;

  /// Whether it won't open, as when its key is gone.
  bool failToOpen = false;

  /// How many times the app has tried to open it.
  var opens = 0;

  @override
  String? get key => dbKey;

  @override
  Future<Database> openDb({String? key}) async {
    opens++;
    if (failToOpen) throw StateError("The database's key is missing");
    openedWith = key;
    return _NoDatabase();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A phone whose fingerprint always matches.
class PassingFingerprint extends AuthenticationService {
  PassingFingerprint() : super(lockService: newLock());

  @override
  Future<FingerprintCheck> checkFingerprint({
    String reason = 'Please authenticate',
  }) async => FingerprintCheck.passed;
}

class FakeVerses implements VerseService {
  @override
  Future<void> loadVerses() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeUserRepository repository;
  late FakeDevice device;
  late UserViewModel user;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'encryptionKey': dbKey});
    repository = FakeUserRepository();
    device = FakeDevice();
    user = UserViewModel(
      repository: repository,
      lockService: newLock(),
      deviceService: device,
      databaseService: FakeDatabase(),
    );
    await user.get();
    repository.updates = 0;
  });

  group('settings', () {
    test('are saved when they change, and only then', () async {
      await user.setDarkTheme(!user.user.darkTheme);
      await user.setAmoledTheme(true);
      await user.setAutoSave(false);
      await user.setStartPage(StartPage.notes);
      await user.setWordCount(true);
      await user.setShowVerse(false);
      await user.setAvatar(const BundledAvatar("004"));
      expect(repository.updates, 7);
      expect(repository.rows.single.toMap(), user.user.toMap());

      var notified = 0;
      user.addListener(() => notified++);
      await user.setAmoledTheme(true);
      await user.setAutoSave(false);
      await user.setStartPage(StartPage.notes);
      await user.setAvatar(const BundledAvatar("004"));
      expect(repository.updates, 7);
      expect(notified, 0);
    });

    test('the handwritten font is saved, and only when it changes', () async {
      await user.setCasualFont(true);
      expect(user.user.casualFont, isTrue);
      expect(repository.rows.single.casualFont, isTrue);
      await user.setCasualFont(true);
      expect(repository.updates, 1);
    });

    test('show up to five lines of a description', () async {
      await user.setDescLines(UserViewModel.maxDescLines);
      expect(user.user.descLines, 5);
      await user.setDescLines(6);
      expect(user.user.descLines, 5);
      await user.setDescLines(0);
      expect(user.user.descLines, 0);
    });

    test('take text sizes from a quarter to twice the size', () async {
      expect(
        await user.setNotesTextSize(UserViewModel.maxTextSize),
        isA<Success>(),
      );
      expect(
        await user.setTasksTitleSize(UserViewModel.minTextSize),
        isA<Success>(),
      );
      expect(await user.setTasksDescSize(2.125), isA<Failure>());
      expect(await user.setNotesTitleSize(0.125), isA<Failure>());
      expect(user.user.notesTextSize, 2);
      expect(user.user.tasksTitleSize, 0.25);
      expect(user.user.tasksDescSize, 1);
    });

    test("save a text size only when it changes", () async {
      expect(await user.setNotesTitleSize(1), isNull);
      expect(repository.updates, 0);
      expect(await user.setNotesTitleSize(1.5), isA<Success>());
      expect(repository.updates, 1);
    });
  });

  group('the tasks view', () {
    test("switched from the to-do page's menu isn't saved", () async {
      var notified = 0;
      user.addListener(() => notified++);
      user.showTasksAs(TasksView.map);
      expect(user.shownTasksView, TasksView.map);
      expect(notified, 1);
      user.showTasksAs(TasksView.map);
      expect(notified, 1);
      expect(user.user.tasksView, TasksView.list);
      expect(repository.updates, 0);

      // The app opens with the saved one again.
      final reopened = UserViewModel(
        repository: repository,
        lockService: newLock(),
        deviceService: device,
        databaseService: FakeDatabase(),
      );
      await reopened.get();
      expect(reopened.shownTasksView, TasksView.list);
    });

    test(
      'picked in the settings is saved, and shows over the menu\'s',
      () async {
        user.showTasksAs(TasksView.map);
        await user.setTasksView(TasksView.map);
        expect(user.user.tasksView, TasksView.map);
        expect(repository.rows.single.tasksView, TasksView.map);

        user.showTasksAs(TasksView.list);
        await user.setTasksView(TasksView.list);
        expect(user.user.tasksView, TasksView.list);
        expect(user.shownTasksView, TasksView.list);
        expect(repository.updates, 2);

        // The saved view again, though it's unchanged.
        user.showTasksAs(TasksView.map);
        var notified = 0;
        user.addListener(() => notified++);
        await user.setTasksView(TasksView.list);
        expect(user.shownTasksView, TasksView.list);
        expect(notified, 1);
        expect(repository.updates, 2);

        // Nothing to change.
        await user.setTasksView(TasksView.list);
        expect(notified, 1);
      },
    );
  });

  test(
    "says why the profile couldn't be made, rather than half making it",
    () async {
      final fresh = UserViewModel(
        repository: FakeUserRepository()..failInserts = true,
        lockService: newLock(),
        deviceService: device,
        databaseService: FakeDatabase(),
      );
      await expectLater(
        fresh.get(),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', "Disk full"),
        ),
      );
    },
  );

  group('a photo of their own', () {
    const first = PhotoAvatar("/data/app_flutter/first.jpg");
    const second = PhotoAvatar("/data/app_flutter/second.jpg");
    late FakeImages images;
    late UserViewModel withPhotos;

    setUp(() async {
      images = FakeImages(repository);
      withPhotos = UserViewModel(
        repository: repository,
        imageService: images,
        lockService: newLock(),
        deviceService: device,
        databaseService: FakeDatabase(),
      );
      await withPhotos.get();
      images.picked = first.path;
      await withPhotos.pickPhoto();
    });

    test("takes the place of the one before, which is deleted once the "
        "profile has the new one", () async {
      expect(withPhotos.user.avatar, first);
      // The bundled one it took the place of is no file of its own.
      expect(images.deleted, isEmpty);

      images.picked = second.path;
      await withPhotos.pickPhoto();
      expect(repository.rows.single.avatar, second);
      expect(images.deleted, [(first.path, second)]);
    });

    test("stays when the user backs out of picking another", () async {
      images.picked = null;
      await withPhotos.pickPhoto();
      expect(repository.rows.single.avatar, first);
      expect(images.deleted, isEmpty);
    });

    test("is deleted once a bundled avatar takes its place", () async {
      await withPhotos.setAvatar(const BundledAvatar("004"));
      expect(images.deleted, [(first.path, const BundledAvatar("004"))]);
    });

    test("stays when the profile can't be saved with another", () async {
      repository.failUpdates = true;
      images.picked = second.path;
      await expectLater(withPhotos.pickPhoto(), throwsA(isA<StateError>()));
      expect(repository.rows.single.avatar, first);
      expect(images.deleted, isEmpty);
    });

    test("that can't be deleted is only left behind", () async {
      images.failDeletes = true;
      await withPhotos.setAvatar(const BundledAvatar("004"));
      expect(repository.rows.single.avatar, const BundledAvatar("004"));
    });
  });

  group('rename', () {
    test('saves the name without the spaces around it', () async {
      expect(await user.rename("  Kerlos "), isA<Info>());
      expect(user.user.name, "Kerlos");
    });

    test("won't take an empty name", () async {
      expect(
        (await user.rename("   ") as Failure).message,
        "Name can't be empty",
      );
      expect(repository.updates, 0);
    });

    test('counts characters as the name field does', () async {
      expect(await user.rename("a" * UserViewModel.maxNameLength), isA<Info>());
      expect(await user.rename("a" * 21), isA<Failure>());
      // One character to the field, though seven code points.
      expect(await user.rename("👨‍👩‍👧‍👦" * 20), isA<Info>());
    });
  });

  group('changeAppLock', () {
    Future<String?> refuse() async => fail("Asked for the current password");
    Future<String?> newPassword({required int minLength}) async {
      expect(minLength, UserViewModel.minPasswordLength);
      return "1234";
    }

    test('locks with a new password, without asking for one first', () async {
      final changes = <AppLock>[];
      final subscription = newLock().changes.listen(changes.add);
      final result = await user.changeAppLock(
        AppLock.password,
        askForPassword: refuse,
        askForNewPassword: newPassword,
      );
      expect((result as Success).message, "Password Lock Enabled");
      expect(user.appLock, AppLock.password);
      expect(await newLock().getLock(), AppLock.password);
      expect(await unlockedKey(), isNull);
      expect(device.hidden, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(changes, [AppLock.password]);
      await subscription.cancel();
    });

    group('with a password lock', () {
      setUp(() async {
        await user.changeAppLock(
          AppLock.password,
          askForPassword: refuse,
          askForNewPassword: newPassword,
        );
      });

      test(
        'asks for the password, and does nothing if it is cancelled',
        () async {
          var asked = 0;
          final result = await user.changeAppLock(
            AppLock.off,
            askForPassword: () async {
              asked++;
              return null;
            },
            askForNewPassword: newPassword,
          );
          expect(result, isNull);
          expect(asked, 1);
          expect(user.appLock, AppLock.password);
        },
      );

      test('turns off with the password', () async {
        final result = await user.changeAppLock(
          AppLock.off,
          askForPassword: () async => "1234",
          askForNewPassword: newPassword,
        );
        expect((result as Info).message, "Lock Disabled");
        expect(user.appLock, AppLock.off);
        expect(await unlockedKey(), dbKey);
        expect(device.hidden, isFalse);
      });

      test('keeps the key as it is again for the fingerprint', () async {
        final fingerprint = UserViewModel(
          repository: repository,
          lockService: newLock(),
          authService: PassingFingerprint(),
          deviceService: device,
          databaseService: FakeDatabase(),
        );
        await fingerprint.loadAppLock();
        final result = await fingerprint.changeAppLock(
          AppLock.fingerprint,
          askForPassword: () async => "1234",
          askForNewPassword: newPassword,
        );
        expect((result as Success).message, "Fingerprint Lock Enabled");
        expect(await newLock().getLock(), AppLock.fingerprint);
        expect(await unlockedKey(), dbKey);
      });

      test("doesn't change for a wrong password", () async {
        final result = await user.changeAppLock(
          AppLock.password,
          askForPassword: () async => "0000",
          askForNewPassword: newPassword,
        );
        expect((result as Failure).message, "Authentication failed");
      });

      test('changes the password', () async {
        final result = await user.changeAppLock(
          AppLock.password,
          askForPassword: () async => "1234",
          askForNewPassword: ({required minLength}) async => "4321",
        );
        expect((result as Success).message, "Password Changed");
        expect((await newLock().checkPassword("4321")).key, dbKey);
        expect((await newLock().checkPassword("1234")).matched, isFalse);
      });

      test("won't take a new password that's too short", () async {
        final result = await user.changeAppLock(
          AppLock.password,
          askForPassword: () async => "1234",
          askForNewPassword: ({required minLength}) async => "12",
        );
        expect((result as Failure).message, "Use at least 4 characters");
      });
    });
  });

  group('the App Lock', () {
    test('is what the lock page asks for', () async {
      await user.changeAppLock(
        AppLock.password,
        askForPassword: () async => null,
        askForNewPassword: ({required minLength}) async => "1234",
      );
      final fresh = UserViewModel(
        repository: repository,
        lockService: newLock(),
        deviceService: device,
        databaseService: FakeDatabase(),
      );
      final auth = AuthViewModel(fresh, lockService: newLock());
      expect(auth.lock, AppLock.off);
      await auth.initializeApp();
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.lock, AppLock.password);
    });

    test('opens the database with the key only its password unlocks', () async {
      await user.changeAppLock(
        AppLock.password,
        askForPassword: () async => null,
        askForNewPassword: ({required minLength}) async => "1234",
      );
      final database = FakeDatabase();
      final auth = AuthViewModel(
        UserViewModel(
          repository: repository,
          lockService: newLock(),
          deviceService: device,
          databaseService: database,
        ),
        lockService: newLock(),
        databaseService: database,
        verseService: FakeVerses(),
      );
      await auth.initializeApp();
      expect(await auth.unlock("0000"), isA<Failure>());
      expect(auth.status, AuthStatus.unauthenticated);
      expect(await auth.unlock("1234"), isA<Success>());
      expect(auth.status, AuthStatus.authenticated);
      expect(database.openedWith, dbKey);
    });

    test(
      "says so when the database won't open, and opens it on a try after",
      () async {
        final database = FakeDatabase()..failToOpen = true;
        final auth = AuthViewModel(
          UserViewModel(
            repository: repository,
            lockService: newLock(),
            deviceService: device,
            databaseService: database,
          ),
          lockService: newLock(),
          databaseService: database,
          verseService: FakeVerses(),
        );
        await auth.initializeApp();
        expect(auth.status, AuthStatus.failed);
        expect(auth.opened, isFalse);

        database.failToOpen = false;
        await auth.retryAuthentication();
        expect(auth.status, AuthStatus.authenticated);
        expect(auth.opened, isTrue);
        expect(database.opens, 2);
      },
    );

    test(
      "has what the pages show read in once it opens, and only the once",
      () async {
        final database = FakeDatabase()..failToOpen = true;
        var reads = 0;
        final auth = AuthViewModel(
          UserViewModel(
            repository: repository,
            lockService: newLock(),
            deviceService: device,
            databaseService: database,
          ),
          lockService: newLock(),
          databaseService: database,
          verseService: FakeVerses(),
          onOpened: () async => reads++,
        );
        await auth.initializeApp();
        expect(reads, 0);

        database.failToOpen = false;
        await auth.retryAuthentication();
        expect(reads, 1);

        // Locked again and let back in, it's open already.
        await auth.initializeApp();
        expect(auth.status, AuthStatus.authenticated);
        expect(reads, 1);
      },
    );

    test(
      "opens all the same when what the pages show can't be read in",
      () async {
        final auth = AuthViewModel(
          UserViewModel(
            repository: repository,
            lockService: newLock(),
            deviceService: device,
            databaseService: FakeDatabase(),
          ),
          lockService: newLock(),
          databaseService: FakeDatabase(),
          verseService: FakeVerses(),
          onOpened: () => throw StateError("Can't read the tasks"),
        );
        await auth.initializeApp();
        expect(auth.status, AuthStatus.authenticated);
        expect(auth.opened, isTrue);
      },
    );

    test(
      "opens on the start page the profile had as it opened, and stays on it "
      "while it runs: one picked since is for the next start",
      () async {
        await user.setStartPage(StartPage.notes);
        final opening = UserViewModel(
          repository: repository,
          lockService: newLock(),
          deviceService: device,
          databaseService: FakeDatabase(),
        );
        final auth = AuthViewModel(
          opening,
          lockService: newLock(),
          databaseService: FakeDatabase(),
          verseService: FakeVerses(),
        );
        await auth.initializeApp();
        expect(auth.openedOn, StartPage.notes);

        await opening.setStartPage(StartPage.tasks);
        expect(auth.openedOn, StartPage.notes);

        // Locked again and let back in, it's open already, on that page.
        await auth.initializeApp();
        expect(auth.openedOn, StartPage.notes);

        // The next start opens on the one picked.
        final next = AuthViewModel(
          UserViewModel(
            repository: repository,
            lockService: newLock(),
            deviceService: device,
            databaseService: FakeDatabase(),
          ),
          lockService: newLock(),
          databaseService: FakeDatabase(),
          verseService: FakeVerses(),
        );
        await next.initializeApp();
        expect(next.openedOn, StartPage.tasks);
      },
    );

    test("stays at the lock page when the right password's database won't "
        "open, for another try, which isn't a wrong password", () async {
      await user.changeAppLock(
        AppLock.password,
        askForPassword: () async => null,
        askForNewPassword: ({required minLength}) async => "1234",
      );
      final database = FakeDatabase()..failToOpen = true;
      final auth = AuthViewModel(
        UserViewModel(
          repository: repository,
          lockService: newLock(),
          deviceService: device,
          databaseService: database,
        ),
        lockService: newLock(),
        databaseService: database,
        verseService: FakeVerses(),
      );
      await auth.initializeApp();
      final result = await auth.unlock("1234");
      expect(
        (result as Failure).message,
        "Couldn't open your tasks and notes. Try again.",
      );
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.opened, isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'lockFailures'),
        isNull,
      );

      database.failToOpen = false;
      expect(await auth.unlock("1234"), isA<Success>());
      expect(auth.status, AuthStatus.authenticated);
      expect(database.openedWith, dbKey);
    });

    test(
      'asks for its password only when the app is locked with one',
      () async {
        final auth = AuthenticationService(lockService: newLock());
        var asked = 0;
        Future<String?> ask() async {
          asked++;
          return "1234";
        }

        expect(await auth.passAppLock(ask), (passed: true, password: null));
        expect(asked, 0);
        await user.changeAppLock(
          AppLock.password,
          askForPassword: () async => null,
          askForNewPassword: ({required minLength}) async => "1234",
        );
        expect(await auth.passAppLock(ask), (passed: true, password: "1234"));
        expect(asked, 1);
        expect(await auth.passAppLock(() async => null), isNull);
        expect(await auth.passAppLock(() async => "0000"), (
          passed: false,
          password: "0000",
        ));
      },
    );

    test("doesn't let the user through when it can't be read", () async {
      final auth = AuthenticationService(lockService: UnreadableLock());
      var asked = 0;
      final pass = await auth.passAppLock(() async {
        asked++;
        return "1234";
      });
      expect(pass, (passed: false, password: null));
      expect(asked, 0);
    });
  });
}
