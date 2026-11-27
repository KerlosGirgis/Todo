import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/services/tour_service.dart';
import 'package:todo/view/screens/notes/notes_page/screen/notes_page.dart';
import 'package:todo/view/screens/profile/lock_page/screen/lock_page.dart';
import 'package:todo/view/screens/tasks/todo_page/screen/todo_page.dart';
import 'package:todo/view/widgets/app_gate.dart';
import 'package:todo/view/widgets/settings_group.dart';
import 'package:todo/view_model/auth_view_model.dart';
import 'package:todo/view_model/notes_view_model.dart';
import 'package:todo/view_model/tasks_view_model.dart';
import 'package:todo/view_model/tour_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:todo/view_model/widgets_view_model.dart';

import '../view_model/notes_view_model_test.dart'
    as notes_test
    show FakeAuth, FakeHomeWidget, FakeLock, FakeNotesRepository;
import '../view_model/tasks_view_model_test.dart'
    show FakeLock, FakeNotifications, FakeTasksRepository;
import '../view_model/user_view_model_test.dart'
    show FakeDatabase, FakeDevice, FakeUserRepository, FakeVerses, newLock;
import '../view_model/widgets_view_model_test.dart' show FakeWidgets;

/// An App Lock with the password "1234".
class PasswordLock extends LockService {
  PasswordLock() : super.withClock(() => throw StateError("No waits"));

  @override
  Future<AppLock> getLock() async => AppLock.password;

  @override
  Future<PasswordCheck> checkPassword(String password) async => (
    matched: password == "1234",
    wait: Duration.zero,
    key: password == "1234" ? "database key" : null,
  );
}

/// An App Lock with the fingerprint, which a test can't give, so the app
/// stays locked.
class FingerprintLock extends LockService {
  FingerprintLock() : super.withClock(() => throw StateError("No waits"));

  @override
  Future<AppLock> getLock() async => AppLock.fingerprint;
}

