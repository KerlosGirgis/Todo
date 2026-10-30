import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/daily_progress.dart';
import 'package:todo/models/todo_item.dart';

void main() {
  group('ClockTime', () {
    test('reads the 12-hour times tasks keep', () {
      expect(ClockTime.tryParse("9:30 PM"), const ClockTime(21, 30));
      expect(ClockTime.tryParse("12:05 AM"), const ClockTime(0, 5));
      expect(ClockTime.tryParse("12:00 PM"), const ClockTime(12, 0));
      expect(ClockTime.tryParse(" 7:00am "), const ClockTime(7, 0));
    });

    test('reads the 24-hour times older versions wrote', () {
      expect(ClockTime.tryParse("21:30"), const ClockTime(21, 30));
      expect(ClockTime.tryParse("0:15"), const ClockTime(0, 15));
    });

    test('has no time for an empty or unreadable one', () {
      expect(ClockTime.tryParse(""), isNull);
      expect(ClockTime.tryParse("noon"), isNull);
      expect(ClockTime.tryParse("25:00"), isNull);
      expect(ClockTime.tryParse("9:75 AM"), isNull);
    });

    test('labels a time as tasks keep it', () {
      expect(const ClockTime(21, 5).label, "9:05 PM");
      expect(const ClockTime(0, 0).label, "12:00 AM");
      expect(const ClockTime(12, 30).label, "12:30 PM");
    });
  });

  group('TodoItem', () {
    final stored = {
      'id': 4,
      'title': "Water the plants",
      'desc': "The ferns",
      'status': 0,
      'date': "2026-05-13",
      'time': "6:00 PM",
      'uuid': "u-1",
      'notification': 1,
      'since': "",
      'doneDays': "",
    };

    test('reads the stored columns', () {
      final task = TodoItem.fromMap(stored);
      expect(task.id, 4);
      expect(task.done, isFalse);
      expect(task.day, DateTime(2026, 5, 13));
      expect(task.time, const ClockTime(18, 0));
      expect(task.reminder, Reminder.once);
    });

    test('writes the columns back exactly as they were', () {
      expect(TodoItem.fromMap(stored).toMap(), {...stored}..remove('id'));
    });

    test('writes no day or time as empty strings', () {
      final map = TodoItem(uuid: "u", title: "t").toMap();
      expect(map['date'], "");
      expect(map['time'], "");
      expect(map['status'], 0);
      expect(map['notification'], 0);
      expect(map['since'], "");
      expect(map['doneDays'], "");
    });

    test("reads and writes a daily task's days", () {
      final daily = {
        ...stored,
        'date': "",
        'notification': 2,
        'since': "2026-05-01",
        'doneDays': "2026-05-11,2026-05-13",
      };
      final task = TodoItem.fromMap(daily);
      expect(task.isDaily, isTrue);
      expect(task.progress.since, DateTime(2026, 5, 1));
      expect(task.progress.doneDays,
          {DateTime(2026, 5, 11), DateTime(2026, 5, 13)});
      expect(task.toMap(), {...daily}..remove('id'));
    });

    test("a daily task is done only on the days it was done", () {
      final task = TodoItem(
        uuid: "u",
        title: "Stretch",
        time: const ClockTime(7, 0),
        reminder: Reminder.daily,
        done: true,
        progress: DailyProgress(
            since: DateTime(2026, 5, 1), doneDays: [DateTime(2026, 5, 12)]),
      );
      expect(task.asOf(DateTime(2026, 5, 12, 23, 59)).done, isTrue);
      expect(task.asOf(DateTime(2026, 5, 13)).done, isFalse);
      final once = TodoItem(uuid: "u", title: "t", done: true);
      expect(once.asOf(DateTime(2026, 5, 13)).done, isTrue);
    });

    test('writes a 24-hour time the way it now keeps them', () {
      final task = TodoItem.fromMap({...stored, 'time': "21:30"});
      expect(task.toMap()['time'], "9:30 PM");
    });

    test('a daily task has no day', () {
      final task = TodoItem.fromMap({...stored, 'notification': 2});
      expect(task.reminder, Reminder.daily);
      expect(task.day, isNull);
      expect(task.toMap()['date'], "");
      expect(
        TodoItem.fromMap(stored).copyWith(reminder: Reminder.daily).day,
        isNull,
      );
    });

    test('reads a backup from before tasks had days, times or reminders', () {
      final task =
          TodoItem.fromMap({'title': "Old", 'desc': "", 'status': 1});
      expect(task.done, isTrue);
      expect(task.day, isNull);
      expect(task.time, isNull);
      expect(task.reminder, Reminder.none);
      expect(task.uuid, "");
      expect(task.progress.since, isNull);
      expect(task.progress.doneDays, isEmpty);
    });

    test('is due at its time, or as its day ends', () {
      final day = DateTime(2026, 5, 13);
      expect(
        TodoItem(uuid: "u", title: "t", day: day, time: const ClockTime(9, 0))
            .due,
        DateTime(2026, 5, 13, 9),
      );
      expect(TodoItem(uuid: "u", title: "t", day: day).due,
          DateTime(2026, 5, 14));
      expect(
          TodoItem(uuid: "u", title: "t", time: const ClockTime(9, 0)).due,
          isNull);
    });

    test('is past due once its due time has gone', () {
      final task = TodoItem(
          uuid: "u",
          title: "t",
          day: DateTime(2026, 5, 13),
          time: const ClockTime(9, 0));
      expect(task.isPastDue(DateTime(2026, 5, 13, 8, 59)), isFalse);
      expect(task.isPastDue(DateTime(2026, 5, 13, 9, 1)), isTrue);
      expect(TodoItem(uuid: "u", title: "t").isPastDue(DateTime(3000)),
          isFalse);
    });
  });

  group('DailyProgress', () {
    final progress = DailyProgress(
      since: DateTime(2026, 5, 8, 15, 30),
      doneDays: [
        DateTime(2026, 5, 9),
        DateTime(2026, 5, 11, 7),
        DateTime(2026, 5, 12),
      ],
    );
    // A Wednesday, like the view model tests' day.
    final today = DateTime(2026, 5, 13, 12);

    test('keeps days, not times', () {
      expect(progress.since, DateTime(2026, 5, 8));
      expect(progress.isDoneOn(DateTime(2026, 5, 11, 22)), isTrue);
      expect(progress.isDoneOn(DateTime(2026, 5, 10)), isFalse);
    });

    test('writes its days oldest first, and reads them back', () {
      final map = DailyProgress(since: DateTime(2026, 5, 8), doneDays: [
        DateTime(2026, 5, 12),
        DateTime(2026, 5, 9),
      ]).toMap();
      expect(map, {'since': "2026-05-08", 'doneDays': "2026-05-09,2026-05-12"});
      final read = DailyProgress.fromMap(map);
      expect(read.since, DateTime(2026, 5, 8));
      expect(read.doneDays, {DateTime(2026, 5, 9), DateTime(2026, 5, 12)});
    });

    test('skips days that will not read as days', () {
      final read = DailyProgress.fromMap(
          {'since': "soon", 'doneDays': "2026-05-09,,later, 2026-05-12"});
      expect(read.since, isNull);
      expect(read.doneDays, {DateTime(2026, 5, 9), DateTime(2026, 5, 12)});
    });

    test('marks a day done, or not', () {
      final done = progress.withDay(today, done: true);
      expect(done.isDoneOn(today), isTrue);
      expect(done.since, progress.since);
      final undone = done.withDay(DateTime(2026, 5, 12, 8), done: false);
      expect(undone.isDoneOn(DateTime(2026, 5, 12)), isFalse);
      expect(undone.isDoneOn(today), isTrue);
      expect(progress.isDoneOn(today), isFalse);
    });

    test('says how each day went', () {
      DayStatus on(int day) => progress.statusOf(DateTime(2026, 5, day), today);
      expect(on(7), DayStatus.untracked);
      expect(on(8), DayStatus.missed);
      expect(on(9), DayStatus.done);
      expect(on(10), DayStatus.missed);
      expect(on(12), DayStatus.done);
      expect(on(13), DayStatus.due);
      expect(on(14), DayStatus.untracked);
      expect(progress.withDay(today, done: true).statusOf(today, today),
          DayStatus.done);
    });

    test('counts no day missed before it knows when it began', () {
      final unknown = DailyProgress(doneDays: [DateTime(2026, 5, 12)]);
      expect(
          unknown.statusOf(DateTime(2026, 5, 11), today), DayStatus.untracked);
      expect(unknown.statusOf(DateTime(2026, 5, 12), today), DayStatus.done);
      expect(unknown.statusOf(today, today), DayStatus.due);
    });

    test('starts counting again from a new day, keeping the days done', () {
      final restarted = progress.startingOn(DateTime(2026, 5, 12, 9));
      expect(restarted.since, DateTime(2026, 5, 12));
      expect(restarted.statusOf(DateTime(2026, 5, 10), today),
          DayStatus.untracked);
      expect(restarted.statusOf(DateTime(2026, 5, 9), today), DayStatus.done);
    });

    test('a streak runs up to today, or to yesterday while today is to do', () {
      expect(progress.streak(today), 2);
      expect(progress.withDay(today, done: true).streak(today), 3);
      expect(progress.streak(DateTime(2026, 5, 14)), 0);
      expect(DailyProgress.none.streak(today), 0);
    });

    test('a streak runs across the end of a month', () {
      final run = DailyProgress(doneDays: [
        DateTime(2026, 2, 27),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 1),
      ]);
      expect(run.streak(DateTime(2026, 3, 2)), 3);
    });
  });
}
