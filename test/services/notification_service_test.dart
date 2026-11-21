import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz.initializeTimeZones);

  group('asking to post notifications', () {
    /// The plugin's channel to the phone.
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    /// What the app asked the phone, in order; whether the app's
    /// notifications are on; and whether the user lets them be when asked.
    late List<String> calls;
    late bool enabled;
    late bool grants;

    setUp(() {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      calls = [];
      enabled = false;
      grants = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'initialize':
            return true;
          case 'areNotificationsEnabled':
            return enabled;
          case 'requestNotificationsPermission':
            enabled = grants;
            return grants;
        }
        return null;
      });
    });

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test("isn't done as the app starts, before it's shown anything", () async {
      await NotificationService.init();
      expect(calls, ['initialize']);
    });

    test("is done while they're off, and tells what the user said", () async {
      expect(await NotificationService().requestPermission(), isTrue);
      expect(calls, [
        'areNotificationsEnabled',
        'requestNotificationsPermission',
        'areNotificationsEnabled',
      ]);

      // On now, so not asked again.
      calls.clear();
      expect(await NotificationService().requestPermission(), isTrue);
      expect(calls, ['areNotificationsEnabled']);
    });

    test("tells when the user won't let them be on", () async {
      grants = false;
      expect(await NotificationService().requestPermission(), isFalse);
    });
  });

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
