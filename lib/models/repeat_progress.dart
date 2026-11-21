/// A repeating task's record: the day it started repeating, and the days it
/// was done for. Which days it comes round on, and so which went by without
/// it, is for its recurrence to say.
class RepeatProgress {
  RepeatProgress({DateTime? since, Iterable<DateTime> doneDays = const []})
    : since = since == null ? null : _dateOnly(since),
      doneDays = Set.unmodifiable(doneDays.map(_dateOnly));

  /// No days at all, as for a task that's never repeated.
  static final none = RepeatProgress();

  /// The day the task started repeating, at midnight, from which each time
  /// it comes round counts as done or not. Null if it never has.
  final DateTime? since;

  /// The days the task was done for, at midnight: each a day it came round
  /// on, or one from before, when it may have come round on others.
  final Set<DateTime> doneDays;

  /// Whether the task was done for [day].
  bool isDoneOn(DateTime day) => doneDays.contains(_dateOnly(day));

  /// With [day] done, or not.
  RepeatProgress withDay(DateTime day, {required bool done}) {
    final date = _dateOnly(day);
    return RepeatProgress(
      since: since,
      doneDays: done
          ? {...doneDays, date}
          : doneDays.where((each) => each != date),
    );
  }

  /// Counting each time from [day] on, as the task starts repeating, or
  /// starts coming round on other days. The days it was done for before
  /// then are kept.
  RepeatProgress startingOn(DateTime day) =>
      RepeatProgress(since: day, doneDays: doneDays);

  /// The days as tasks keep them: the first as "2026-05-12", and the days
  /// done as "2026-05-12,2026-05-13", oldest first. Each is empty without
  /// any, as are older tasks and backups, from before tasks had them.
  factory RepeatProgress.fromMap(Map<String, dynamic> map) => RepeatProgress(
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
String storedDay(DateTime day) =>
    "${day.year.toString().padLeft(4, "0")}-"
    "${day.month.toString().padLeft(2, "0")}-"
    "${day.day.toString().padLeft(2, "0")}";

DateTime _dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);
