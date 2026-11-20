import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/repeat_progress.dart';
import 'package:todo/models/task_sort.dart';
import 'package:todo/models/tasks_widget_snapshot.dart';
import 'package:todo/models/todo_item.dart';

/// Noon on a Wednesday.
final now = DateTime(2026, 5, 13, 12);

void main() {
  group('the tasks', () {
    test('come each ahead of its subtasks, none from inside a folded one', () {
      final snapshot = TasksWidgetSnapshot.of([
        TodoItem(uuid: "a", title: "A"),
        TodoItem(uuid: "b", title: "B", folded: true),
        TodoItem(uuid: "c", title: "C", parent: "b"),
        TodoItem(uuid: "d", title: "D", parent: "a"),
        TodoItem(uuid: "e", title: "E"),
      ], now: now);
      expect([for (final task in snapshot.tasks) task.title],
          ["A", "D", "B", "E"]);
      expect([for (final task in snapshot.tasks) task.parent], [-1, 0, -1, -1]);
      // The folded one's still counts.
      expect(snapshot.total, 5);
      expect(snapshot.left, List.filled(7, 5));
    });

    test('come in the to-do page\'s order', () {
      final tasks = [
        TodoItem(uuid: "x", title: "X", day: DateTime(2026, 5, 20)),
        TodoItem(uuid: "y", title: "Y", day: DateTime(2026, 5, 14)),
        TodoItem(uuid: "z", title: "Z"),
      ];
      List<String> titles(TasksWidgetSnapshot snapshot) =>
          [for (final task in snapshot.tasks) task.title];
      expect(titles(TasksWidgetSnapshot.of(tasks, now: now)), ["X", "Y", "Z"]);
      expect(
          titles(
              TasksWidgetSnapshot.of(tasks, now: now, sort: TaskSort.dueDate)),
          ["Y", "X", "Z"]);
      expect(
          titles(TasksWidgetSnapshot.of(tasks,
              now: now,
              sort: TaskSort.dueDate,
              direction: SortDirection.descending)),
          ["X", "Y", "Z"]);
    });

    test('stop at a hundred, though all of them count', () {
      final snapshot = TasksWidgetSnapshot.of([
        for (var i = 0; i < 150; i++) TodoItem(uuid: "$i", title: "$i"),
      ], now: now);
      expect(snapshot.tasks, hasLength(TasksWidgetSnapshot.maxTasks));
      expect(snapshot.total, 150);
    });
  });

  group('day by day, a week ahead', () {
    test('a daily task done today is to do again tomorrow', () {
      final snapshot = TasksWidgetSnapshot.of([
        TodoItem(
          uuid: "run",
          title: "Run",
          time: const ClockTime(7, 0),
          reminder: Reminder.daily,
          progress: RepeatProgress(
              since: DateTime(2026, 5, 1), doneDays: [DateTime(2026, 5, 13)]),
        ),
      ], now: now);
      final run = snapshot.tasks.single;
      expect(run.done, 1);
      expect(run.late, 0);
      expect(run.due, isNull);
      expect(run.when, List.filled(7, "7:00 AM"));
      expect(run.repeat, "Daily");
      expect(snapshot.left, [0, 1, 1, 1, 1, 1, 1]);
      expect(run.toJson()['when'], "7:00 AM");
    });

    test('a weekly one stays done until it comes round again', () {
      final snapshot = TasksWidgetSnapshot.of([
        TodoItem(
          uuid: "review",
          title: "Review",
          time: const ClockTime(9, 0),
          reminder: Reminder.weekly,
          weekdays: const {DateTime.monday},
          progress: RepeatProgress(
              since: DateTime(2026, 5, 1), doneDays: [DateTime(2026, 5, 11)]),
        ),
      ], now: now);
      final review = snapshot.tasks.single;
      // Done from Wednesday to Sunday; to do on Monday, and late on Tuesday.
      expect(review.done, 31);
      expect(review.late, 64);
      expect(review.when, [
        ...List.filled(5, "Mon, May 11, 9:00 AM"),
        "Today, 9:00 AM",
        "Yesterday, 9:00 AM",
      ]);
      expect(review.repeat, "Weekly");
    });

    test('one that doesn\'t repeat is late once its time has gone', () {
      final snapshot = TasksWidgetSnapshot.of([
        TodoItem(
          uuid: "plants",
          title: "Water the plants",
          day: DateTime(2026, 5, 13),
          time: const ClockTime(18, 0),
          reminder: Reminder.once,
        ),
      ], now: now);
      final plants = snapshot.tasks.single;
      expect(plants.due, DateTime(2026, 5, 13, 18));
      expect(plants.when.take(3),
          ["Today, 6:00 PM", "Yesterday, 6:00 PM", "Wed, May 13, 6:00 PM"]);
      expect(snapshot.rowsOn(now, showDone: false).single.late, isFalse);
      expect(
          snapshot
              .rowsOn(DateTime(2026, 5, 13, 18, 1), showDone: false)
              .single
              .late,
          isTrue);
    });
  });

  group('the rows', () {
    final snapshot = TasksWidgetSnapshot.of([
      TodoItem(uuid: "p", title: "Pack", done: true),
      TodoItem(
        uuid: "q",
        title: "Stretch",
        parent: "p",
        time: const ClockTime(8, 0),
        reminder: Reminder.daily,
        progress: RepeatProgress(since: DateTime(2026, 5, 1)),
      ),
      TodoItem(uuid: "r", title: "Socks", parent: "q", done: true),
      TodoItem(uuid: "s", title: "Shirts", parent: "r"),
    ], now: now);

    test('are each as deep in as the tasks it\'s in that are listed', () {
      final rows = snapshot.rowsOn(now, showDone: true);
      expect([
        for (final row in rows) (row.title, row.depth, row.done)
      ], [
        ("Pack", 0, true),
        ("Stretch", 1, false),
        ("Socks", 2, true),
        ("Shirts", 3, false),
      ]);
      expect(rows[1].details, "8:00 AM · Daily");
      expect(rows[0].details, isNull);
    });

    test('leave out the tasks that are done, unless they\'re shown', () {
      final rows = snapshot.rowsOn(now, showDone: false);
      expect([
        for (final row in rows) (row.title, row.depth)
      ], [
        ("Stretch", 0),
        ("Shirts", 1),
      ]);
    });

    test('go by the last day once the week has gone', () {
      expect(snapshot.dayOf(DateTime(2026, 5, 12, 23)), 0);
      expect(snapshot.dayOf(DateTime(2026, 5, 16)), 3);
      expect(snapshot.dayOf(DateTime(2026, 6, 1)), 6);
      expect(snapshot.leftOn(DateTime(2026, 6, 1)), snapshot.left[6]);
    });
  });

  test('while the App Lock is on, only how many are left', () {
    final snapshot = TasksWidgetSnapshot.of([
      TodoItem(uuid: "a", title: "Secret plan"),
      TodoItem(uuid: "b", title: "Done already", done: true),
    ], now: now, locked: true);
    expect(snapshot.locked, isTrue);
    expect(snapshot.tasks, isEmpty);
    expect(snapshot.left, List.filled(7, 1));
    expect(snapshot.total, 2);
    expect(snapshot.encode(), isNot(contains("Secret")));
  });

  test('as the phone\'s widget reads it', () {
    final snapshot = TasksWidgetSnapshot.of([
      TodoItem(
        uuid: "plants",
        title: "Water the plants",
        day: DateTime(2026, 5, 14),
        reminder: Reminder.once,
      ),
    ], now: now);
    expect(jsonDecode(snapshot.encode()), {
      'from': "2026-05-13",
      'locked': false,
      'left': List.filled(7, 1),
      'total': 1,
      'tasks': [
        {
          'title': "Water the plants",
          'parent': -1,
          'done': 0,
          'late': 0,
          'due': DateTime(2026, 5, 15).millisecondsSinceEpoch,
          'when': [
            "Tomorrow",
            "Today",
            "Yesterday",
            "Thu, May 14",
            "Thu, May 14",
            "Thu, May 14",
            "Thu, May 14",
          ],
          'repeat': null,
        },
      ],
    });
  });
}
