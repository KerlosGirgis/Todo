import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/view/screens/profile/lock_page/screen/lock_page.dart';
import 'package:todo/view/widgets/app_gate.dart';
import 'package:todo/view_model/auth_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';

import '../view_model/user_view_model_test.dart'
    show FakeDatabase, FakeDevice, FakeUserRepository, FakeVerses, newLock;

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
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(
        theme: AppTheme.getTheme(isDarkMode: false),
        home: Consumer<AuthViewModel>(
          builder: (context, auth, _) => AppGate(auth: auth, user: user),
        ),
      ),
    ));
  }

  testWidgets(
      "a database that won't open says so, rather than opening for good, "
      "and Try Again tries again", (tester) async {
    await openApp(tester, newLock());
    expect(auth.status, AuthStatus.failed);
    expect(find.text("Couldn't Open Your Data"), findsOneWidget);
    expect(database.opens, 1);

    await tester.tap(find.text("Try Again"));
    await tester.pump();
    expect(database.opens, 2);
    expect(find.text("Couldn't Open Your Data"), findsOneWidget);
  });

  testWidgets(
      "the lock page says so when the right password's database won't open, "
      "and can be unlocked again", (tester) async {
    await openApp(tester, PasswordLock());
    expect(find.byType(LockPage), findsOneWidget);

    await tester.enterText(find.byType(TextField), "1234");
    await tester.pump();
    await tester.tap(find.text("Unlock"));
    await tester.pump();
    expect(find.text("Couldn't open your tasks and notes. Try again."),
        findsOneWidget);
    expect(find.byType(LockPage), findsOneWidget);
    expect(database.opens, 1);

    // Not left checking for good, with the button off.
    expect(find.text("Checking…"), findsNothing);
    await tester.enterText(find.byType(TextField), "1234");
    await tester.pump();
    await tester.tap(find.text("Unlock"));
    await tester.pump();
    expect(database.opens, 2);
  });
}
