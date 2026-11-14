import 'clock_time.dart';
import 'daily_progress.dart';

/// A task's reminder: none, once on its day at its time, or every day at
/// its time. Kept as its index: 0, 1 or 2.
enum Reminder { none, once, daily }

class TodoItem {
  /// A daily task goes off every day, so it has no [day], whatever's given.
  TodoItem({
    this.id,
    required this.uuid,
    required this.title,
    this.desc = "",
    this.done = false,
    DateTime? day,
    this.time,
    this.reminder = Reminder.none,
    DailyProgress? progress,
    String? parent,
    this.folded = false,
  })  : day = day == null || reminder == Reminder.daily
            ? null
            : DateTime(day.year, day.month, day.day),
        progress = progress ?? DailyProgress.none,
        parent = parent == null || parent.isEmpty ? null : parent;

  final int? id;

  /// Tells the task apart for good: [id]s change whenever the tasks are
  /// reordered. Its reminder goes by it too.
  final String uuid;
  final String title;
  final String desc;

  /// Whether the task is done. A daily task's is whether it's done today,
  /// as of the day [asOf] gave it for.
  final bool done;

  /// The day the task is for, at midnight, if it's for one.
  final DateTime? day;
  final ClockTime? time;
  final Reminder reminder;

  /// The days a daily task was done on, and since when it's been one. A
  /// task keeps them when it stops being daily.
  final DailyProgress progress;

  /// The [uuid] of the task this one is a subtask of, or null for a task of
  /// its own. One whose task has gone counts as a task of its own too.
  final String? parent;

  /// Whether its subtasks are folded away, on the list and on the map.
  final bool folded;

  /// Whether the task is for every day, done or not each day afresh: one
  /// that reminds the user daily.
  bool get isDaily => reminder == Reminder.daily;

  /// The task as it stands on [today]: a daily task is done only if it was
  /// done that day.
  TodoItem asOf(DateTime today) =>
      isDaily ? copyWith(done: progress.isDoneOn(today)) : this;

  /// The task marked done, or not done again, on [today]. A daily task is
  /// done for that day only, and keeps its reminder; any other is done for
  /// good, which turns its reminder off.
  TodoItem marked({required bool done, required DateTime today}) => isDaily
      ? copyWith(done: done, progress: progress.withDay(today, done: done))
      : copyWith(done: done, reminder: done ? Reminder.none : null);

  /// The task as a subtask of the one with the uuid [parent], or as a task
  /// of its own for null.
  TodoItem under(String? parent) => _copy(parent: parent);

  /// When the task is due: at its time on its day, or as its day ends when
  /// it has no time. Null when it has no day.
  DateTime? get due {
    final day = this.day;
    if (day == null) return null;
    return time?.on(day) ?? DateTime(day.year, day.month, day.day + 1);
  }

  /// Whether the task was due before [now].
  bool isPastDue(DateTime now) => due?.isBefore(now) ?? false;

  TodoItem copyWith({
    int? id,
    String? uuid,
    bool? done,
    Reminder? reminder,
    DailyProgress? progress,
    bool? folded,
  }) =>
      _copy(
        id: id,
        uuid: uuid,
        done: done,
        reminder: reminder,
        progress: progress,
        parent: parent,
        folded: folded,
      );

  /// A copy with what's given in place of its own, and [parent] whatever it
  /// is: null takes the task out of the one it's in.
  TodoItem _copy({
    int? id,
    String? uuid,
    bool? done,
    Reminder? reminder,
    DailyProgress? progress,
    required String? parent,
    bool? folded,
  }) {
    return TodoItem(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      title: title,
      desc: desc,
      done: done ?? this.done,
      day: day,
      time: time,
      reminder: reminder ?? this.reminder,
      progress: progress ?? this.progress,
      parent: parent,
      folded: folded ?? this.folded,
    );
  }

  /// A task as the database and backups keep it. Older backups may lack the
  /// fields that came later.
  factory TodoItem.fromMap(Map<String, dynamic> map) {
    final reminder = map['notification'] as int? ?? 0;
    return TodoItem(
      id: map['id'] as int?,
      uuid: map['uuid'] as String? ?? "",
      title: map['title'] as String? ?? "",
      desc: map['desc'] as String? ?? "",
      done: map['status'] == 1,
      day: DateTime.tryParse(map['date'] as String? ?? ""),
      time: ClockTime.tryParse(map['time'] as String? ?? ""),
      reminder: Reminder.values.elementAtOrNull(reminder) ?? Reminder.none,
      progress: DailyProgress.fromMap(map),
      parent: map['parent'] as String?,
      folded: map['folded'] == 1,
    );
  }

  /// The day as "2026-05-13", or empty without one; the time as "9:30 PM",
  /// or empty; then the days of a daily task, the uuid of the task it's a
  /// subtask of, or empty for a task of its own, and whether its subtasks
  /// are folded away.
  Map<String, Object> toMap() {
    final day = this.day;
    return {
      'title': title,
      'desc': desc,
      'status': done ? 1 : 0,
      'date': day == null ? "" : storedDay(day),
      'time': time?.label ?? "",
      'uuid': uuid,
      'notification': reminder.index,
      ...progress.toMap(),
      'parent': parent ?? "",
      'folded': folded ? 1 : 0,
    };
  }
}
