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
    bool isHoursSingular = duration.inHours == 1;
    bool isMinutesSingular = duration.inMinutes == 1;
    if (duration.inHours == 0) {
      return "$twoDigitMinutes ${isMinutesSingular ? 'minute' : 'minutes'}";
    } else {
      return "${twoDigits(duration.inHours)} ${isHoursSingular ? 'hour' : 'hours'} , $twoDigitMinutes ${isMinutesSingular ? 'minute' : 'minutes'}";
    }
  }
}
