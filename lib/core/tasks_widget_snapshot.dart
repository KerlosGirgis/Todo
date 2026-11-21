import 'dart:convert';

import '../models/task_sort.dart';
import '../models/task_tree.dart';
import '../models/todo_item.dart';
import 'utils/task_labels.dart';

/// What the to-do widget on the home screen shows: the tasks, in the order
/// the to-do page lists them, each with how it stands on each of the [days]
/// days from [from], and how many tasks are left to do on each.
///
/// The widget can't work out when a repeating task comes round again, so it
/// gets that day by day, a week ahead: a daily task done today is to do
/// again tomorrow, whether or not the app has opened since. It picks the
/// day it's on, and lists the tasks as [rowsOn] does.
///
/// While the App Lock is on, the widget only gets how many tasks are left,
/// as the home screen would show the tasks to anyone with the phone, which
/// is why reminders don't name their tasks then either.
class TasksWidgetSnapshot {
  const TasksWidgetSnapshot._({
    required this.from,
    required this.locked,
    required this.left,
    required this.total,
    required this.tasks,
  });

  /// How many days ahead the snapshot goes, today included.
  static const days = 7;

  /// The most tasks the widget gets, which is more than it has room for.
  static const maxTasks = 100;

  /// The snapshot of [tasks] as of [now], sorted as [sort] has them, which
  /// lists only how many are left on each day when the App Lock is
  /// [locked]. The tasks inside a task whose subtasks are folded away are
  /// left out, as on the list and the map, but they count among those left.
  factory TasksWidgetSnapshot.of(
    Iterable<TodoItem> tasks, {
    required DateTime now,
    TaskSort sort = TaskSort.custom,
    SortDirection direction = SortDirection.ascending,
    bool locked = false,
  }) {
    final from = DateTime(now.year, now.month, now.day);
    final dates = [
      for (var day = 0; day < days; day++)
        DateTime(from.year, from.month, from.day + day),
    ];
    final all = tasks.toList();
    final left = [
      for (final date in dates)
        all.where((task) => !task.asOf(date).done).length,
    ];
    if (locked) {
      return TasksWidgetSnapshot._(
        from: from,
        locked: true,
        left: left,
        total: all.length,
        tasks: [],
      );
    }
    var tree = TaskTree(all);
    final compare = sort.compare(from, direction);
    if (compare != null) tree = tree.sorted(compare);
    final listed = <WidgetTask>[];
    final indexes = Map<TaskNode, int>.identity();
    for (final node in tree.nodes) {
      if (listed.length == maxTasks) break;
      if (node.ancestors.any((each) => each.task.folded)) continue;
      final task = node.task;
      var done = 0;
      var late = 0;
      final when = <String?>[];
      for (final (day, date) in dates.indexed) {
        final then = task.asOf(date);
        if (then.done) done |= 1 << day;
        if (task.repeats && !then.done && then.isPastDue(date)) {
          late |= 1 << day;
        }
        when.add(taskWhenLabel(then, date));
      }
      indexes[node] = listed.length;
      listed.add(
        WidgetTask(
          title: task.title,
          parent: node.parent == null ? -1 : indexes[node.parent]!,
          done: done,
          late: late,
          due: task.repeats ? null : task.due,
          when: when,
          repeat: switch (task.recurrence) {
            final recurrence? => repeatChipLabel(recurrence),
            null => null,
          },
        ),
      );
    }
    return TasksWidgetSnapshot._(
      from: from,
      locked: false,
      left: left,
      total: all.length,
      tasks: listed,
    );
  }

  /// The day the snapshot was made on, at midnight: its first day.
  final DateTime from;

  /// Whether the App Lock was on, which leaves the tasks out.
  final bool locked;

  /// How many tasks are left to do on each day, subtasks included.
  final List<int> left;

  /// How many tasks there are, subtasks included.
  final int total;

  /// The tasks, each ahead of its own subtasks.
  final List<WidgetTask> tasks;

