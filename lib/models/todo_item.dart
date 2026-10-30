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
  })  : day = day == null || reminder == Reminder.daily
            ? null
            : DateTime(day.year, day.month, day.day),
        progress = progress ?? DailyProgress.none;

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

  /// Whether the task is for every day, done or not each day afresh: one
  /// that reminds the user daily.
  bool get isDaily => reminder == Reminder.daily;

  /// The task as it stands on [today]: a daily task is done only if it was
  /// done that day.
  TodoItem asOf(DateTime today) =>
      isDaily ? copyWith(done: progress.isDoneOn(today)) : this;

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
    );
  }

  /// The day as "2026-05-13", or empty without one; the time as "9:30 PM",
  /// or empty; then the days of a daily task.
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
    };
  }
}
