import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/core/utils/date_time_utils.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/recurrence.dart';
import 'package:todo/models/repeat_progress.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/view/widgets/profile_button.dart';

import 'todo_page_test.dart' show TodoPageHarness;

void main() {
  late TodoPageHarness page;

  setUp(() => page = TodoPageHarness());

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Whether the form's button with [label], Add or Save, is on.
  bool isOn(WidgetTester tester, String label) =>
      tester
          .widget<ProfileButton>(find.widgetWithText(ProfileButton, label))
          .onPressed !=
      null;

  /// Opens the form for a new task titled [title], with a time: the one it
  /// is now, which the time picker opens on.
  Future<void> startTask(WidgetTester tester, String title) async {
    await tester.tap(find.byTooltip("Add Task"));
    await page.wait(tester);
    await tester.enterText(find.widgetWithText(TextField, "Title"), title);
    await tester.tap(find.text("Time"));
    await page.wait(tester);
    await tester.tap(find.text("OK"));
    await page.wait(tester);
  }

  testWidgets("a task can repeat on days of the week, for a while", (
    tester,
  ) async {
    await page.open(tester, const []);
    await startTask(tester, "Gym");
    expect(find.text("Weekly"), findsNothing);

    await tester.tap(find.text("Repeat"));
    await page.wait(tester);
    // Daily, to start with, and for good.
    expect(find.textContaining("Every day at"), findsOneWidget);
    expect(find.text("Never"), findsOneWidget);
    await tester.tap(find.text("Weekly"));
    await page.wait(tester);
    await tester.tap(find.bySemanticsLabel("Monday"));
    await page.wait(tester);

    await tester.tap(find.text("Ends"));
    await page.wait(tester);
    expect(find.text("Repeat For"), findsOneWidget);
    await tester.tap(find.text("For a While"));
    await page.wait(tester);
    expect(find.text("4 weeks"), findsOneWidget);
    await tester.tap(find.byTooltip("More"));
    await page.wait(tester);
    expect(find.text("5 weeks"), findsOneWidget);
    await tester.tap(find.text("Done"));
    await page.wait(tester);
    final until = RepeatUnit.weeks.lastDay(today(), 5);
    expect(
      find.text(DateTimeUtils.friendlyDay(until, DateTime.now())),
      findsOneWidget,
    );

    await tester.tap(find.text("Add"));
    await page.wait(tester);
    final gym = page.task("Gym");
    expect(gym.reminder, Reminder.weekly);
    expect(gym.weekdays, contains(DateTime.monday));
    expect(gym.until, until);
    expect(
      find.text("Until ${DateTimeUtils.shortDay(until, DateTime.now())}"),
      findsOneWidget,
    );
    await page.close(tester);
  });

  testWidgets("a task can repeat on a day of every month", (tester) async {
    await page.open(tester, const []);
    await startTask(tester, "Rent");
    await tester.tap(find.text("Repeat"));
    await page.wait(tester);
    await tester.tap(find.text("Monthly"));
    await page.wait(tester);
    expect(find.text(DateTimeUtils.ordinal(today().day)), findsOneWidget);

    await tester.tap(find.text("Day of the Month"));
    await page.wait(tester);
    await tester.tap(find.text("1"));
    await page.wait(tester);
    expect(find.text("1st"), findsOneWidget);
    expect(find.textContaining("Every month on the 1st at"), findsOneWidget);

    await tester.tap(find.text("Add"));
    await page.wait(tester);
    final rent = page.task("Rent");
    expect(rent.reminder, Reminder.monthly);
    expect(rent.monthDay, 1);
    expect(find.text("Monthly"), findsOneWidget);
    await page.close(tester);
  });

  testWidgets("an ended task's end can be moved on", (tester) async {
    await page.open(tester, [
      TodoItem(
        uuid: "physio",
        title: "Physio",
        time: const ClockTime(19, 30),
        reminder: Reminder.daily,
        until: today().subtract(const Duration(days: 3)),
        progress: RepeatProgress(
          since: today().subtract(const Duration(days: 10)),
        ),
      ),
    ]);
    await tester.longPress(find.text("Physio"));
    await page.wait(tester);
    expect(find.textContaining("Ended "), findsOneWidget);
    await tester.tap(find.text("Ends"));
    await page.wait(tester);
    expect(find.text("It would stop before it comes round."), findsOneWidget);
    // The date picker opens on today, the first day it can stop on now.
    await tester.tap(find.text("Last Day"));
    await page.wait(tester);
    await tester.tap(find.text("OK"));
    await page.wait(tester);
    expect(find.text("It comes round just once, today."), findsOneWidget);
    await tester.tap(find.text("Done"));
    await page.wait(tester);
    await tester.tap(find.text("Save"));
    await page.wait(tester);
    expect(page.task("Physio").until, today());
    await page.close(tester);
  });

  testWidgets("a repeating task can be set back to repeat for good", (
    tester,
  ) async {
    await page.open(tester, [
      TodoItem(
        uuid: "pills",
        title: "Pills",
        time: const ClockTime(8, 0),
        reminder: Reminder.daily,
        until: today().add(const Duration(days: 40)),
      ),
    ]);
    await tester.longPress(find.text("Pills"));
    await page.wait(tester);
    expect(find.text("Never"), findsNothing);
    await tester.tap(find.byTooltip("Clear").last);
    await page.wait(tester);
    expect(find.text("Never"), findsOneWidget);
    await tester.tap(find.text("Save"));
    await page.wait(tester);
    expect(page.task("Pills").until, isNull);
    await page.close(tester);
  });

  testWidgets("a repeating task isn't saved without its time, which would "
      "stop it repeating", (tester) async {
    await page.open(tester, [
      TodoItem(
        uuid: "gym",
        title: "Gym",
        time: const ClockTime(18, 0),
        reminder: Reminder.weekly,
        weekdays: const {DateTime.monday},
      ),
    ]);
    await tester.longPress(find.text("Gym"));
    await page.wait(tester);
    expect(isOn(tester, "Save"), isTrue);

    // Its time is the only thing there is to clear.
    await tester.tap(find.byTooltip("Clear"));
    await page.wait(tester);
    expect(find.text("Needs a time"), findsOneWidget);
    expect(isOn(tester, "Save"), isFalse);
    await tester.tap(find.text("Save"));
    await page.wait(tester);
    expect(find.text("Edit Task"), findsOneWidget);
    expect(page.task("Gym").reminder, Reminder.weekly);
    expect(page.task("Gym").time, const ClockTime(18, 0));

    // With a time again, it's saved, still weekly.
    await tester.tap(find.text("Time"));
    await page.wait(tester);
    await tester.tap(find.text("OK"));
    await page.wait(tester);
    expect(isOn(tester, "Save"), isTrue);
    await tester.tap(find.text("Save"));
    await page.wait(tester);
    expect(find.text("Edit Task"), findsNothing);
    expect(page.task("Gym").reminder, Reminder.weekly);
    await page.close(tester);
  });

  testWidgets("a form left open into the next day says the task can't come "
      "round anymore, rather than closing with nothing saved", (tester) async {
    var time = DateTime(2026, 5, 13, 23, 59);
    await page.open(tester, const [], clock: () => time);
    await tester.tap(find.byTooltip("Add Task"));
    await page.wait(tester);
    await tester.enterText(find.widgetWithText(TextField, "Title"), "Stretch");
    // At the time it is now, 11:59 PM, which the picker opens on.
    await tester.tap(find.text("Time"));
    await page.wait(tester);
    await tester.tap(find.text("OK"));
    await page.wait(tester);
    await tester.tap(find.text("Repeat"));
    await page.wait(tester);
    // Every day, for a day: today only.
    await tester.tap(find.text("Ends"));
    await page.wait(tester);
    await tester.tap(find.text("For a While"));
    await page.wait(tester);
    await tester.tap(find.text("Days"));
    await page.wait(tester);
    await tester.tap(find.byTooltip("Fewer"));
    await page.wait(tester);
    await tester.tap(find.text("Done"));
    await page.wait(tester);
    expect(find.text("Every day at 11:59 PM until today"), findsOneWidget);
    expect(isOn(tester, "Add"), isTrue);

    // Midnight goes by before Add is tapped.
    time = DateTime(2026, 5, 14, 0, 1);
    await tester.tap(find.text("Add"));
    await page.wait(tester);
    expect(find.text("New Task"), findsOneWidget);
    expect(find.text("Ends before it comes round"), findsOneWidget);
    expect(isOn(tester, "Add"), isFalse);
    expect(page.tasks.items, isEmpty);
    await page.close(tester);
  });

  testWidgets("a task that can't be added keeps its form open, with what "
      "was written in it", (tester) async {
    await page.open(tester, const []);
    await tester.tap(find.byTooltip("Add Task"));
    await page.wait(tester);
    await tester.enterText(find.widgetWithText(TextField, "Title"), "Gym");
    // Add is on once there's a title.
    await page.wait(tester);
    page.rows.failWrites = true;
    await tester.tap(find.text("Add"));
    await page.wait(tester);
    expect(find.text("Couldn't add the task"), findsOneWidget);
    expect(find.text("New Task"), findsOneWidget);
    expect(find.widgetWithText(TextField, "Gym"), findsOneWidget);

    // Added once it can be, which closes the form.
    page.rows.failWrites = false;
    await tester.tap(find.text("Add"));
    await page.wait(tester);
    expect(find.text("New Task"), findsNothing);
    expect(page.task("Gym").title, "Gym");
    await page.close(tester);
  });
}
