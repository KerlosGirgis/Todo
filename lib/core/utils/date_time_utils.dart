import 'package:intl/intl.dart';

class DateTimeUtils {
  /// [duration] in words, to the minute, leaving out what's none: "1 day,
  /// 2 hours, 5 minutes", "3 hours", or "less than a minute".
  static String durationToString(Duration duration) {
    String count(int n, String unit) => "$n $unit${n == 1 ? "" : "s"}";
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final parts = [
      if (days > 0) count(days, "day"),
      if (hours > 0) count(hours, "hour"),
      if (minutes > 0) count(minutes, "minute"),
    ];
    return parts.isEmpty ? "less than a minute" : parts.join(", ");
  }

  /// "Today", "Tomorrow", "Yesterday", "Fri, Oct 24", or "Jan 3, 2027" in
  /// another year.
  static String friendlyDay(DateTime date, DateTime now) =>
      switch (_daysFrom(now, date)) {
        0 => "Today",
        1 => "Tomorrow",
        -1 => "Yesterday",
        _ => _dateLabel(date, now),
      };

  /// [friendlyDay] as it reads within a sentence: "today", "tomorrow",
  /// "yesterday", "Fri, Oct 24", or "Jan 3, 2027" in another year.
  static String dayInSentence(DateTime date, DateTime now) =>
      switch (_daysFrom(now, date)) {
        0 => "today",
        1 => "tomorrow",
        -1 => "yesterday",
        _ => _dateLabel(date, now),
      };

  /// "Oct 24", or "Jan 3, 2027" in another year: short, for a chip.
  static String shortDay(DateTime date, DateTime now) => date.year == now.year
      ? DateFormat("MMM d").format(date)
      : DateFormat("MMM d, y").format(date);

  /// [day] of a month as it's said: "1st", "2nd", "3rd", "4th", "11th",
  /// "22nd".
  static String ordinal(int day) {
    final suffix = switch (day % 100) {
      11 || 12 || 13 => "th",
      _ => switch (day % 10) {
        1 => "st",
        2 => "nd",
        3 => "rd",
        _ => "th",
      },
    };
    return "$day$suffix";
  }

  /// The name of [weekday], from [DateTime.monday] to [DateTime.sunday]:
  /// "Monday", or "Mon" when [short].
  static String weekdayName(int weekday, {bool short = false}) =>
      // January 2024 began on a Monday.
      (short ? DateFormat.E() : DateFormat.EEEE()).format(
        DateTime(2024, 1, weekday),
      );

  static String _dateLabel(DateTime date, DateTime now) => date.year == now.year
      ? DateFormat("EEE, MMM d").format(date)
      : DateFormat("MMM d, y").format(date);

  /// How many days [date] is from [now]'s day, counted in UTC, where every
  /// day is 24 hours long.
  static int _daysFrom(DateTime now, DateTime date) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
}
