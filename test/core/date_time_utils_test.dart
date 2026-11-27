import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/utils/date_time_utils.dart';

void main() {
  group('a duration in words', () {
    test("names each part, without the ones that are none", () {
      expect(
        DateTimeUtils.durationToString(
          const Duration(days: 1, hours: 2, minutes: 5),
        ),
        "1 day, 2 hours, 5 minutes",
      );
      expect(
        DateTimeUtils.durationToString(const Duration(hours: 6)),
        "6 hours",
      );
      expect(
        DateTimeUtils.durationToString(const Duration(days: 2, minutes: 30)),
        "2 days, 30 minutes",
      );
    });

    test("counts one of each as one", () {
      expect(
        DateTimeUtils.durationToString(
          const Duration(days: 1, hours: 1, minutes: 1),
        ),
        "1 day, 1 hour, 1 minute",
      );
    });

    test("is to the minute", () {
      expect(
        DateTimeUtils.durationToString(
          const Duration(hours: 23, minutes: 58, seconds: 59),
        ),
        "23 hours, 58 minutes",
      );
      expect(
        DateTimeUtils.durationToString(const Duration(seconds: 40)),
        "less than a minute",
      );
    });
  });
}
