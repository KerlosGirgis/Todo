import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/core/ui/feedback_toast.dart';

void main() {
  /// Lets [duration] go by a frame at a time, as it does on a phone, for
  /// the toasts' animations: a single pump would draw only their first frame.
  Future<void> wait(WidgetTester tester,
      [Duration duration = const Duration(seconds: 1)]) async {
    const frame = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < duration; waited += frame) {
      await tester.pump(frame);
    }
  }

  /// A page under the toasts, as the app has them: laid out above its
  /// MaterialApp.
  Future<void> showApp(WidgetTester tester) => tester.pumpWidget(
        ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: false),
            home: const Scaffold(),
          ),
        ),
      );

  testWidgets("a deletion's Undo puts it back, and closes the toast",
      (tester) async {
    await showApp(tester);
    var undone = 0;
    FeedbackToast.deleted("Task moved to Trash", onUndo: () => undone++);
    await wait(tester);
    expect(find.text("Task moved to Trash"), findsOneWidget);

    await tester.tap(find.text("Undo"));
    expect(undone, 1);
    await wait(tester);
    expect(find.text("Task moved to Trash"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a newer deletion's toast takes the last one's place",
      (tester) async {
    await showApp(tester);
    var undone = <String>[];
    FeedbackToast.deleted("First", onUndo: () => undone.add("First"));
    await wait(tester);
    FeedbackToast.deleted("Second", onUndo: () => undone.add("Second"));
    await wait(tester);
    expect(find.text("First"), findsNothing);
    expect(find.text("Undo"), findsOneWidget);

    await tester.tap(find.text("Undo"));
    expect(undone, ["Second"]);
    await wait(tester);
  });

  testWidgets("closes by itself, leaving it deleted", (tester) async {
    await showApp(tester);
    var undone = 0;
    FeedbackToast.deleted("Note moved to Trash", onUndo: () => undone++);
    await wait(tester, const Duration(seconds: 7));
    expect(find.text("Note moved to Trash"), findsNothing);
    expect(undone, 0);
  });
}
