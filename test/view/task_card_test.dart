import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/daily_progress.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/task_card.dart';

void main() {
  Future<void> showCard(WidgetTester tester, TodoItem task) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: false),
          home: Scaffold(
            body: TaskCard(
              task: task,
              titleScale: 1,
              descriptionScale: 1,
              descriptionLines: 2,
            ),
          ),
        ),
      );

  /// The card's label ending in [text]: the week's, which is the card's
  /// last part, as a card reads out as one.
  Finder cardEndingIn(String text) =>
      find.bySemanticsLabel(RegExp("${RegExp.escape(text)}\$"));

  DateTime daysAgo(int days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - days);
  }

  final stretch = TodoItem(
    uuid: "u",
    title: "Stretch",
    time: const ClockTime(7, 0),
    reminder: Reminder.daily,
    progress:
        DailyProgress(since: daysAgo(3), doneDays: [daysAgo(2), daysAgo(1)]),
  );

  testWidgets("a daily task's card shows its week and its streak",
      (tester) async {
    await showCard(tester, stretch);
    expect(find.text("2-day streak"), findsOneWidget);
    expect(cardEndingIn("Last 7 days: 2 done, 1 missed, today still to do"),
        findsOneWidget);
  });

  testWidgets("checking it off counts today, as the card has it",
      (tester) async {
    await showCard(tester, stretch.copyWith(done: true));
    await tester.pumpAndSettle();
    expect(find.text("3-day streak"), findsOneWidget);
    expect(cardEndingIn("Last 7 days: 3 done, 1 missed"), findsOneWidget);
  });

  testWidgets("other tasks' cards show neither", (tester) async {
    await showCard(tester,
        TodoItem(uuid: "u", title: "Call", time: const ClockTime(9, 0)));
    expect(find.textContaining("streak"), findsNothing);
    expect(find.bySemanticsLabel(RegExp("Last 7 days")), findsNothing);
  });
}
