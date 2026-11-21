import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
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

  group('reminders are set in', () {
    tearDown(() => tz.setLocalLocation(tz.UTC));

    test("the phone's time zone", () async {
      await NotificationService.followPhoneTimeZone(
        device: FakeDevice("Africa/Cairo"),
      );
      expect(NotificationService().timeZone, "Africa/Cairo");
    });

    test("UTC, for a time zone there's no record of", () async {
      await NotificationService.followPhoneTimeZone(
        device: FakeDevice("Mars/Olympus"),
      );
      expect(NotificationService().timeZone, tz.UTC.name);
    });
  });

  test(
    "remembers how the reminders' ids were made, as 0 before it did",
    () async {
      SharedPreferences.setMockInitialValues({});
      final notifications = NotificationService();
      expect(await notifications.remindersIdVersion(), 0);
      await notifications.setRemindersIdVersion(1);
      expect(await notifications.remindersIdVersion(), 1);
    },
  );
}
