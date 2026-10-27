import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/result.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/avatar.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/repositories/user_repository.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/device_service.dart';
import 'package:todo/services/home_widget_service.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/view_model/auth_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';

/// The profile table, in memory.
class FakeUserRepository extends UserRepository {
  final rows = <UserProfile>[];
  var updates = 0;

  @override
  Future<void> insertUser(UserProfile user) async =>
      rows.add(UserProfile.fromMap({...user.toMap(), 'id': 1}));

  @override
  Future<List<UserProfile>> getUser() async => List.of(rows);

  @override
  Future<void> updateUser(UserProfile item) async {
    updates++;
    rows[0] = item;
  }
}

class FakeHomeWidget extends HomeWidgetService {
  bool? casualFont;

  @override
  Future<void> setCasualFont(bool useCasual) async => casualFont = useCasual;

  @override
  Future<void> setTextSize(double size) async {}
}

class FakeDevice extends DeviceService {
  bool? hidden;

  @override
  Future<void> hideFromRecents(bool hidden) async => this.hidden = hidden;
}

/// A lock whose waits after wrong passwords go by a clock that stands still.
LockService newLock() =>
    LockService.withClock(() async => (boot: 1, sinceBoot: Duration.zero));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeUserRepository repository;
  late FakeHomeWidget homeWidget;
  late FakeDevice device;
  late UserViewModel user;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    repository = FakeUserRepository();
    homeWidget = FakeHomeWidget();
    device = FakeDevice();
    user = UserViewModel(
      repository: repository,
      homeWidgetService: homeWidget,
      lockService: newLock(),
      deviceService: device,
    );
    await user.get();
    repository.updates = 0;
  });

  group('settings', () {
    test('are saved when they change, and only then', () async {
      await user.setDarkTheme(!user.user.darkTheme);
      await user.setAutoSave(false);
      await user.setStartPage(StartPage.notes);
      await user.setWordCount(true);
      await user.setShowVerse(false);
      await user.setAvatar(const BundledAvatar("004"));
      expect(repository.updates, 6);
      expect(repository.rows.single.toMap(), user.user.toMap());

      var notified = 0;
      user.addListener(() => notified++);
      await user.setAutoSave(false);
      await user.setStartPage(StartPage.notes);
      await user.setAvatar(const BundledAvatar("004"));
      expect(repository.updates, 6);
      expect(notified, 0);
    });

    test('the handwritten font goes to the widget too', () async {
      await user.setCasualFont(true);
      expect(user.user.casualFont, isTrue);
      expect(homeWidget.casualFont, isTrue);
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
      expect(await user.setNotesTextSize(UserViewModel.maxTextSize),
          isA<Success>());
      expect(await user.setTasksTitleSize(UserViewModel.minTextSize),
          isA<Success>());
      expect(await user.setTasksDescSize(2.125), isA<Failure>());
      expect(await user.setNotesTitleSize(0.125), isA<Failure>());
      expect(user.user.notesTextSize, 2);
      expect(user.user.tasksTitleSize, 0.25);
      expect(user.user.tasksDescSize, 1);
    });
  });

  group('rename', () {
    test('saves the name without the spaces around it', () async {
      expect(await user.rename("  Kerlos "), isA<Info>());
      expect(user.user.name, "Kerlos");
    });

    test("won't take an empty name", () async {
      expect((await user.rename("   ") as Failure).message,
          "Name can't be empty");
      expect(repository.updates, 0);
    });

    test('counts characters as the name field does', () async {
      expect(await user.rename("a" * UserViewModel.maxNameLength),
          isA<Info>());
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
      final result = await user.changeAppLock(AppLock.password,
          askForPassword: refuse, askForNewPassword: newPassword);
      expect((result as Success).message, "Password Lock Enabled");
      expect(user.appLock, AppLock.password);
      expect(await newLock().getLock(), AppLock.password);
      expect(device.hidden, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(changes, [AppLock.password]);
      await subscription.cancel();
    });

    group('with a password lock', () {
      setUp(() async {
        await user.changeAppLock(AppLock.password,
            askForPassword: refuse, askForNewPassword: newPassword);
      });

      test('asks for the password, and does nothing if it is cancelled',
          () async {
        var asked = 0;
        final result = await user.changeAppLock(AppLock.off,
            askForPassword: () async {
              asked++;
              return null;
            },
            askForNewPassword: newPassword);
        expect(result, isNull);
        expect(asked, 1);
        expect(user.appLock, AppLock.password);
      });

      test('turns off with the password', () async {
        final result = await user.changeAppLock(AppLock.off,
            askForPassword: () async => "1234", askForNewPassword: newPassword);
        expect((result as Info).message, "Lock Disabled");
        expect(user.appLock, AppLock.off);
        expect(device.hidden, isFalse);
      });

      test("doesn't change for a wrong password", () async {
        final result = await user.changeAppLock(AppLock.password,
            askForPassword: () async => "0000",
            askForNewPassword: newPassword);
        expect((result as Failure).message, "Authentication Failed");
      });

      test('changes the password', () async {
        final result = await user.changeAppLock(AppLock.password,
            askForPassword: () async => "1234",
            askForNewPassword: ({required minLength}) async => "4321");
        expect((result as Success).message, "Password Changed");
        expect((await newLock().checkPassword("4321")).matched, isTrue);
      });

      test("won't take a new password that's too short", () async {
        final result = await user.changeAppLock(AppLock.password,
            askForPassword: () async => "1234",
            askForNewPassword: ({required minLength}) async => "12");
        expect((result as Failure).message, "Use at least 4 characters");
      });
    });
  });

  group('the App Lock', () {
    test('is what the lock page asks for', () async {
      await user.changeAppLock(AppLock.password,
          askForPassword: () async => null,
          askForNewPassword: ({required minLength}) async => "1234");
      final fresh = UserViewModel(
        repository: repository,
        homeWidgetService: homeWidget,
        lockService: newLock(),
        deviceService: device,
      );
      final auth = AuthViewModel(fresh, lockService: newLock());
      expect(auth.lock, AppLock.off);
      await auth.initializeApp();
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.lock, AppLock.password);
    });

    test('asks for its password only when the app is locked with one',
        () async {
      final auth = AuthenticationService();
      var asked = 0;
      Future<String?> ask() async {
        asked++;
        return "1234";
      }

      expect(await auth.passAppLock(ask), (passed: true, password: null));
      expect(asked, 0);
      await user.changeAppLock(AppLock.password,
          askForPassword: () async => null,
          askForNewPassword: ({required minLength}) async => "1234");
      expect(await auth.passAppLock(ask), (passed: true, password: "1234"));
      expect(asked, 1);
      expect(await auth.passAppLock(() async => null), isNull);
      expect(await auth.passAppLock(() async => "0000"),
          (passed: false, password: "0000"));
    });
  });
}
