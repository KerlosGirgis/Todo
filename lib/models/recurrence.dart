/// How often a repeating task comes round.
enum RepeatEvery {
  /// Every day.
  day,

  /// On some days of every week.
  week,

  /// On one day of every month.
  month,
}

/// What a while a task repeats for is counted in.
enum RepeatUnit {
  days,
  weeks,
  months;

  /// The last day of [amount] of these, with [start] as the first day: a
  /// week from a Friday ends on the Thursday after, and a month from the
  /// 31st ends on the day before the 31st of the month after, or before its
  /// last day when it has no 31st.
  DateTime lastDay(DateTime start, int amount) {
    final DateTime end;
    switch (this) {
      case RepeatUnit.days:
        end = DateTime(start.year, start.month, start.day + amount);
      case RepeatUnit.weeks:
        end = DateTime(start.year, start.month, start.day + 7 * amount);
      case RepeatUnit.months:
        final month = DateTime(start.year, start.month + amount);
        end = DateTime(
          month.year,
          month.month,
          start.day < _daysIn(month) ? start.day : _daysIn(month),
        );
    }
    return _dayBefore(end);
  }
}

/// How a day went for a repeating task.
enum DayStatus {
  /// The task was done for that day.
  done,

  /// The day that stands for the task now, with the task still to do.
  due,

  /// The day came round and went by without the task getting done, and the
  /// next one has come since.
  missed,

  /// A day the task doesn't come round on, one before it started repeating,
  /// or one still to come, which doesn't count either way.
  untracked,
}

/// When a repeating task comes round: every day, on some days of the week,
/// or on a day of the month; from the day it started repeating, [since], to
/// the last day it repeats on, [until], or for good.
///
/// Each time it comes round stands for the task until the next one does: a
/// time that's missed can still be done late, until then. A month without
/// its day, as February has no 30th, is skipped, as on a calendar, and as
/// the phone's monthly reminders skip it.
class Recurrence {
  /// Every day.
  Recurrence.daily({DateTime? since, DateTime? until})
    : this._(RepeatEvery.day, since: since, until: until);

  /// On each of [weekdays], from [DateTime.monday] to [DateTime.sunday].
  Recurrence.weekly(Set<int> weekdays, {DateTime? since, DateTime? until})
    : this._(RepeatEvery.week, weekdays: weekdays, since: since, until: until);

  /// On [day] of each month, from 1 to 31.
  Recurrence.monthly(int day, {DateTime? since, DateTime? until})
    : this._(RepeatEvery.month, monthDay: day, since: since, until: until);

  /// Throws an [ArgumentError] for a weekly one without its days, or a
  /// monthly one without its day, which would never come round.
  Recurrence._(
    this.every, {
    Set<int> weekdays = const {},
    int? monthDay,
    DateTime? since,
    DateTime? until,
  }) : weekdays = every == RepeatEvery.week
           ? Set.unmodifiable(_checkedWeekdays(weekdays))
           : const <int>{},
       monthDay = every == RepeatEvery.month
           ? _checkedMonthDay(monthDay)
           : null,
       since = since == null ? null : _date(since),
       until = until == null ? null : _date(until);

  static Set<int> _checkedWeekdays(Set<int> days) {
    if (days.isEmpty || !days.every(isWeekday)) {
      throw ArgumentError.value(days, "weekdays", "Needs days of the week");
    }
    return days;
  }

  static int _checkedMonthDay(int? day) {
    if (day == null || !isMonthDay(day)) {
      throw ArgumentError.value(day, "monthDay", "Needs a day from 1 to 31");
    }
    return day;
  }

  final RepeatEvery every;

  /// The days of the week a weekly task comes round on, from
  /// [DateTime.monday] to [DateTime.sunday]. Empty for the others.
  final Set<int> weekdays;

  /// The day of the month a monthly task comes round on, from 1 to 31, or
  /// null for the others.
  final int? monthDay;

  /// The day it started repeating, at midnight, from which each time it
  /// comes round counts as done or missed. Null when that isn't known, as
  /// for a task from before tasks kept it: no day before today is missed.
  final DateTime? since;

  /// The last day it repeats on, at midnight, or null for good.
  final DateTime? until;

  static bool isWeekday(int day) =>
      day >= DateTime.monday && day <= DateTime.sunday;

  static bool isMonthDay(int day) => day >= 1 && day <= 31;

  /// The same days, from [since] to [until] instead.
  Recurrence spanning({required DateTime? since, required DateTime? until}) =>
      Recurrence._(
        every,
        weekdays: weekdays,
        monthDay: monthDay,
        since: since,
        until: until,
      );

  /// Whether it comes round on the same days as [other], whenever each of
  /// them starts or stops.
  bool repeatsLike(Recurrence other) =>
      every == other.every &&
      monthDay == other.monthDay &&
      weekdays.length == other.weekdays.length &&
      weekdays.containsAll(other.weekdays);

  /// Whether [day] is one of the days it comes round on, whether or not
  /// it's repeating by then, or still.
  bool fits(DateTime day) => switch (every) {
    RepeatEvery.day => true,
    RepeatEvery.week => weekdays.contains(day.weekday),
    RepeatEvery.month => day.day == monthDay,
  };

