import '../../models/clock_time.dart';
import '../../models/recurrence.dart';
import '../../models/todo_item.dart';
import 'date_time_utils.dart';

/// Monday to Friday, and the weekend.
const _workWeek = {1, 2, 3, 4, 5};
const _weekend = {6, 7};

/// The day [task] is for, as of [now]: its own, or the day that stands for
/// it when it comes round on days of the week or of the month. Null for a
/// daily task, which is for every day, and for a task without a day.
DateTime? taskDayOf(TodoItem task, DateTime now) =>
    switch (task.recurrence?.every) {
      null => task.day,
      RepeatEvery.day => null,
      RepeatEvery.week || RepeatEvery.month => task.occurrenceOn(now),
    };

/// When [task] is for, as of [now]: "Today, 9:30 AM", "Tomorrow", "Fri, Oct
/// 24" or "Jan 3, 2027, 9:30 AM", or null when it has neither a date nor a
/// time. A task that comes round on days of the week or the month is for
/// the day that stands for it.
String? taskWhenLabel(TodoItem task, DateTime now) {
  final day = taskDayOf(task, now);
  final time = task.time;
  final parts = [
    if (day != null) DateTimeUtils.friendlyDay(day, now),
    if (time != null) time.label,
  ];
  return parts.isEmpty ? null : parts.join(", ");
}

/// How [recurrence] comes round, in a word or few, for a task's chip:
/// "Daily", "Weekly", "Weekdays", "Weekends", "Mon, Wed, Fri", or "Monthly".
String repeatChipLabel(Recurrence recurrence) {
  final days = recurrence.weekdays;
  return switch (recurrence.every) {
    RepeatEvery.day => "Daily",
    RepeatEvery.month => "Monthly",
    RepeatEvery.week when days.length == 7 => "Daily",
    RepeatEvery.week when _isOnly(days, _workWeek) => "Weekdays",
    RepeatEvery.week when _isOnly(days, _weekend) => "Weekends",
    RepeatEvery.week when days.length == 1 => "Weekly",
    RepeatEvery.week => [
      for (final day in _inOrder(days))
        DateTimeUtils.weekdayName(day, short: true),
    ].join(", "),
  };
}

/// When [recurrence] has a task come round, at [time], as of [now], as a
/// sentence: "Every day at 7:00 AM", "Every Monday at 7:00 AM", "Every Mon,
/// Wed and Fri at 7:00 AM", "Every month on the 20th at 9:00 AM", with
/// "until tomorrow" after it when it stops.
String repeatSentence(Recurrence recurrence, ClockTime time, DateTime now) {
  final days = recurrence.weekdays;
  final when = switch (recurrence.every) {
    RepeatEvery.day => "Every day",
    RepeatEvery.month =>
      "Every month on the ${DateTimeUtils.ordinal(recurrence.monthDay!)}",
    RepeatEvery.week when days.length == 7 => "Every day",
    RepeatEvery.week when _isOnly(days, _workWeek) => "Every weekday",
    RepeatEvery.week =>
      "Every ${_listed([for (final day in _inOrder(days)) DateTimeUtils.weekdayName(day, short: days.length > 2)])}",
  };
  final until = recurrence.until;
  final end = until == null
      ? ""
      : " until ${DateTimeUtils.dayInSentence(until, now)}";
  return "$when at ${time.label}$end";
}

/// How many times in a row a task that comes round as [recurrence] has it
/// has been done, [count]: "5-day streak", "3-week streak", "2-month
/// streak", or "4 in a row" for one that comes round on a few days a week.
String streakLabel(
  Recurrence recurrence,
  int count,
) => switch (recurrence.every) {
  RepeatEvery.day => "$count-day streak",
  RepeatEvery.month => "$count-month streak",
  RepeatEvery.week when recurrence.weekdays.length == 7 => "$count-day streak",
  RepeatEvery.week when recurrence.weekdays.length == 1 => "$count-week streak",
  RepeatEvery.week => "$count in a row",
};

/// When [recurrence] stops, for a task's chip, as of [now]: "Until Oct 24",
/// "Ends Today", or "Ended" once its last time has gone. Null while it
/// repeats for good.
String? repeatEndLabel(Recurrence recurrence, DateTime now) {
  final until = recurrence.until;
  if (until == null) return null;
  if (recurrence.hasEndedBy(now)) return "Ended";
  if (until == DateTime(now.year, now.month, now.day)) return "Ends Today";
  return "Until ${DateTimeUtils.shortDay(until, now)}";
}

bool _isOnly(Set<int> days, Set<int> these) =>
    days.length == these.length && days.containsAll(these);

/// [days] from Monday on.
List<int> _inOrder(Set<int> days) => days.toList()..sort();

/// "Mon", "Mon and Wed", or "Mon, Wed and Fri".
String _listed(List<String> words) => words.length == 1
    ? words.single
    : "${words.take(words.length - 1).join(", ")} and ${words.last}";
