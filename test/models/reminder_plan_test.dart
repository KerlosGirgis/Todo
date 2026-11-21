import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/recurrence.dart';
import 'package:todo/models/reminder_plan.dart';
import 'package:todo/models/repeat_progress.dart';
import 'package:todo/models/todo_item.dart';

void main() {
  /// Noon on a Wednesday.
  final now = DateTime(2026, 5, 13, 12);
  DateTime may(int day, [int hour = 0]) => DateTime(2026, 5, day, hour);
  const uuid = "u";

  TodoItem repeating(Recurrence rule, {ClockTime? time}) => TodoItem(
    uuid: uuid,
    title: "t",
    time: time ?? const ClockTime(7, 0),
  ).repeatingAs(rule, progress: RepeatProgress(since: may(1)));

  group('a one-time reminder', () {
    TodoItem once(DateTime day, {bool done = false}) => TodoItem(
      uuid: uuid,
      title: "t",
      day: day,
      time: const ClockTime(18, 0),
      reminder: Reminder.once,
      done: done,
    );

    test('is set while it is still to come', () {
      expect(ReminderPlan.of(once(may(13)), now), [
        OnceAlarm(ReminderPlan.idOf(uuid), may(13, 18)),
      ]);
    });

    test('is not set once it has gone, or the task is done', () {
      expect(ReminderPlan.of(once(may(12)), now), isEmpty);
      expect(ReminderPlan.of(once(may(13), done: true), now), isEmpty);
    });
  });

  test('none is set for a task without a time', () {
    final untimed = TodoItem(uuid: uuid, title: "t", reminder: Reminder.daily);
    expect(ReminderPlan.of(untimed, now), isEmpty);
  });

  group('a daily reminder', () {
    final daily = repeating(Recurrence.daily());

    test("repeats from today's time while it's still to come", () {
      expect(ReminderPlan.of(daily, may(13, 5)), [
        RepeatingAlarm(ReminderPlan.idOf(uuid), may(13, 7), RepeatEvery.day),
      ]);
    });

    test("repeats from tomorrow's once today's has gone", () {
      expect(ReminderPlan.of(daily, may(13, 8)), [
        RepeatingAlarm(ReminderPlan.idOf(uuid), may(14, 7), RepeatEvery.day),
      ]);
    });

    test('goes by the clock on a day the clocks change', () {
      // Cairo's go forward an hour as April 30, 2027 begins, so there a day
      // on from 7:00 the day before is 8:00.
      final alarm =
          ReminderPlan.of(daily, DateTime(2027, 4, 29, 8)).single
              as RepeatingAlarm;
      expect(alarm.first, DateTime(2027, 4, 30, 7));
    });
  });

  test('a weekly reminder repeats on each of its days', () {
    final gym = repeating(
      Recurrence.weekly({DateTime.monday, DateTime.thursday}),
      time: const ClockTime(18, 0),
    );
    final ids = ReminderPlan.idsOf(uuid);
    expect(ReminderPlan.of(gym, now), [
      RepeatingAlarm(ids[DateTime.monday], may(18, 18), RepeatEvery.week),
      RepeatingAlarm(ids[DateTime.thursday], may(14, 18), RepeatEvery.week),
    ]);
  });

  test('a monthly reminder repeats from its next day of the month', () {
    final rent = repeating(Recurrence.monthly(31), time: const ClockTime(9, 0));
    expect(ReminderPlan.of(rent, DateTime(2026, 6, 1)), [
      RepeatingAlarm(
        ReminderPlan.idOf(uuid),
        DateTime(2026, 7, 31, 9),
        RepeatEvery.month,
      ),
    ]);
  });

  group('a reminder that stops', () {
    test('repeats by itself while it has many times left', () {
      final course = repeating(Recurrence.daily(until: may(31)));
      expect(ReminderPlan.of(course, now), [
        RepeatingAlarm(ReminderPlan.idOf(uuid), may(14, 7), RepeatEvery.day),
      ]);
    });

    test('is set one time at a time for its last few times', () {
      final course = repeating(Recurrence.daily(until: may(16)));
      final ids = ReminderPlan.idsOf(uuid).skip(8).toList();
      expect(ReminderPlan.of(course, may(13, 5)), [
        OnceAlarm(ids[0], may(13, 7)),
        OnceAlarm(ids[1], may(14, 7)),
        OnceAlarm(ids[2], may(15, 7)),
        OnceAlarm(ids[3], may(16, 7)),
      ]);
      final exactly = repeating(
        Recurrence.daily(until: may(13 + ReminderPlan.lastTimes)),
      );
      expect(ReminderPlan.of(exactly, now), hasLength(ReminderPlan.lastTimes));
      expect(ReminderPlan.of(exactly, now), everyElement(isA<OnceAlarm>()));
    });

    test('is not set at all once its last time has gone', () {
      final course = repeating(Recurrence.daily(until: may(13)));
      expect(ReminderPlan.of(course, now), isEmpty);
      expect(ReminderPlan.of(course, may(20)), isEmpty);
    });
  });

  test("a task's reminders each have an id of their own", () {
    final ids = ReminderPlan.idsOf(uuid);
    expect(ids, hasLength(1 + 7 + ReminderPlan.lastTimes));
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids.first, ReminderPlan.idOf(uuid));
    expect(
      ReminderPlan.idsOf("other").toSet().intersection(ids.toSet()),
      isEmpty,
    );
  });

  test("a reminder's id is the same in every version of Dart: its key's "
      "32-bit FNV-1a hash, signed, as Android takes it", () {
    // The hash's published test vectors.
    expect(ReminderPlan.idOf(""), (0x811c9dc5).toSigned(32));
    expect(ReminderPlan.idOf("a"), (0xe40c292c).toSigned(32));
    expect(ReminderPlan.idOf("foobar"), (0xbf9cf968).toSigned(32));
    for (final id in ReminderPlan.idsOf(
      "3f8e2a9c-1b4d-4e6f-9a7b-2c5d8e1f0a3b",
    )) {
      expect(id, inInclusiveRange(-0x80000000, 0x7fffffff));
    }
  });
}