  /// Which of the snapshot's days [now] is on: the last one once they've
  /// all gone, as nothing more is known, and the first before they start.
  int dayOf(DateTime now) {
    final today = DateTime.utc(now.year, now.month, now.day);
    final first = DateTime.utc(from.year, from.month, from.day);
    return today.difference(first).inDays.clamp(0, days - 1);
  }

  /// The rows the widget lists at [now]: the tasks, the ones that are done
  /// only when it [showDone], each as deep in as the tasks it's in that it
  /// lists. The phone's widget works them out the same way.
  List<WidgetRow> rowsOn(DateTime now, {required bool showDone}) {
    final day = dayOf(now);
    final shown = [for (final task in tasks) showDone || !task.doneOn(day)];
    final depths = <int>[];
    final rows = <WidgetRow>[];
    for (final (index, task) in tasks.indexed) {
      // Counted as each task comes, as the tasks it's in come before it.
      final parent = task.parent;
      final depth = parent < 0 ? 0 : depths[parent] + (shown[parent] ? 1 : 0);
      depths.add(depth);
      if (!shown[index]) continue;
      final done = task.doneOn(day);
      rows.add(
        WidgetRow(
          title: task.title,
          depth: depth,
          done: done,
          late: !done && task.isLateAt(now, day),
          when: task.when[day],
          repeat: task.repeat,
        ),
      );
    }
    return rows;
  }

  /// How many tasks are left at [now].
  int leftOn(DateTime now) => left[dayOf(now)];

  /// The snapshot as the widget reads it: its first day as "2026-05-13";
  /// each task's days done and late as bits, the first day the lowest; its
  /// due time in milliseconds since 1970, for a task that doesn't repeat;
  /// and its labels, one for all the days when they're all the same.
  Map<String, Object?> toJson() => {
    'from':
        "${from.year.toString().padLeft(4, '0')}-"
        "${from.month.toString().padLeft(2, '0')}-"
        "${from.day.toString().padLeft(2, '0')}",
    'locked': locked,
    'left': left,
    'total': total,
    'tasks': [for (final task in tasks) task.toJson()],
  };

  String encode() => jsonEncode(toJson());
}

/// A task as the widget gets it.
class WidgetTask {
  const WidgetTask({
    required this.title,
    required this.parent,
    required this.done,
    required this.late,
    required this.due,
    required this.when,
    required this.repeat,
  });

  final String title;

  /// Where the task it's a subtask of is among the snapshot's tasks, or -1
  /// for a task of its own.
  final int parent;

  /// The days it's done on, a bit for each, the first day the lowest.
  final int done;

  /// The days a repeating task is overdue on: the time that stands for it
  /// came round on a day before, and it isn't done yet.
  final int late;

  /// When a task that doesn't repeat is due, which it's overdue after.
  final DateTime? due;

  /// When it's for, as its card says, on each day, or null when it has
  /// neither a day nor a time.
  final List<String?> when;

  /// How a repeating task comes round, as its card's chip says.
  final String? repeat;

  bool doneOn(int day) => done & (1 << day) != 0;

  bool isLateAt(DateTime now, int day) {
    final due = this.due;
    return due != null ? now.isAfter(due) : late & (1 << day) != 0;
  }

  Map<String, Object?> toJson() {
    final first = when.first;
    return {
      'title': title,
      'parent': parent,
      'done': done,
      'late': late,
      'due': due?.millisecondsSinceEpoch,
      'when': when.every((each) => each == first) ? first : when,
      'repeat': repeat,
    };
  }
}

/// A task as the widget lists it at a time.
class WidgetRow {
  const WidgetRow({
    required this.title,
    required this.depth,
    required this.done,
    required this.late,
    required this.when,
    required this.repeat,
  });

  final String title;

  /// How many of the tasks it's in are listed above it.
  final int depth;
  final bool done;
  final bool late;
  final String? when;
  final String? repeat;

  /// The line under the title: when it's for, and how it repeats.
  String? get details {
    final (day, repeats) = (when, repeat);
    final parts = [?day, ?repeats];
    return parts.isEmpty ? null : parts.join(" · ");
  }
}
