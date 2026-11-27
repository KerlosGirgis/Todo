import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/recurrence.dart';
import 'package:todo/models/repeat_progress.dart';
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

  final stored = {
    'id': 4,
    'title': "Water the plants",
    'desc': "The ferns",
    'status': 0,
    'date': "2026-05-13",
    'time': "6:00 PM",
    'uuid': "u-1",
    'notification': 1,
    'weekdays': "",
    'monthDay': 0,
    'until': "",
    'since': "",
    'doneDays': "",
    'parent': "",
    'folded': 0,
  };

  group('TodoItem', () {
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
      expect(map['weekdays'], "");
      expect(map['monthDay'], 0);
      expect(map['until'], "");
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
      expect(task.reminder, Reminder.daily);
      expect(task.progress.since, DateTime(2026, 5, 1));
      expect(task.progress.doneDays, {
        DateTime(2026, 5, 11),
        DateTime(2026, 5, 13),
      });
      expect(task.toMap(), {...daily}..remove('id'));
    });

    test("a daily task is done only on the days it was done", () {
      final task = TodoItem(
        uuid: "u",
        title: "Stretch",
        time: const ClockTime(7, 0),
        reminder: Reminder.daily,
        done: true,
        progress: RepeatProgress(
          since: DateTime(2026, 5, 1),
          doneDays: [DateTime(2026, 5, 12)],
        ),
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
      final task = TodoItem.fromMap({'title': "Old", 'desc': "", 'status': 1});
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
        TodoItem(
          uuid: "u",
          title: "t",
          day: day,
          time: const ClockTime(9, 0),
        ).due,
        DateTime(2026, 5, 13, 9),
      );
      expect(
        TodoItem(uuid: "u", title: "t", day: day).due,
        DateTime(2026, 5, 14),
      );
      expect(
        TodoItem(uuid: "u", title: "t", time: const ClockTime(9, 0)).due,
        isNull,
      );
    });

    test('is past due once its due time has gone', () {
      final task = TodoItem(
        uuid: "u",
        title: "t",
        day: DateTime(2026, 5, 13),
        time: const ClockTime(9, 0),
      );
      expect(task.isPastDue(DateTime(2026, 5, 13, 8, 59)), isFalse);
      expect(task.isPastDue(DateTime(2026, 5, 13, 9, 1)), isTrue);
      expect(
        TodoItem(uuid: "u", title: "t").isPastDue(DateTime(3000)),
        isFalse,
      );
    });

    group('is due as of a day', () {
      // A Wednesday.
      final today = DateTime(2026, 5, 13);

      test('when it is due, if it is for a day', () {
        final day = DateTime(2026, 5, 20);
        TodoItem on(DateTime? day, [ClockTime? time]) =>
            TodoItem(uuid: "u", title: "t", day: day, time: time);
        expect(
          on(day, const ClockTime(9, 0)).dueAsOf(today),
          DateTime(2026, 5, 20, 9),
        );
        // As its day ends, without a time.
        expect(on(day).dueAsOf(today), DateTime(2026, 5, 21));
        expect(on(null).dueAsOf(today), isNull);
      });

      test('at its time on the day that stands for it, if it repeats', () {
        TodoItem repeating(
          Reminder reminder, {
          Set<int> weekdays = const {},
          int? monthDay,
        }) => TodoItem(
          uuid: "u",
          title: "t",
          time: const ClockTime(18, 0),
          reminder: reminder,
          weekdays: weekdays,
          monthDay: monthDay,
          progress: RepeatProgress(since: DateTime(2026, 5, 1)),
        );
        expect(
          repeating(Reminder.daily).dueAsOf(today),
          DateTime(2026, 5, 13, 18),
        );
        // The Monday just gone stands for it until the next one.
        expect(
          repeating(
            Reminder.weekly,
            weekdays: {DateTime.monday},
          ).dueAsOf(today),
          DateTime(2026, 5, 11, 18),
        );
        // Before its first time, that one.
        expect(
          repeating(Reminder.monthly, monthDay: 20).dueAsOf(today),
          DateTime(2026, 5, 20, 18),
        );
        // Not one that never comes round.
        final ended = TodoItem(
          uuid: "u",
          title: "t",
          time: const ClockTime(18, 0),
          reminder: Reminder.monthly,
          monthDay: 31,
          until: DateTime(2026, 5, 2),
          progress: RepeatProgress(since: DateTime(2026, 5, 1)),
        );
        expect(ended.dueAsOf(today), isNull);
      });
    });
  });

  group('weekly and monthly tasks', () {
    test("read and write their days, and when they stop", () {
      final weekly = {
        ...stored,
        'date': "",
        'notification': 3,
        'weekdays': "1,3,5",
        'until': "2026-06-30",
        'since': "2026-05-01",
        'doneDays': "2026-05-11",
      };
      final task = TodoItem.fromMap(weekly);
      expect(task.reminder, Reminder.weekly);
      expect(task.weekdays, {1, 3, 5});
      expect(task.until, DateTime(2026, 6, 30));
      expect(
        task.recurrence,
        Recurrence.weekly(
          {1, 3, 5},
          since: DateTime(2026, 5, 1),
          until: DateTime(2026, 6, 30),
        ),
      );
      expect(task.toMap(), {...weekly}..remove('id'));

      final monthly = {
        ...weekly,
        'notification': 4,
        'weekdays': "",
        'monthDay': 20,
      };
      final read = TodoItem.fromMap(monthly);
      expect(read.monthDay, 20);
      expect(read.toMap(), {...monthly}..remove('id'));
    });

    test('keep only what their reminder goes by, and no day', () {
      final task = TodoItem(
        uuid: "u",
        title: "t",
        day: DateTime(2026, 5, 20),
        reminder: Reminder.weekly,
        weekdays: {1, 9},
        monthDay: 3,
        until: DateTime(2026, 6, 1, 15),
      );
      expect(task.day, isNull);
      expect(task.weekdays, {1});
      expect(task.monthDay, isNull);
      expect(task.until, DateTime(2026, 6, 1));
      final once = task.copyWith(reminder: Reminder.once);
      expect(once.weekdays, isEmpty);
      expect(once.until, isNull);
      expect(once.repeats, isFalse);
    });

    test('do not repeat without the days they go by', () {
      expect(
        TodoItem(uuid: "u", title: "t", reminder: Reminder.weekly).repeats,
        isFalse,
      );
      expect(
        TodoItem(uuid: "u", title: "t", reminder: Reminder.monthly).repeats,
        isFalse,
      );
      expect(
        TodoItem.fromMap({...stored, 'notification': 4, 'monthDay': 32})
            .repeats,
        isFalse,
      );
    });

    // Mondays and Thursdays, since Monday, May 11.
    final gym = TodoItem(
      uuid: "u",
      title: "Gym",
      time: const ClockTime(18, 0),
      reminder: Reminder.weekly,
      weekdays: {DateTime.monday, DateTime.thursday},
      progress: RepeatProgress(since: DateTime(2026, 5, 11)),
    );

    test('stand for their last time until the next one comes', () {
      // Wednesday the 13th: Monday's still stands.
      final wednesday = DateTime(2026, 5, 13, 12);
      expect(gym.occurrenceOn(wednesday), DateTime(2026, 5, 11));
      final done = gym.marked(done: true, today: wednesday);
      expect(done.progress.doneDays, {DateTime(2026, 5, 11)});
      expect(done.asOf(wednesday).done, isTrue);
      // Thursday comes round afresh.
      expect(done.asOf(DateTime(2026, 5, 14)).done, isFalse);
    });

    test("are overdue on the days after a time they weren't done for", () {
      expect(gym.isPastDue(DateTime(2026, 5, 11, 23)), isFalse);
      expect(gym.isPastDue(DateTime(2026, 5, 12, 9)), isTrue);
      expect(
        gym
            .marked(done: true, today: DateTime(2026, 5, 12))
            .isPastDue(DateTime(2026, 5, 12, 9)),
        isTrue,
        reason: "a done one is past due, but it's done",
      );
      expect(gym.isPastDue(DateTime(2026, 5, 14, 9)), isFalse);
      // Daily ones never are: today stands for them.
      expect(
        TodoItem(
          uuid: "u",
          title: "t",
          time: const ClockTime(7, 0),
          reminder: Reminder.daily,
          progress: RepeatProgress(since: DateTime(2026, 5, 1)),
        ).isPastDue(DateTime(2026, 5, 13, 23)),
        isFalse,
      );
    });

    test('are for their first time while it is still to come', () {
      final later = gym.repeatingAs(
        Recurrence.weekly({DateTime.friday}),
        progress: RepeatProgress(since: DateTime(2026, 5, 13)),
      );
      expect(later.reminder, Reminder.weekly);
      expect(later.occurrenceOn(DateTime(2026, 5, 13)), DateTime(2026, 5, 15));
      expect(later.isPastDue(DateTime(2026, 5, 13, 20)), isFalse);
    });
  });

  group('RepeatProgress', () {
    test('keeps days, not times', () {
      final progress = RepeatProgress(
        since: DateTime(2026, 5, 8, 15, 30),
        doneDays: [DateTime(2026, 5, 11, 7)],
      );
      expect(progress.since, DateTime(2026, 5, 8));
      expect(progress.isDoneOn(DateTime(2026, 5, 11, 22)), isTrue);
      expect(progress.isDoneOn(DateTime(2026, 5, 10)), isFalse);
    });

    test('writes its days oldest first, and reads them back', () {
      final map = RepeatProgress(
        since: DateTime(2026, 5, 8),
        doneDays: [DateTime(2026, 5, 12), DateTime(2026, 5, 9)],
      ).toMap();
      expect(map, {'since': "2026-05-08", 'doneDays': "2026-05-09,2026-05-12"});
      final read = RepeatProgress.fromMap(map);
      expect(read.since, DateTime(2026, 5, 8));
      expect(read.doneDays, {DateTime(2026, 5, 9), DateTime(2026, 5, 12)});
    });

    test('skips days that will not read as days', () {
      final read = RepeatProgress.fromMap({
        'since': "soon",
        'doneDays': "2026-05-09,,later, 2026-05-12",
      });
      expect(read.since, isNull);
      expect(read.doneDays, {DateTime(2026, 5, 9), DateTime(2026, 5, 12)});
    });

    test('marks a day done, or not', () {
      final progress = RepeatProgress(
        since: DateTime(2026, 5, 8),
        doneDays: [DateTime(2026, 5, 12)],
      );
      final today = DateTime(2026, 5, 13, 12);
      final done = progress.withDay(today, done: true);
      expect(done.isDoneOn(today), isTrue);
      expect(done.since, progress.since);
      final undone = done.withDay(DateTime(2026, 5, 12, 8), done: false);
      expect(undone.isDoneOn(DateTime(2026, 5, 12)), isFalse);
      expect(undone.isDoneOn(today), isTrue);
      expect(progress.isDoneOn(today), isFalse);
    });

    test('starts counting again from a new day, keeping the days done', () {
      final progress = RepeatProgress(
        since: DateTime(2026, 5, 8),
        doneDays: [DateTime(2026, 5, 9)],
      );
      final restarted = progress.startingOn(DateTime(2026, 5, 12, 9));
      expect(restarted.since, DateTime(2026, 5, 12));
      expect(restarted.doneDays, {DateTime(2026, 5, 9)});
    });
  });
}
