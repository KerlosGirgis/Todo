import 'package:flutter/material.dart';
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

}
