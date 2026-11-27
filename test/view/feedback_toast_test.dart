import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/result.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/core/ui/feedback_toast.dart';

void main() {
  /// Lets [duration] go by a frame at a time, as it does on a phone, for
  /// the toasts' animations: a single pump would draw only their first frame.
  Future<void> wait(
    WidgetTester tester, [
    Duration duration = const Duration(seconds: 1),
  ]) async {
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

  testWidgets("a deletion's Undo puts it back, and closes the toast", (
    tester,
  ) async {
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

  testWidgets("a newer deletion's toast takes the last one's place", (
    tester,
  ) async {
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

  testWidgets("a deletion a view model says of shows as one, with its Undo", (
    tester,
  ) async {
    await showApp(tester);
    var undone = 0;
    FeedbackToast.show(
      Deleted(
        "Task moved to Trash",
        undo: () async {
          undone++;
          return const Success("Task Restored");
        },
      ),
    );
    await wait(tester);
    expect(find.text("Task moved to Trash"), findsOneWidget);
    expect(find.byIcon(Icons.delete_rounded), findsOneWidget);

    await tester.tap(find.text("Undo"));
    await wait(tester);
    expect(undone, 1);
    // Back in view, which says so: no toast of its own.
    expect(find.text("Task Restored"), findsNothing);
    expect(find.text("Task moved to Trash"), findsNothing);
  });

  testWidgets("closes by itself, leaving it deleted", (tester) async {
    await showApp(tester);
    var undone = 0;
    FeedbackToast.deleted("Note moved to Trash", onUndo: () => undone++);
    await wait(tester, const Duration(seconds: 7));
    expect(find.text("Note moved to Trash"), findsNothing);
    expect(undone, 0);
  });

  testWidgets("a result shows as it went, and nothing shows without one", (
    tester,
  ) async {
    await showApp(tester);
    FeedbackToast.show(null);
    await wait(tester);
    expect(find.byType(Text), findsNothing);

    FeedbackToast.show(const Failure("Couldn't save the task"));
    await wait(tester);
    expect(find.text("Couldn't save the task"), findsOneWidget);
    expect(find.text("Undo"), findsNothing);
    await wait(tester, const Duration(seconds: 4));
    expect(find.text("Couldn't save the task"), findsNothing);
  });

  testWidgets("a result that changed more than was asked comes with an Undo, "
      "which says how taking it back went", (tester) async {
    await showApp(tester);
    var undone = 0;
    FeedbackToast.show(
      Undoable(
        "Task done, with its 2 subtasks",
        undo: () async {
          undone++;
          return const Failure("Couldn't undo that");
        },
      ),
    );
    await wait(tester);
    expect(find.text("Task done, with its 2 subtasks"), findsOneWidget);

    await tester.tap(find.text("Undo"));
    await wait(tester);
    expect(undone, 1);
    expect(find.text("Task done, with its 2 subtasks"), findsNothing);
    expect(find.text("Couldn't undo that"), findsOneWidget);
    await wait(tester, const Duration(seconds: 4));
  });
}
