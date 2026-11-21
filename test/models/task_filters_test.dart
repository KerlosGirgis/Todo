import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/task_filters.dart';
import 'package:todo/models/todo_item.dart';

void main() {
  TodoItem task(
    String title, {
    bool done = false,
    Reminder reminder = Reminder.none,
    Set<int> weekdays = const {},
    int? monthDay,
  }) => TodoItem(
    uuid: title,
    title: title,
    done: done,
    day: reminder == Reminder.once ? DateTime(2026, 5, 20) : null,
    time: reminder == Reminder.none ? null : const ClockTime(9, 0),
    reminder: reminder,
    weekdays: weekdays,
    monthDay: monthDay,
  );

  final tasks = [
    task("Call", done: true),
    task("Dentist", reminder: Reminder.once),
    task("Stretch", reminder: Reminder.daily, done: true),
    task(
      "Gym",
      reminder: Reminder.weekly,
      weekdays: {DateTime.monday, DateTime.thursday},
    ),
    // Every day of the week, which its card calls daily.
    task("Walk", reminder: Reminder.weekly, weekdays: {1, 2, 3, 4, 5, 6, 7}),
    task("Rent", reminder: Reminder.monthly, monthDay: 1),
    // Without its days, it doesn't repeat.
    task("Odd", reminder: Reminder.weekly),
  ];

  List<String> shown(TaskFilter filter) => [
    for (final each in tasks.where(filter.shows)) each.title,
  ];

  test('All lets every task through', () {
    expect(shown(TaskFilter.all), hasLength(tasks.length));
  });

  test('Done and Undone go by whether a task is done', () {
    expect(shown(TaskFilter.done), ["Call", "Stretch"]);
    expect(shown(TaskFilter.undone), ["Dentist", "Gym", "Walk", "Rent", "Odd"]);
  });

  test('Daily, Weekly and Monthly go by how often a task comes round', () {
    expect(shown(TaskFilter.daily), ["Stretch", "Walk"]);
    expect(shown(TaskFilter.weekly), ["Gym"]);
    expect(shown(TaskFilter.monthly), ["Rent"]);
  });

  test("Once lets through the tasks that don't repeat", () {
    expect(shown(TaskFilter.once), ["Call", "Dentist", "Odd"]);
  });
}
