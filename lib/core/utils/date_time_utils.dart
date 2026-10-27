import 'package:intl/intl.dart';

class DateTimeUtils {
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
