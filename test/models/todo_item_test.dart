import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/clock_time.dart';
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
}
