import 'clock_time.dart';
import 'recurrence.dart';
import 'repeat_progress.dart';

/// A task's reminder: none; once, on its day at its time; or at its time
/// each time the task comes round: every day, on some days of every week,
/// or on a day of every month. Kept as its index: 0 to 4.
enum Reminder {
  none,
  once,
  daily,
  weekly,
  monthly;

  /// Whether it goes off again and again, as the task comes round.
  bool get repeats => index >= daily.index;

  /// The reminder of a task that comes round [every] day, week or month.
  static Reminder repeating(RepeatEvery every) => switch (every) {
    RepeatEvery.day => daily,
    RepeatEvery.week => weekly,
    RepeatEvery.month => monthly,
  };
}

class TodoItem {
  /// A repeating task comes round on days of its own, so it has no [day],
  /// whatever's given; and a task keeps only the [weekdays], [monthDay] and
  /// [until] its reminder goes by.
  TodoItem({
    this.id,
    required this.uuid,
    required this.title,
    this.desc = "",
    this.done = false,
    DateTime? day,
    this.time,
    this.reminder = Reminder.none,
    Set<int> weekdays = const {},
    int? monthDay,
    DateTime? until,
    RepeatProgress? progress,
    String? parent,
    this.folded = false,
  }) : day = day == null || reminder.repeats ? null : _date(day),
       weekdays = reminder == Reminder.weekly
           ? Set.unmodifiable(weekdays.where(Recurrence.isWeekday))
           : const <int>{},
       monthDay =
           reminder == Reminder.monthly &&
               monthDay != null &&
               Recurrence.isMonthDay(monthDay)
           ? monthDay
           : null,
       until = until == null || !reminder.repeats ? null : _date(until),
       progress = progress ?? RepeatProgress.none,
       parent = parent == null || parent.isEmpty ? null : parent;

  final int? id;

  /// Tells the task apart for good: [id]s change whenever the tasks are
  /// reordered. Its reminder goes by it too.
  final String uuid;
  final String title;
  final String desc;

  /// Whether the task is done. A repeating task's is whether it's done for
  /// the time that stands for it, as of the day [asOf] gave it for.
  final bool done;

  /// The day the task is for, at midnight, if it's for one.
  final DateTime? day;
  final ClockTime? time;
  final Reminder reminder;

  /// The days of the week a weekly task comes round on, from
  /// [DateTime.monday] to [DateTime.sunday].
  final Set<int> weekdays;

  /// The day of the month a monthly task comes round on, from 1 to 31.
  final int? monthDay;

  /// The last day a repeating task repeats on, at midnight, or null for one
  /// that repeats for good.
  final DateTime? until;

  /// The days a repeating task was done for, and since when it's been one. A
  /// task keeps them when it stops repeating.
  final RepeatProgress progress;

  /// The [uuid] of the task this one is a subtask of, or null for a task of
  /// its own. One whose task has gone counts as a task of its own too.
  final String? parent;

  /// Whether its subtasks are folded away, on the list and on the map.
  final bool folded;

  /// When the task comes round, if it repeats: as its reminder has it, from
  /// the day it started repeating to its last day. Null for a task that
  /// doesn't, as for one whose reminder lacks the days it goes by.
  late final Recurrence? recurrence = switch (reminder) {
    Reminder.daily => Recurrence.daily(since: progress.since, until: until),
    Reminder.weekly when weekdays.isNotEmpty => Recurrence.weekly(
      weekdays,
      since: progress.since,
      until: until,
    ),
    Reminder.monthly when monthDay != null => Recurrence.monthly(
      monthDay!,
      since: progress.since,
      until: until,
    ),
    _ => null,
  };

  /// Whether the task comes round again and again, done or not each time
  /// afresh: one that reminds the user daily, weekly or monthly.
  bool get repeats => recurrence != null;

  /// Whether the task is for every day.
  bool get isDaily => reminder == Reminder.daily;

  /// The day that stands for a repeating task on [today]: the last time it
  /// came round, until the next time does, or the first time, while that's
  /// still to come. Null for a task that doesn't repeat, or never comes
  /// round.
  DateTime? occurrenceOn(DateTime today) => recurrence?.currentAsOf(today);

  /// The task as it stands on [today]: a repeating task is done only if it
  /// was done for the time that stands for it then.
  TodoItem asOf(DateTime today) {
    if (!repeats) return this;
    final occurrence = occurrenceOn(today);
    return copyWith(done: occurrence != null && progress.isDoneOn(occurrence));
  }

