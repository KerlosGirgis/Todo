import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/clock_time.dart';
import 'device_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> onDidReceiveNotification(
      NotificationResponse notificationResponse) async {}

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
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotification,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveNotification,
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

  Future<void> showInstantNotification(String title, String body) async {
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_notification_channel_id',
          'Instant Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails());

    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: 'instant_notification',
    );
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

  Future<void> scheduleDailyNotification(
      int id, String title, String? body, ClockTime scheduledTime) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(
          nextInstanceOfTime(scheduledTime, DateTime.now()), tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel',
          'Daily Notifications',
          channelDescription: 'Daily notification channel',
        ),
      ),
      // At its time every day, by the clock of the time zone it's set in.
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// When the phone's clock next shows [time] after [now]: today, or
  /// tomorrow once today's has gone. Counted by the clock, as a day can be 23
  /// or 25 hours long.
  @visibleForTesting
  static DateTime nextInstanceOfTime(ClockTime time, DateTime now) {
    final today = time.on(now);
    return today.isBefore(now)
        ? time.on(DateTime(now.year, now.month, now.day + 1))
        : today;
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