  /// Whether it comes round on [day].
  bool occursOn(DateTime day) {
    final date = _date(day);
    return fits(date) && _within(date);
  }

  bool _within(DateTime date) {
    final since = this.since;
    final until = this.until;
    return (since == null || !date.isBefore(since)) &&
        (until == null || !date.isAfter(until));
  }

  /// The last day it comes round on, [day] or before, or null when it
  /// hasn't come round by then.
  DateTime? lastOnOrBefore(DateTime day) {
    var date = _date(day);
    final until = this.until;
    if (until != null && date.isAfter(until)) date = until;
    final found = _fitOnOrBefore(date);
    final since = this.since;
    if (since != null && found.isBefore(since)) return null;
    return found;
  }

  /// The first day it comes round on, [day] or after, or null when it
  /// doesn't anymore.
  DateTime? firstOnOrAfter(DateTime day) {
    var date = _date(day);
    final since = this.since;
    if (since != null && date.isBefore(since)) date = since;
    final found = _fitOnOrAfter(date);
    final until = this.until;
    if (until != null && found.isAfter(until)) return null;
    return found;
  }

  /// The day that stands for the task on [today]: the last time it came
  /// round, today or before, which stands until the next one; or the first
  /// time, while that's still to come. Null when it never comes round, as
  /// when it stops before it would.
  DateTime? currentAsOf(DateTime today) =>
      lastOnOrBefore(today) ?? firstOnOrAfter(today);

  /// Each day it comes round on, from [day] on, in order: for good, unless
  /// it stops.
  Iterable<DateTime> from(DateTime day) sync* {
    for (
      var next = firstOnOrAfter(day);
      next != null;
      next = firstOnOrAfter(_dayAfter(next))
    ) {
      yield next;
    }
  }

  /// Whether it's done coming round by [today]: it has stopped, and its last
  /// time has gone.
  bool hasEndedBy(DateTime today) =>
      until != null && firstOnOrAfter(today) == null;

  /// How [day] went, as of [today], for a task done on the days in [done]:
  /// every time it came round stands until the next one, so it's only
  /// missed once the next has come.
  DayStatus statusOf(
    DateTime day,
    DateTime today, {
    required Set<DateTime> done,
  }) {
    final date = _date(day);
    if (done.contains(date)) return DayStatus.done;
    final current = currentAsOf(today);
    if (current == null || date.isAfter(current) || !occursOn(date)) {
      return DayStatus.untracked;
    }
    if (date == current) return DayStatus.due;
    return since == null ? DayStatus.untracked : DayStatus.missed;
  }

  /// How many times in a row the task has been done, on the days in [done]:
  /// up to the day that stands for it on [today], or up to the time before
  /// while that one's still to do.
  int streak(DateTime today, {required Set<DateTime> done}) {
    final current = currentAsOf(today);
    if (current == null) return 0;
    var day = done.contains(current) ? current : _fitBefore(current);
    var count = 0;
    while (done.contains(day)) {
      count++;
      day = _fitBefore(day);
    }
    return count;
  }

  /// The day it comes round on before [day], however long before it
  /// started repeating.
  DateTime _fitBefore(DateTime day) => _fitOnOrBefore(_dayBefore(day));

  DateTime _fitOnOrBefore(DateTime date) {
    switch (every) {
      case RepeatEvery.day:
        return date;
      case RepeatEvery.week:
        var day = date;
        while (!weekdays.contains(day.weekday)) {
          day = _dayBefore(day);
        }
        return day;
      case RepeatEvery.month:
        final monthDay = this.monthDay!;
        // Every day of the month is in one of any two months in a row.
        for (var back = 0; ; back++) {
          final month = DateTime(date.year, date.month - back);
          if (_daysIn(month) < monthDay) continue;
          final day = DateTime(month.year, month.month, monthDay);
          if (!day.isAfter(date)) return day;
        }
    }
  }

  DateTime _fitOnOrAfter(DateTime date) {
    switch (every) {
      case RepeatEvery.day:
        return date;
      case RepeatEvery.week:
        var day = date;
        while (!weekdays.contains(day.weekday)) {
          day = _dayAfter(day);
        }
        return day;
      case RepeatEvery.month:
        final monthDay = this.monthDay!;
        for (var ahead = 0; ; ahead++) {
          final month = DateTime(date.year, date.month + ahead);
          if (_daysIn(month) < monthDay) continue;
          final day = DateTime(month.year, month.month, monthDay);
          if (!day.isBefore(date)) return day;
        }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Recurrence &&
      repeatsLike(other) &&
      other.since == since &&
      other.until == until;

  @override
  int get hashCode => Object.hash(
    every,
    monthDay,
    Object.hashAllUnordered(weekdays),
    since,
    until,
  );

  @override
  String toString() =>
      "Recurrence(${every.name}, ${weekdays.toList()..sort()}, $monthDay, "
      "$since–$until)";
}

/// How many days there are in [month]'s month.
int _daysIn(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

DateTime _date(DateTime time) => DateTime(time.year, time.month, time.day);

/// Counted by the calendar, as a day can be 23 or 25 hours long.
DateTime _dayBefore(DateTime day) => DateTime(day.year, day.month, day.day - 1);
DateTime _dayAfter(DateTime day) => DateTime(day.year, day.month, day.day + 1);
