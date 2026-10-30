import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/note.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/repositories/notes_repository.dart';
import 'package:todo/repositories/user_repository.dart';
import 'package:todo/services/database_service.dart';
import 'package:todo/services/device_service.dart';
import 'package:todo/services/file_service.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/services/verse_service.dart';
import 'package:todo/view/screens/notes/notes_page/widgets/notes_overwrite_dialog.dart';
import 'package:todo/view/screens/profile/lock_page/screen/lock_page.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/form_dialog.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/tasks_overwrite_dialog.dart';
import 'package:todo/view/widgets/app_lock_guard.dart';
import 'package:todo/view_model/auth_view_model.dart';
import 'package:todo/view_model/notes_view_model.dart';
import 'package:todo/view_model/tasks_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';

/// An App Lock with the password "1234".
class FakeLock extends LockService {
  FakeLock() : super.withClock(() => throw StateError("No waits"));

  final _changes = StreamController<AppLock>.broadcast();

  @override
  Stream<AppLock> get changes => _changes.stream;

  @override
  Future<AppLock> getLock() async => AppLock.password;

  @override
  Future<PasswordCheck> checkPassword(String password) async =>
      (matched: password == "1234", wait: Duration.zero);
}

class _NoDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A database that opens, which nothing here reads.
class FakeDatabase implements DatabaseService {
  @override
  Future<Database> openDb() async => _NoDatabase();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeVerses implements VerseService {
  @override
  Future<void> loadVerses() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDevice extends DeviceService {
  @override
  Future<void> hideFromRecents(bool hidden) async {}

  @override
  Future<Duration> sinceBoot() async => Duration.zero;

  @override
  Future<void> moveToBack() async {}
}

/// The profile table, in memory.
class FakeUserRepository extends UserRepository {
  final rows = <UserProfile>[];

  @override
  Future<void> insertUser(UserProfile user) async => rows.add(user);

  @override
  Future<List<UserProfile>> getUser() async => List.of(rows);
}

/// No notes, so a restore asks for no note's lock first.
class FakeNotesRepository extends NotesRepository {
  @override
  Future<List<Note>> getNotes() async => [];
}

/// A file picker the user is still in until [picked] completes.
class SlowPicker extends FileService {
  final picked = Completer<Uint8List?>();

  @override
  Future<Uint8List?> pickJsonFile() => picked.future;
}

void main() {
  late AuthViewModel auth;
  late SlowPicker picker;
  late TasksViewModel tasks;
  late GlobalKey<NavigatorState> navigatorKey;

  /// Opens the app, unlocked with its password, on a page with a button for
  /// each restore dialog.
  Future<void> openApp(WidgetTester tester) async {
    final lock = FakeLock();
    final device = FakeDevice();
    auth = AuthViewModel(
      UserViewModel(
        repository: FakeUserRepository(),
        lockService: lock,
        deviceService: device,
      ),
      lockService: lock,
      databaseService: FakeDatabase(),
      deviceService: device,
      verseService: FakeVerses(),
    );
    picker = SlowPicker();
    tasks = TasksViewModel(fileService: picker, lockService: lock);
    addTearDown(tasks.dispose);
    final notes = NotesViewModel(
      repository: FakeNotesRepository(),
      fileService: picker,
      lockService: lock,
    );
    navigatorKey = GlobalKey<NavigatorState>();
    await auth.unlock("1234");

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: tasks),
        ChangeNotifierProvider.value(value: notes),
      ],
      child: AppLockGuard(
        navigatorKey: navigatorKey,
        child: ToastificationWrapper(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            theme: AppTheme.getTheme(isDarkMode: false),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => showFormDialog<void>(
                            context, const TasksOverwriteDialog()),
                        child: const Text("Restore tasks"),
                      ),
                      TextButton(
                        onPressed: () => showFormDialog<void>(
                            context, const NotesOverwriteDialog()),
                        child: const Text("Restore notes"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  /// The app locking again as it comes back after a minute away, as
  /// [AuthViewModel.appShown] has it do.
  Future<void> lockAgain(WidgetTester tester) async {
    unawaited(auth.initializeApp());
    await tester.pumpAndSettle();
  }

  /// Lets the toasts shown go, as each waits a few seconds to.
  Future<void> waitOutToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  for (final kind in ["tasks", "notes"]) {
    testWidgets(
        "a restore of $kind that ends under the lock page closes its own "
        "dialog, not the lock page", (tester) async {
      await openApp(tester);
      await tester.tap(find.text("Restore $kind"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Import"));
      await tester.pump();

      // The user is in the file picker for over a minute, so the app locks
      // again as it comes back, before the picker's answer gets to it.
      await lockAgain(tester);
      expect(find.byType(LockPage), findsOneWidget);
      picker.picked.complete(null);
      await tester.pumpAndSettle();

      expect(find.byType(LockPage), findsOneWidget);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(find.text("Restore Backup", skipOffstage: false), findsNothing);

      // And the lock still comes back after it's unlocked.
      await auth.unlock("1234");
      await tester.pumpAndSettle();
      expect(find.byType(LockPage), findsNothing);
      await lockAgain(tester);
      expect(find.byType(LockPage), findsOneWidget);
      await waitOutToasts(tester);
    });
  }

  testWidgets("only unlocking takes the lock page off", (tester) async {
    await openApp(tester);
    await lockAgain(tester);

    // A page under it closing the page on top, as the restore dialogs did.
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LockPage), findsOneWidget);

    // Or another page put in its place.
    navigatorKey.currentState!.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const Text("Elsewhere")));
    await tester.pumpAndSettle();
    expect(find.byType(LockPage), findsOneWidget);

    await auth.unlock("1234");
    await tester.pumpAndSettle();
    expect(find.byType(LockPage), findsNothing);
    expect(find.text("Elsewhere"), findsOneWidget);
  });
}