void main() {
  late FakeDatabase database;
  late AuthViewModel auth;
  late UserViewModel user;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    database = FakeDatabase()..failToOpen = true;
  });

  /// Starts the app locked with [lock], or with none, over a database that
  /// won't open, and shows what it opens on, as main.dart does.
  Future<void> openApp(WidgetTester tester, LockService lock) async {
    final device = FakeDevice();
    user = UserViewModel(
      repository: FakeUserRepository(),
      lockService: lock,
      deviceService: device,
      databaseService: database,
    );
    auth = AuthViewModel(
      user,
      lockService: lock,
      databaseService: database,
      deviceService: device,
      verseService: FakeVerses(),
    );
    await auth.initializeApp();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(
            create: (_) => WidgetsViewModel(service: FakeWidgets()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: false),
          home: const AppGate(),
        ),
      ),
    );
  }

  /// Lets [duration] go by a frame at a time, as it does on a phone, for
  /// the animations in it: a single pump would draw only their first frame.
  Future<void> wait(
    WidgetTester tester, [
    Duration duration = const Duration(seconds: 1),
  ]) async {
    const frame = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < duration; waited += frame) {
      await tester.pump(frame);
    }
  }

  /// Opens the app as main.dart puts it together, over a database that
  /// opens and with every tour seen, on the to-do page: its tasks and notes.
  Future<(TasksViewModel, NotesViewModel)> openWholeApp(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // Every tour seen, so none starts over the page.
    SharedPreferences.setMockInitialValues({
      for (final tour in PageTour.values) 'tour.${tour.name}': tour.version,
    });
    // A database that opens, this time.
    database.failToOpen = false;
    final lock = newLock();
    final device = FakeDevice();
    user = UserViewModel(
      repository: FakeUserRepository(),
      lockService: lock,
      deviceService: device,
      databaseService: database,
    );
    auth = AuthViewModel(
      user,
      lockService: lock,
      databaseService: database,
      deviceService: device,
      verseService: FakeVerses(),
    );
    final tasks = TasksViewModel(
      repository: FakeTasksRepository(),
      notificationService: FakeNotifications(),
      lockService: FakeLock(),
    );
    final notes = NotesViewModel(
      repository: notes_test.FakeNotesRepository(),
      authService: notes_test.FakeAuth(),
      lockService: notes_test.FakeLock(),
      homeWidgetService: notes_test.FakeHomeWidget(),
    );
    await auth.initializeApp();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          ChangeNotifierProvider.value(value: tasks),
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(
            create: (_) => WidgetsViewModel(service: FakeWidgets()),
          ),
          ChangeNotifierProvider(
            create: (_) => TourViewModel(service: TourService()),
          ),
        ],
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: false),
            home: const AppGate(),
          ),
        ),
      ),
    );
    await wait(tester, const Duration(seconds: 2));
    expect(find.byType(TodoPage), findsOneWidget);
    return (tasks, notes);
  }

  testWidgets(
    "a start page picked in the settings is for the next start: the page "
    "the app opened on stays under them",
    (tester) async {
      final (tasks, notes) = await openWholeApp(tester);

      // The settings, from the page's menu, where Notes becomes the start
      // page.
      await tester.tap(find.byTooltip("Menu"));
      await wait(tester);
      await tester.tap(find.byTooltip("Settings"));
      await wait(tester, const Duration(seconds: 2));
      final notesSegment = find.descendant(
        of: find.widgetWithText(SettingsTile, "Start Page"),
        matching: find.text("Notes"),
      );
      await tester.scrollUntilVisible(
        notesSegment,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await wait(tester);
      await tester.tap(notesSegment);
      await wait(tester);
      expect(user.user.startPage, StartPage.notes);

      // Back on the page they came from, as it was.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await wait(tester);
      expect(find.byType(TodoPage), findsOneWidget);
      expect(find.byType(NotesPage), findsNothing);

      await tester.pumpWidget(const SizedBox());
      tasks.dispose();
      notes.dispose();
    },
  );

  testWidgets(
    "each page's switch puts the other in its place: the notes slide in "
    "from the left, and the to-do page from the right",
    (tester) async {
      final (tasks, notes) = await openWholeApp(tester);

      await tester.tap(find.byTooltip("Notes"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getTopLeft(find.byType(NotesPage)).dx, lessThan(0));
      await wait(tester);
      expect(find.byType(NotesPage), findsOneWidget);
      expect(find.byType(TodoPage), findsNothing);

      await tester.tap(find.byTooltip("To-Do"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getTopLeft(find.byType(TodoPage)).dx, greaterThan(0));
      await wait(tester);
      expect(find.byType(TodoPage), findsOneWidget);
      expect(find.byType(NotesPage), findsNothing);

      await tester.pumpWidget(const SizedBox());
      tasks.dispose();
      notes.dispose();
    },
  );

  testWidgets(
    "a database that won't open says so, rather than opening for good, "
    "and Try Again tries again",
    (tester) async {
      await openApp(tester, newLock());
      expect(auth.status, AuthStatus.failed);
      expect(find.text("Couldn't Open Your Data"), findsOneWidget);
      expect(database.opens, 1);

      await tester.tap(find.text("Try Again"));
      await tester.pump();
      expect(database.opens, 2);
      expect(find.text("Couldn't Open Your Data"), findsOneWidget);
    },
  );

  testWidgets(
    "the lock page says so when the right password's database won't open, "
    "and can be unlocked again",
    (tester) async {
      await openApp(tester, PasswordLock());
      expect(find.byType(LockPage), findsOneWidget);

      await tester.enterText(find.byType(TextField), "1234");
      await tester.pump();
      await tester.tap(find.text("Unlock"));
      await tester.pump();
      expect(
        find.text("Couldn't open your tasks and notes. Try again."),
        findsOneWidget,
      );
      expect(find.byType(LockPage), findsOneWidget);
      expect(database.opens, 1);

      // Not left checking for good, with the button off.
      expect(find.text("Checking…"), findsNothing);
      await tester.enterText(find.byType(TextField), "1234");
      await tester.pump();
      await tester.tap(find.text("Unlock"));
      await tester.pump();
      expect(database.opens, 2);
    },
  );

  testWidgets(
    "the fingerprint's lock page names its button, for screen readers, and "
    "asks again with it",
    (tester) async {
      // A phone whose fingerprint doesn't match.
      const biometrics = MethodChannel('com.k.todo/biometrics');
      final messenger = tester.binding.defaultBinaryMessenger;
      var asked = 0;
      messenger.setMockMethodCallHandler(biometrics, (call) async {
        asked++;
        return 'failed';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(biometrics, null));
      await openApp(tester, FingerprintLock());
      expect(find.byType(LockPage), findsOneWidget);
      expect(asked, 1);
      expect(database.opens, 0);

      await tester.tap(find.byTooltip("Try Again"));
      await tester.pump();
      await tester.pump();
      expect(asked, 2);
      // Asked again, and still locked, with no fingerprint to give.
      expect(find.byTooltip("Try Again"), findsOneWidget);
      expect(auth.status, AuthStatus.unauthenticated);
    },
  );
}
