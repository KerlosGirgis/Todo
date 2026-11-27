import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/text_size.dart';
import 'package:todo/view/screens/profile/profile_page/widgets/text_size_sheet.dart';
import 'package:todo/view_model/user_view_model.dart';

import '../view_model/user_view_model_test.dart'
    show FakeDatabase, FakeDevice, FakeUserRepository, newLock;

void main() {
  /// Lets [duration] go by a frame at a time, as it does on a phone, for the
  /// animations in it, a toast's too.
  Future<void> wait(
    WidgetTester tester, [
    Duration duration = const Duration(seconds: 1),
  ]) async {
    const frame = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < duration; waited += frame) {
      await tester.pump(frame);
    }
  }

  testWidgets("a text size's sheet saves the size it's for, and no other", (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final user = UserViewModel(
      repository: FakeUserRepository(),
      lockService: newLock(),
      deviceService: FakeDevice(),
      databaseService: FakeDatabase(),
    );
    await user.get();
    for (final setting in TextSizeSetting.values) {
      await user.setTextSize(setting, 1.5);
    }
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: user,
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: false),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      showTextSizeSheet(context, TextSizeSetting.noteTitle),
                  child: const Text("Open"),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Open"));
    await wait(tester);
    expect(find.text("Note Title"), findsOneWidget);
    expect(find.text("150%"), findsOneWidget);

    await tester.tap(find.text("Reset"));
    await tester.pump();
    expect(find.text("100%"), findsOneWidget);
    await tester.tap(find.text("Apply"));
    await wait(tester);
    expect(find.text("Note Title"), findsNothing);
    expect(find.text("Text Size Changed"), findsOneWidget);
    expect(user.user.textSize(TextSizeSetting.noteTitle), 1);
    for (final setting in [
      TextSizeSetting.taskTitle,
      TextSizeSetting.taskDescription,
      TextSizeSetting.noteBody,
    ]) {
      expect(user.user.textSize(setting), 1.5);
    }
    // Till the toast has gone.
    await wait(tester, const Duration(seconds: 5));
  });
}