  /// The task marked done, or not done again, on [today]. A repeating task is
  /// done for the time that stands for it only, and keeps its reminder; any
  /// other is done for good, which turns its reminder off.
  TodoItem marked({required bool done, required DateTime today}) {
    if (!repeats) {
      return copyWith(done: done, reminder: done ? Reminder.none : null);
    }
    final occurrence = occurrenceOn(today) ?? today;
    return copyWith(
      done: done,
      progress: progress.withDay(occurrence, done: done),
    );
  }

  /// The task as a subtask of the one with the uuid [parent], or as a task
  /// of its own for null.
  TodoItem under(String? parent) => _copy(parent: parent);

  /// The task coming round as [rule] has it: on its days, with its last day,
  /// and with [progress] as its record. It has no day of its own then.
  TodoItem repeatingAs(Recurrence rule, {RepeatProgress? progress}) => TodoItem(
    id: id,
    uuid: uuid,
    title: title,
    desc: desc,
    done: done,
    time: time,
    reminder: Reminder.repeating(rule.every),
    weekdays: rule.weekdays,
    monthDay: rule.monthDay,
    until: rule.until,
    progress: progress ?? this.progress,
    parent: parent,
    folded: folded,
  );

  /// When the task is due: at its time on its day, or as its day ends when
  /// it has no time. Null when it has no day, as a repeating task has none.
  DateTime? get due => _dueOn(day);

  /// When the task is due as of [today], which tasks are sorted by: as
  /// [due] has it, or, for a repeating task, at its time on the day that
  /// stands for it then, which is today for a daily task. Null for a task
  /// without a day, and for a repeating one that never comes round.
  DateTime? dueAsOf(DateTime today) =>
      _dueOn(repeats ? occurrenceOn(today) : day);

  DateTime? _dueOn(DateTime? day) {
    if (day == null) return null;
    return time?.on(day) ?? DateTime(day.year, day.month, day.day + 1);
  }

  /// Whether the task was due before [now]. A repeating task is overdue
  /// while the time that stands for it is from a day before: one it wasn't
  /// done for, as long as it's done afterwards.
  bool isPastDue(DateTime now) {
    if (repeats) {
      final occurrence = occurrenceOn(now);
      return occurrence != null && occurrence.isBefore(_date(now));
    }
    return due?.isBefore(now) ?? false;
  }

  TodoItem copyWith({
    int? id,
    String? uuid,
    bool? done,
    Reminder? reminder,
    RepeatProgress? progress,
    bool? folded,
  }) => _copy(
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
    RepeatProgress? progress,
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
      weekdays: weekdays,
      monthDay: monthDay,
      until: until,
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
      weekdays: (map['weekdays'] as String? ?? "")
          .split(",")
          .map((day) => int.tryParse(day.trim()))
          .nonNulls
          .toSet(),
      monthDay: switch (map['monthDay']) {
        final int day => day,
        final String day => int.tryParse(day),
        _ => null,
      },
      until: DateTime.tryParse(map['until'] as String? ?? ""),
      progress: RepeatProgress.fromMap(map),
      parent: map['parent'] as String?,
      folded: map['folded'] == 1,
    );
  }

  /// The day as "2026-05-13", or empty without one; the time as "9:30 PM",
  /// or empty; then the days of the week a weekly task comes round on, as
  /// "1,3,5" from Monday, the day of the month a monthly one does, or 0, and
  /// a repeating task's last day, or empty; then its days, the uuid of the
  /// task it's a subtask of, or empty for a task of its own, and whether its
  /// subtasks are folded away.
  Map<String, Object> toMap() {
    final day = this.day;
    final until = this.until;
    return {
      'title': title,
      'desc': desc,
      'status': done ? 1 : 0,
      'date': day == null ? "" : storedDay(day),
      'time': time?.label ?? "",
      'uuid': uuid,
      'notification': reminder.index,
      'weekdays': (weekdays.toList()..sort()).join(","),
      'monthDay': monthDay ?? 0,
      'until': until == null ? "" : storedDay(until),
      ...progress.toMap(),
      'parent': parent ?? "",
      'folded': folded ? 1 : 0,
    };
  }
}

DateTime _date(DateTime time) => DateTime(time.year, time.month, time.day);
