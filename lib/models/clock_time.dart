/// A time of day without a date, such as a task's: an [hour] from 0 to 23,
/// and a [minute].
class ClockTime {
  const ClockTime(this.hour, this.minute)
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  /// A time as tasks keep it: "9:30 PM", or "21:30", as the time picker
  /// once wrote it on phones set to a 24-hour clock. Null when there's no
  /// time, or one that won't read as one.
  static ClockTime? tryParse(String text) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$', caseSensitive: false)
        .firstMatch(text.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    switch (match.group(3)?.toUpperCase()) {
      case "PM" when hour != 12:
        hour += 12;
      case "AM" when hour == 12:
        hour = 0;
    }
    if (hour > 23 || minute > 59) return null;
    return ClockTime(hour, minute);
  }

  /// "9:30 PM": how tasks keep a time, and how they show it.
  String get label {
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? "AM" : "PM";
    return "$hour12:${minute.toString().padLeft(2, "0")} $period";
  }

  /// This time on [day].
  DateTime on(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => label;
}
