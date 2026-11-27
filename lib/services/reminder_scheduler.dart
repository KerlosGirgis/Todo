import '../models/app_lock.dart';
import '../models/reminder_plan.dart';
import '../models/todo_item.dart';
import 'lock_service.dart';
import 'notification_service.dart';

/// The tasks' reminders on the phone: each task's, as its [ReminderPlan]
/// has them, saying which task they're for only while the app isn't
/// locked, as the lock screen and the notification shade would show it to
/// anyone with the phone.
class ReminderScheduler {
  /// [clock] is the time the tasks go by, which tests can set.
  ReminderScheduler({
    NotificationService? notifications,
    LockService? lockService,
    DateTime Function()? clock,
  }) : _notifications = notifications ?? NotificationService(),
       _lockService = lockService ?? LockService(),
       _now = clock ?? DateTime.now;

  final NotificationService _notifications;
  final LockService _lockService;
  final DateTime Function() _now;

  static const _title = "Don't Forget Your Task!";

  /// Whether the phone will show the reminders, once the user has been asked
  /// to let the app post notifications, if they're off: as they turn a
  /// reminder on, when the question makes sense, rather than as the app
  /// starts.
  Future<bool> askToShow() => _notifications.requestPermission();

  /// Sets the reminders [task] needs, if it has any still to come. Those of
  /// a repeating task that it needs no more, as when its last times are set
  /// one by one, or once they've gone, are cancelled.
  Future<void> set(TodoItem task) => _set(task, _isLocked);

  /// Sets [task]'s reminders, as [set] does, with [locked] telling whether
  /// the app is locked, which is asked only when there's one to set.
  Future<void> _set(TodoItem task, Future<bool> Function() locked) async {
    final alarms = ReminderPlan.of(task, _now());
    if (alarms.isNotEmpty) {
      // Which task it is, but not while the app is locked.
      final body = await locked() ? null : task.title;
      for (final alarm in alarms) {
        switch (alarm) {
          case OnceAlarm(:final id, :final at):
            await _notifications.scheduleNotification(id, _title, body, at);
          case RepeatingAlarm(:final id, :final first, :final every):
            await _notifications.scheduleRepeatingNotification(
              id,
              _title,
              body,
              first,
              every,
            );
        }
      }
    }
    if (!task.reminder.repeats) return;
    final kept = {for (final alarm in alarms) alarm.id};
    for (final id in ReminderPlan.idsOf(task.uuid)) {
      if (!kept.contains(id)) await _notifications.cancelNotification(id);
    }
  }

  /// Sets the reminders of each of [tasks], as [set] does: one that can't
  /// be leaves the others to be set all the same. Whether every one was.
  Future<bool> setEach(Iterable<TodoItem> tasks) async {
    // Asked once for them all, rather than for each, as asking reads the
    // phone's secure storage; and only if one of them has a reminder to set.
    Future<bool>? asked;
    Future<bool> locked() => asked ??= _isLocked();
    var allSet = true;
    for (final task in tasks) {
      try {
        await _set(task, locked);
      } catch (e) {
        allSet = false;
      }
    }
    return allSet;
  }

  /// Sets afresh the reminders of those of [tasks] that repeat until a day,
  /// as the days go by: nearing their last day, their last times are set one
  /// by one, so that they stop with them, and once those have gone, they're
  /// off.
  Future<void> setEnding(Iterable<TodoItem> tasks) async {
    await setEach([
      for (final task in tasks)
        if (task.reminder.repeats && task.until != null) task,
    ]);
  }

  /// Cancels the reminders [task] has on the phone: every one a repeating
  /// task's can be, or a one-time reminder.
  Future<void> cancel(TodoItem task) async {
    final ids = task.reminder.repeats
        ? ReminderPlan.idsOf(task.uuid)
        : [ReminderPlan.idOf(task.uuid)];
    for (final id in ids) {
      await _notifications.cancelNotification(id);
    }
  }

  /// Cancels every reminder there is, as tasks restored in place of all the
  /// others take theirs.
  Future<void> cancelAll() => _notifications.cancelAllNotifications();

  /// Brings the reminders up to date as the app starts, given the tasks
  /// [all] reads in, and the tasks [current] as they stand today.
  ///
  /// Reminders set in another time zone, or before reminders went by the
  /// phone's, keep to another clock, and a one-time one from back then goes
  /// off again every year. Ones set under ids made another way can't be
  /// found by their tasks to be cancelled. So they're all set afresh, which
  /// is kept once every one is. Otherwise, while the app is locked, a
  /// reminder set before reminders went by the App Lock, or one whose change
  /// of lock didn't get to it, may still say which task it's for, so they're
  /// all set again. Otherwise only the days have gone by since they were last
  /// set, which [setEnding] goes by.
  Future<void> checkAsAppStarts({
    required Future<List<TodoItem>> Function() all,
    required Iterable<TodoItem> current,
  }) async {
    final timeZone = _notifications.timeZone;
    if (await _notifications.remindersTimeZone() != timeZone ||
        await _notifications.remindersIdVersion() != ReminderPlan.idVersion) {
      await _notifications.cancelPendingNotifications();
      // Until they all are, they're set afresh at each start.
      if (await setEach(await all())) {
        await _notifications.setRemindersTimeZone(timeZone);
        await _notifications.setRemindersIdVersion(ReminderPlan.idVersion);
      }
    } else if (await _lockService.getLock() != AppLock.off) {
      await setEach(await all());
    } else {
      await setEnding(current);
    }
  }

  /// Whether the app is locked, when reminders don't say which task they're
  /// for, as the lock screen and the notification shade would show it to
  /// anyone with the phone.
  Future<bool> _isLocked() async => await _lockService.getLock() != AppLock.off;
}
