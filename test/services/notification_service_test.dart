import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:todo/models/clock_time.dart';
import 'package:todo/services/device_service.dart';
import 'package:todo/services/notification_service.dart';

/// A phone in the time zone [zone].
class FakeDevice extends DeviceService {
  FakeDevice(this.zone);

  final String zone;

  @override
  Future<String> timeZone() async => zone;
}

void main() {
  setUpAll(tz.initializeTimeZones);

  group("a daily reminder's next time", () {
    DateTime nextSeven(DateTime now) =>
        NotificationService.nextInstanceOfTime(const ClockTime(7, 0), now);

    test('is today while its time is still to come', () {
      expect(nextSeven(DateTime(2026, 10, 30, 5)), DateTime(2026, 10, 30, 7));
    });

    test('is tomorrow once it has gone', () {
      expect(nextSeven(DateTime(2026, 10, 30, 8)), DateTime(2026, 10, 31, 7));
    });

    test('is by the clock on a day the clocks change', () {
      // Cairo's go forward an hour as April 30, 2027 begins, so there a day
      // on from 7:00 the day before is 8:00.
      expect(nextSeven(DateTime(2027, 4, 29, 8)), DateTime(2027, 4, 30, 7));
    });
  });

  group('reminders are set in', () {
    tearDown(() => tz.setLocalLocation(tz.UTC));

    test("the phone's time zone", () async {
      await NotificationService.followPhoneTimeZone(
          device: FakeDevice("Africa/Cairo"));
      expect(NotificationService().timeZone, "Africa/Cairo");
    });

    test("UTC, for a time zone there's no record of", () async {
      await NotificationService.followPhoneTimeZone(
          device: FakeDevice("Mars/Olympus"));
      expect(NotificationService().timeZone, tz.UTC.name);
    });
  });
}
