import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/recurrence.dart';
import 'device_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings("@mipmap/launcher_icon");
    const DarwinInitializationSettings iOSInitializationSettings =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitializationSettings,
      iOS: iOSInitializationSettings,
    );
    // A tap on a reminder only opens the app, so there's no handler for it.
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Sets reminders in the phone's time zone, such as "Africa/Cairo", rather
  /// than UTC, so that a daily one keeps to the phone's clock as it changes
  /// for summer time. For once the time zones are read in, as that sets UTC.
  static Future<void> followPhoneTimeZone({DeviceService? device}) async {
    try {
      final name = await (device ?? DeviceService()).timeZone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      // One there's no record of: they stay in UTC.
    }
  }

  /// The time zone reminders are set in.
  String get timeZone => tz.local.name;

  static const _timeZoneKey = 'reminders.timeZone';

  /// The time zone the reminders were last all set in, or null if they were
  /// set before reminders went by the phone's.
  Future<String?> remindersTimeZone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_timeZoneKey);
  }

  Future<void> setRemindersTimeZone(String timeZone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timeZoneKey, timeZone);
  }

  static const _idVersionKey = 'reminders.idVersion';

  /// How the ids of the reminders were made when they were last all set,
  /// as `ReminderPlan.idVersion` has it, or 0 if that was before it was kept.
  Future<int> remindersIdVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_idVersionKey) ?? 0;
  }

  Future<void> setRemindersIdVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_idVersionKey, version);
  }

  Future<void> scheduleNotification(
      int id, String title, String? body, DateTime scheduledTime) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminder Channel',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      // Matching nothing, so it goes off once: matching its date and time
      // would have it go off again on that day every year.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Sets a reminder that goes off at [first], then at that time again
  /// [every] day, every week on that day, or every month on that day, by the
  /// clock of the time zone it's set in. A monthly one skips the months
  /// without its day.
  Future<void> scheduleRepeatingNotification(int id, String title, String? body,
      DateTime first, RepeatEvery every) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(first, tz.local),
      notificationDetails: NotificationDetails(
        android: switch (every) {
          RepeatEvery.day => const AndroidNotificationDetails(
              'daily_channel',
              'Daily Notifications',
              channelDescription: 'Daily notification channel',
            ),
          RepeatEvery.week => const AndroidNotificationDetails(
              'weekly_channel',
              'Weekly Notifications',
              channelDescription: 'Weekly notification channel',
            ),
          RepeatEvery.month => const AndroidNotificationDetails(
              'monthly_channel',
              'Monthly Notifications',
              channelDescription: 'Monthly notification channel',
            ),
        },
      ),
      matchDateTimeComponents: switch (every) {
        RepeatEvery.day => DateTimeComponents.time,
        RepeatEvery.week => DateTimeComponents.dayOfWeekAndTime,
        RepeatEvery.month => DateTimeComponents.dayOfMonthAndTime,
      },
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Cancels every reminder still to go off, but none already showing.
  Future<void> cancelPendingNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAllPendingNotifications();
  }
}
