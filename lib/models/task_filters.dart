import 'recurrence.dart';
import 'todo_item.dart';

/// Which tasks a page shows: all of them, the done or the undone ones, the
/// ones that come round daily, weekly or monthly, or the ones that happen
/// once. Kept as its index, so new ones go last.
enum TaskFilter {
  all,
  done,
  undone,
  daily,
  weekly,
  monthly,
  once;

  /// Whether [task] is one of them. A repeating task is done or not for the
  /// time that stands for it, and comes round as its card says: a weekly
  /// task on every day of the week is a daily one.
  bool shows(TodoItem task) => switch (this) {
    all => true,
    done => task.done,
    undone => !task.done,
    daily => _cadenceOf(task) == RepeatEvery.day,
    weekly => _cadenceOf(task) == RepeatEvery.week,
    monthly => _cadenceOf(task) == RepeatEvery.month,
    once => !task.repeats,
  };
}

/// How often [task] comes round, or null for one that doesn't repeat.
RepeatEvery? _cadenceOf(TodoItem task) {
  final recurrence = task.recurrence;
  if (recurrence == null) return null;
  if (recurrence.every == RepeatEvery.week &&
      recurrence.weekdays.length == DateTime.daysPerWeek) {
    return RepeatEvery.day;
  }
  return recurrence.every;
}
