import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/core/result.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/view/widgets/password_dialogs.dart';
import 'package:todo/view_model/user_view_model.dart';

import '../view_model/backup_flow_test.dart' show noPassword;
import '../view_model/user_view_model_test.dart'
    show CountingLock, FakeDatabase, FakeDevice, FakeUserRepository, dbKey;

void main() {
  /// A page with a button that runs [onPressed] with the page's context,
  /// and no view models over it at all.
  Widget page(Future<void> Function(BuildContext context) onPressed) =>
      MaterialApp(
        theme: AppTheme.getTheme(isDarkMode: false),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => onPressed(context),
              child: const Text("Ask"),
            ),
          ),
        ),
      );

  /// Types [password] into the dialog and presses Continue.
  Future<void> enter(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField), password);
    await tester.pump();
    await tester.tap(find.text("Continue"));
    await tester.pumpAndSettle();
  }

  testWidgets("the App Lock's password is tried with the check it's given, "
      "which says why one won't do, until one does", (tester) async {
    final tried = <String>[];
    String? given;
    await tester.pumpWidget(
      page((context) async {
        given = await passwordPrompt(context, subtitle: "To test it.")((
          password,
        ) async {
          tried.add(password);
          return password == "1234"
              ? const Success("Unlocked")
              : const Failure("Wrong password");
        });
      }),
    );
    await tester.tap(find.text("Ask"));
    await tester.pumpAndSettle();
    expect(find.text("To test it."), findsOneWidget);

    await enter(tester, "0000");
    expect(find.text("Wrong password"), findsOneWidget);
    expect(given, isNull);

    await enter(tester, "1234");
    expect(tried, ["0000", "1234"]);
    expect(given, "1234");
    expect(find.text("Enter Password"), findsNothing);
  });

  testWidgets("turning the App Lock off checks the password typed the once", (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'encryptionKey': dbKey});
    final lock = CountingLock();
    final user = UserViewModel(
      repository: FakeUserRepository(),
      lockService: lock,
      deviceService: FakeDevice(),
      databaseService: FakeDatabase(),
    );
    await user.changeAppLock(
      AppLock.password,
      askForPassword: noPassword,
      askForNewPassword: ({required minLength}) async => "1234",
    );
    lock.checks = 0;
    Result? result;
    await tester.pumpWidget(
      page((context) async {
        result = await user.changeAppLock(
          AppLock.off,
          askForPassword: passwordPrompt(context, subtitle: "To turn it off."),
          askForNewPassword: newPasswordPrompt(context),
        );
      }),
    );
    await tester.tap(find.text("Ask"));
    await tester.pumpAndSettle();
    await enter(tester, "1234");

    expect((result as Success).message, "Lock Disabled");
    expect(user.appLock, AppLock.off);
    expect(lock.checks, 1);
  });
}
