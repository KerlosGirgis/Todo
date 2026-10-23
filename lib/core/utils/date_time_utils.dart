import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

class DateTimeUtils {
  static DateTime stringToDateTime(String date, String time12Hour) {
    DateFormat format12Hour = DateFormat('h:mm a');
    DateTime dateTime = format12Hour.parse(time12Hour);
    DateFormat format24Hour = DateFormat('HH:mm:ss');
    String time24Hour = format24Hour.format(dateTime);
    return DateTime.parse("$date $time24Hour");
  }

  static String durationToString(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    bool isDaysSingular = duration.inDays == 1;
    bool isHoursSingular = duration.inHours == 1;
    bool isMinutesSingular = duration.inMinutes == 1;
    if(duration.inDays > 0){
      return "${duration.inDays} ${isDaysSingular ? 'day' : 'days'} , ${twoDigits(duration.inHours.remainder(24))} ${isHoursSingular ? 'hour' : 'hours'} , $twoDigitMinutes ${isMinutesSingular ? 'minute' : 'minutes'}";
    }
    if (duration.inHours == 0) {
      return "$twoDigitMinutes ${isMinutesSingular ? 'minute' : 'minutes'}";
    } else {
      return "${twoDigits(duration.inHours)} ${isHoursSingular ? 'hour' : 'hours'} , $twoDigitMinutes ${isMinutesSingular ? 'minute' : 'minutes'}";
    }
  }

  static TimeOfDay parseTime(String timeStr) {
    final regex =
    RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final match = regex.firstMatch(timeStr.trim());

    if (match != null) {
      int hour = int.parse(match.group(1)!);
      int minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();

      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      return TimeOfDay(hour: hour, minute: minute);
    } else {
      throw FormatException(
          "Invalid time format. Expected format is 'hh:mm AM/PM'.");
    }
  }

  /// When a task with [date] ("2026-05-13") and [time] is due: at its time,
  /// or at the end of its day when it has none. Null when it has no date.
  static DateTime? dueDate(String date, String time) {
    final day = DateTime.tryParse(date);
    if (day == null) return null;
    final timeOfDay = tryParseTime(time);
    return timeOfDay == null
        ? DateTime(day.year, day.month, day.day + 1)
        : DateTime(
            day.year, day.month, day.day, timeOfDay.hour, timeOfDay.minute);
  }

  /// [parseTime], or a time from a 24-hour clock such as "21:30", which is
  /// how the time picker used to write times on phones set to one. Null when
  /// there's no time, or one that won't parse.
  static TimeOfDay? tryParseTime(String timeStr) {
    if (timeStr.isEmpty) return null;
    try {
      return parseTime(timeStr);
    } on FormatException {
      final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(timeStr.trim());
      if (match == null) return null;
      return TimeOfDay(
          hour: int.parse(match.group(1)!), minute: int.parse(match.group(2)!));
    }
  }

  /// "9:30 AM", the form [parseTime] and [stringToDateTime] read, whichever
  /// clock the phone shows.
  static String formatTime(TimeOfDay time) =>
      DateFormat('h:mm a').format(DateTime(2000, 1, 1, time.hour, time.minute));

  /// "Today", "Tomorrow", "Yesterday", "Fri, Oct 24", or "Jan 3, 2027" in
  /// another year.
  static String friendlyDay(DateTime date, DateTime now) {
    // Counted in UTC, where every day is 24 hours long.
    final days = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
    return switch (days) {
      0 => "Today",
      1 => "Tomorrow",
      -1 => "Yesterday",
      _ when date.year == now.year => DateFormat("EEE, MMM d").format(date),
      _ => DateFormat("MMM d, y").format(date),
    };
  }
}
