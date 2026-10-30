/// How a day went for a daily task.
enum DayStatus {
  /// The task was done that day.
  done,

  /// Today, with the task still to do.
  due,

  /// The day went by without the task getting done.
  missed,

  /// A day before the task was a daily one, or one still to come, which
  /// doesn't count either way.
  untracked,
}

/// A daily task's days: the day it became a daily task, and the days it
/// was done on. Every other day from then until today went by without it.
class DailyProgress {
  DailyProgress({DateTime? since, Iterable<DateTime> doneDays = const []})
      : since = since == null ? null : _dateOnly(since),
        doneDays = Set.unmodifiable(doneDays.map(_dateOnly));

  /// No days at all, as for a task that's never been a daily one.
  static final none = DailyProgress();

  /// The day the task became a daily one, at midnight, from which each day
  /// counts as done or not. Null if it never has been.
  final DateTime? since;

  /// The days the task was done on, at midnight.
  final Set<DateTime> doneDays;

  /// Whether the task was done on [day].
  bool isDoneOn(DateTime day) => doneDays.contains(_dateOnly(day));

  /// With [day] done, or not.
  DailyProgress withDay(DateTime day, {required bool done}) {
    final date = _dateOnly(day);
    return DailyProgress(
      since: since,
      doneDays:
          done ? {...doneDays, date} : doneDays.where((each) => each != date),
    );
  }

  /// Counting each day from [day] on, as the task becomes a daily one. The
  /// days it was done on before then are kept.
  DailyProgress startingOn(DateTime day) =>
      DailyProgress(since: day, doneDays: doneDays);

  /// How [day] went, as of [today].
  DayStatus statusOf(DateTime day, DateTime today) {
    final date = _dateOnly(day);
    final now = _dateOnly(today);
    final since = this.since;
    if (doneDays.contains(date)) return DayStatus.done;
    if (date == now) return DayStatus.due;
    if (since == null || date.isBefore(since) || date.isAfter(now)) {
      return DayStatus.untracked;
    }
    return DayStatus.missed;
  }

  /// How many days in a row the task has been done, up to [today], or up to
  /// the day before while today's still to do.
  int streak(DateTime today) {
    var day = _dateOnly(today);
    if (!doneDays.contains(day)) day = _dayBefore(day);
    var count = 0;
    while (doneDays.contains(day)) {
      count++;
      day = _dayBefore(day);
    }
    return count;
  }

  /// The days as tasks keep them: the first as "2026-05-12", and the days
  /// done as "2026-05-12,2026-05-13", oldest first. Each is empty without
  /// any, as are older tasks and backups, from before tasks had them.
  factory DailyProgress.fromMap(Map<String, dynamic> map) => DailyProgress(
        since: DateTime.tryParse(map['since'] as String? ?? ""),
        doneDays: (map['doneDays'] as String? ?? "")
            .split(",")
            .map((day) => DateTime.tryParse(day.trim()))
            .nonNulls,
      );

  Map<String, Object> toMap() {
    final since = this.since;
    return {
      'since': since == null ? "" : storedDay(since),
      'doneDays': (doneDays.toList()..sort()).map(storedDay).join(","),
    };
  }
}

/// [day] as tasks keep a day: "2026-05-13".
String storedDay(DateTime day) => "${day.year.toString().padLeft(4, "0")}-"
    "${day.month.toString().padLeft(2, "0")}-"
    "${day.day.toString().padLeft(2, "0")}";

DateTime _dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);

/// Counted by the calendar, as a day can be 23 or 25 hours long.
DateTime _dayBefore(DateTime day) => DateTime(day.year, day.month, day.day - 1);
