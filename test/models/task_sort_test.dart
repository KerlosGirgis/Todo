import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/repeat_progress.dart';
import 'package:todo/models/task_sort.dart';
import 'package:todo/models/todo_item.dart';

void main() {
  // A Wednesday.
  final today = DateTime(2026, 5, 13);

  TodoItem on(String title, int? day, [ClockTime? time]) => TodoItem(
        uuid: title,
        title: title,
        day: day == null ? null : DateTime(2026, 5, day),
        time: time,
      );

  final tasks = [
    on("Someday", null),
    on("Friday", 15),
    on("Tonight", 13, const ClockTime(20, 0)),
    on("Today", 13),
    on("Late", 11),
    on("Whenever", null),
    on("Morning", 13, const ClockTime(8, 0)),
    // Every day at 6 PM: today, then.
    TodoItem(
      uuid: "Run",
      title: "Run",
      time: const ClockTime(18, 0),
      reminder: Reminder.daily,
      progress: RepeatProgress(since: DateTime(2026, 5, 1)),
    ),
  ];

  /// [tasks] sorted by [sort] in [direction], by title, as a stable sort
  /// would leave them.
  List<String> sorted(TaskSort sort, SortDirection direction) {
    final compare = sort.compare(today, direction);
    if (compare == null) return [for (final task in tasks) task.title];
    final indexed = tasks.indexed.toList()
      ..sort((a, b) {
        final order = compare(a.$2, b.$2);
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return [for (final (_, task) in indexed) task.title];
  }

  test('Custom leaves the tasks as they are', () {
    expect(TaskSort.custom.compare(today, SortDirection.ascending), isNull);
  });

  test('due date puts the earliest first, the ones without a day last', () {
    expect(sorted(TaskSort.dueDate, SortDirection.ascending), [
      "Late",
      "Morning",
      "Run",
      "Tonight",
      // As today ends.
      "Today",
      "Friday",
      "Someday",
      "Whenever",
    ]);
  });

  test('due date can put the latest first, still with no day last', () {
    expect(sorted(TaskSort.dueDate, SortDirection.descending), [
      "Friday",
      "Today",
      "Tonight",
      "Run",
      "Morning",
      "Late",
      "Someday",
      "Whenever",
    ]);
  });
}
