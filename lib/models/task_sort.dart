import 'todo_item.dart';

/// What the tasks are listed by, among the tasks they're next to: the tasks
/// of their own among themselves, and each task's subtasks among
/// themselves, under it. Kept as its index, so new ones go last.
enum TaskSort {
  /// The user's own order, which they drag the tasks into.
  custom,

  /// When each task is due, as [TodoItem.dueAsOf] has it. Tasks due at the
  /// same time keep the user's order, and tasks without a day come last,
  /// whichever way they're sorted.
  dueDate;

  /// How to compare two tasks as of [today], [direction] first, or null for
  /// [custom], where they stay as they are.
  Comparator<TodoItem>? compare(DateTime today, SortDirection direction) {
    switch (this) {
      case custom:
        return null;
      case dueDate:
        // Each worked out once, however many tasks it's compared with.
        final dues = Map<TodoItem, DateTime?>.identity();
        DateTime? dueOf(TodoItem task) =>
            dues.putIfAbsent(task, () => task.dueAsOf(today));
        final sign = direction == SortDirection.ascending ? 1 : -1;
        return (a, b) {
          final (first, second) = (dueOf(a), dueOf(b));
          if (first == null || second == null) {
            return (first == null ? 1 : 0) - (second == null ? 1 : 0);
          }
          return sign * first.compareTo(second);
        };
    }
  }
}

/// Which way the tasks are sorted: by due date, the earliest first or the
/// latest first. Kept as its index.
enum SortDirection { ascending, descending }
