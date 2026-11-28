import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/view/screens/profile/profile_page/widgets/edit_name_dialog.dart';
import 'package:todo/view/widgets/profile_button.dart';
import 'package:todo/view_model/user_view_model.dart';

import '../view_model/user_view_model_test.dart'
    show FakeDatabase, FakeDevice, FakeUserRepository, newLock;

void main() {
  late FakeUserRepository profile;
  late UserViewModel user;

  /// Lets [duration] go by a frame at a time, for the dialog's animation and
  /// the toasts'.
  Future<void> wait(
    WidgetTester tester, [
    Duration duration = const Duration(seconds: 1),
  ]) async {
    const frame = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < duration; waited += frame) {
      await tester.pump(frame);
    }
  }

  /// Opens the name dialog over a page of its own.
  Future<void> open(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    profile = FakeUserRepository();
    user = UserViewModel(
      repository: profile,
      lockService: newLock(),
      deviceService: FakeDevice(),
      databaseService: FakeDatabase(),
    );
    await user.get();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: user,
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: false),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showEditNameDialog(context),
                  child: const Text("Rename"),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Rename"));
    await wait(tester);
  }

  /// Whether the dialog's Save is on.
  bool saveIsOn(WidgetTester tester) =>
      tester
          .widget<ProfileButton>(find.widgetWithText(ProfileButton, "Save"))
          .onPressed !=
      null;

  testWidgets("a blank name can't be saved, from the button or the keyboard", (
    tester,
  ) async {
    await open(tester);
    expect(find.text("Edit Name"), findsOneWidget);
    expect(saveIsOn(tester), isTrue);

    await tester.enterText(find.byType(TextField), "   ");
    await tester.pump();
    expect(saveIsOn(tester), isFalse);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await wait(tester);
    // Nothing's said, as there's nothing wrong to say: the form says it.
    expect(find.text("Name can't be empty"), findsNothing);
    expect(find.text("Edit Name"), findsOneWidget);
    expect(profile.updates, 0);

    await tester.enterText(find.byType(TextField), "Kerlos");
    await tester.pump();
    expect(saveIsOn(tester), isTrue);
    await tester.tap(find.text("Save"));
    await wait(tester);
    expect(find.text("Edit Name"), findsNothing);
    expect(find.text("Name Updated"), findsOneWidget);
    expect(user.user.name, "Kerlos");
    // The toasts close.
    await wait(tester, const Duration(seconds: 4));
  });

  testWidgets("a name that can't be saved keeps the dialog open, with it in "
      "it", (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), "Kerlos");
    await tester.pump();
    profile.failUpdates = true;
    await tester.tap(find.text("Save"));
    await wait(tester);
    expect(find.text("Couldn't change the name"), findsOneWidget);
    expect(find.text("Edit Name"), findsOneWidget);
    expect(find.widgetWithText(TextField, "Kerlos"), findsOneWidget);
    await wait(tester, const Duration(seconds: 4));
  });
}
