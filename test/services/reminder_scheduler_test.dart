import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/reminder_plan.dart';
import 'package:todo/models/repeat_progress.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/services/reminder_scheduler.dart';

import '../view_model/tasks_view_model_test.dart'
    show FakeLock, FakeNotifications;

void main() {
  /// Noon on a Wednesday.
  final now = DateTime(2026, 5, 13, 12);
  late FakeNotifications notifications;
  late FakeLock lock;
  late ReminderScheduler reminders;

  setUp(() {
    notifications = FakeNotifications();
    lock = FakeLock();
    reminders = ReminderScheduler(
      notifications: notifications,
      lockService: lock,
      clock: () => now,
    );
  });

  final call = TodoItem(
    uuid: "call",
    title: "Call",
    day: DateTime(2026, 5, 13),
    time: const ClockTime(18, 0),
    reminder: Reminder.once,
  );
  final stretch = TodoItem(
    uuid: "stretch",
    title: "Stretch",
    time: const ClockTime(7, 0),
    reminder: Reminder.daily,
  );

  /// A daily task with three times left: from tomorrow until Saturday.
  final course = TodoItem(
    uuid: "course",
    title: "Course",
    time: const ClockTime(7, 0),
    reminder: Reminder.daily,
    until: DateTime(2026, 5, 16),
    progress: RepeatProgress(since: DateTime(2026, 5, 1)),
  );

  test("sets a task's reminder, naming the task only while the app isn't "
      "locked", () async {
    await reminders.set(call);
    final id = ReminderPlan.idOf("call");
    expect(notifications.once, {id: DateTime(2026, 5, 13, 18)});
    expect(notifications.bodies[id], "Call");

    lock.lock = AppLock.password;
    await reminders.set(call);
    expect(notifications.bodies[id], isNull);
  });

  test("cancels a task's reminders, one-time or repeating", () async {
    await reminders.setEach([call, stretch]);
    expect(notifications.daily, {
      ReminderPlan.idOf("stretch"): const ClockTime(7, 0),
    });
    await reminders.cancel(call);
    await reminders.cancel(stretch);
    expect(notifications.once, isEmpty);
    expect(notifications.repeating, isEmpty);
  });

  test("says whether every reminder could be set", () async {
    expect(await reminders.setEach([call, stretch]), isTrue);
    notifications.failSchedules = true;
    expect(await reminders.setEach([call, stretch]), isFalse);
  });

  test("reads the App Lock once for every reminder set together, and not at "
      "all with none to set", () async {
    await reminders.setEach([call, stretch, course]);
    expect(lock.reads, 1);
    expect(notifications.bodies.values.toSet(), {"Call", "Stretch", "Course"});

    lock.reads = 0;
    await reminders.setEach([TodoItem(uuid: "shop", title: "Shop")]);
    expect(lock.reads, 0);

    // Locked, none says which task it's for.
    lock.lock = AppLock.password;
    await reminders.setEach([call, stretch]);
    expect(lock.reads, 1);
    expect(notifications.bodies[ReminderPlan.idOf("call")], isNull);
    expect(notifications.bodies[ReminderPlan.idOf("stretch")], isNull);
  });

  group('as the app starts', () {
    test("sets every reminder afresh when they were set another way, and "
        "keeps how once they all are", () async {
      notifications
        ..idVersion = 0
        ..once[1001] = DateTime(2026, 5, 13, 18);
      await reminders.checkAsAppStarts(
        all: () async => [call, stretch],
        current: const [],
      );
      expect(notifications.once, {
        ReminderPlan.idOf("call"): DateTime(2026, 5, 13, 18),
      });
      expect(notifications.daily, {
        ReminderPlan.idOf("stretch"): const ClockTime(7, 0),
      });
      expect(notifications.idVersion, ReminderPlan.idVersion);
      expect(notifications.setIn, "Africa/Cairo");
    });

    test("otherwise sets the ones that stop on a day, or every one while "
        "the app is locked", () async {
      var reads = 0;
      Future<List<TodoItem>> all() async {
        reads++;
        return [call, course];
      }

      await reminders.checkAsAppStarts(all: all, current: [call, course]);
      expect(reads, 0);
      expect(
        notifications.once.keys.toSet(),
        ReminderPlan.idsOf("course").skip(8).take(3).toSet(),
      );

      lock.lock = AppLock.fingerprint;
      await reminders.checkAsAppStarts(all: all, current: [call, course]);
      expect(reads, 1);
      expect(notifications.once, contains(ReminderPlan.idOf("call")));
    });
  });
}
