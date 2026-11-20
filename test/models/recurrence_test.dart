import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/recurrence.dart';

void main() {
  // A Wednesday, like the view model tests' day.
  final today = DateTime(2026, 5, 13, 12);
  DateTime may(int day) => DateTime(2026, 5, day);

  group('a daily task', () {
    final daily = Recurrence.daily(since: DateTime(2026, 5, 8, 15, 30));
    final done = {may(9), may(11), may(12)};

    test('says how each day went', () {
      DayStatus on(int day) => daily.statusOf(may(day), today, done: done);
      expect(on(7), DayStatus.untracked);
      expect(on(8), DayStatus.missed);
      expect(on(9), DayStatus.done);
      expect(on(10), DayStatus.missed);
      expect(on(12), DayStatus.done);
      expect(on(13), DayStatus.due);
      expect(on(14), DayStatus.untracked);
      expect(daily.statusOf(today, today, done: {...done, may(13)}),
          DayStatus.done);
    });

    test('counts no day missed before it knows when it began', () {
      final unknown = Recurrence.daily();
      final done = {may(12)};
      expect(unknown.statusOf(may(11), today, done: done), DayStatus.untracked);
      expect(unknown.statusOf(may(12), today, done: done), DayStatus.done);
      expect(unknown.statusOf(today, today, done: done), DayStatus.due);
    });

    test('counts days from when it starts afresh, keeping the days done', () {
      final restarted = Recurrence.daily(since: may(12));
      expect(
          restarted.statusOf(may(10), today, done: done), DayStatus.untracked);
      expect(restarted.statusOf(may(9), today, done: done), DayStatus.done);
    });

    test('has a streak up to today, or to yesterday while today is to do', () {
      expect(daily.streak(today, done: done), 2);
      expect(daily.streak(today, done: {...done, may(13)}), 3);
      expect(daily.streak(may(14), done: done), 0);
      expect(daily.streak(today, done: {}), 0);
    });

    test('has a streak across the end of a month', () {
      final run = {
        DateTime(2026, 2, 27),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 1),
      };
      expect(Recurrence.daily().streak(DateTime(2026, 3, 2), done: run), 3);
    });
  });

  group('a weekly task', () {
    // Mondays and Thursdays, since Monday the 4th.
    final gym =
        Recurrence.weekly({DateTime.monday, DateTime.thursday}, since: may(4));

    test('comes round on its days of the week', () {
      expect(gym.occursOn(may(11)), isTrue);
      expect(gym.occursOn(may(13)), isFalse);
      expect(gym.occursOn(DateTime(2026, 4, 30)), isFalse,
          reason: "before it started");
      expect(gym.lastOnOrBefore(today), may(11));
      expect(gym.firstOnOrAfter(today), may(14));
      expect(gym.from(today).take(3), [may(14), may(18), may(21)]);
    });

    test('stands for its last time until the next one comes', () {
      expect(gym.currentAsOf(today), may(11));
      expect(gym.currentAsOf(may(14)), may(14));
    });

    test('is for its first time while that is still to come', () {
      final later = Recurrence.weekly({DateTime.friday}, since: today);
      expect(later.currentAsOf(today), may(15));
      expect(later.statusOf(may(15), today, done: {}), DayStatus.due);
      expect(later.statusOf(may(8), today, done: {}), DayStatus.untracked);
    });

    test('has a time missed only once the next one has come', () {
      DayStatus on(int day, DateTime asOf) =>
          gym.statusOf(may(day), asOf, done: {may(4)});
      expect(on(4, today), DayStatus.done);
      expect(on(7, today), DayStatus.missed);
      expect(on(11, today), DayStatus.due, reason: "it can still be done");
      expect(on(12, today), DayStatus.untracked);
      expect(on(11, may(14)), DayStatus.missed);
    });

    test('has a streak of its times in a row', () {
      expect(gym.streak(today, done: {may(4), may(7), may(11)}), 3);
      expect(gym.streak(today, done: {may(4), may(7)}), 2,
          reason: "Monday's still to do");
      expect(gym.streak(today, done: {may(4), may(11)}), 1);
    });
  });

  group('a monthly task', () {
    test('comes round on its day of the month', () {
      final rent = Recurrence.monthly(1, since: DateTime(2026, 1, 15));
      expect(rent.currentAsOf(today), may(1));
      expect(rent.firstOnOrAfter(today), DateTime(2026, 6, 1));
      expect(rent.lastOnOrBefore(DateTime(2026, 1, 31)), isNull);
      expect(rent.currentAsOf(DateTime(2026, 1, 31)), DateTime(2026, 2, 1));
    });

    test('skips the months without its day', () {
      final last = Recurrence.monthly(31, since: DateTime(2026, 1, 1));
      expect(last.from(DateTime(2026, 1, 1)).take(4), [
        DateTime(2026, 1, 31),
        DateTime(2026, 3, 31),
        DateTime(2026, 5, 31),
        DateTime(2026, 7, 31),
      ]);
      expect(last.currentAsOf(DateTime(2026, 4, 30)), DateTime(2026, 3, 31));
      final leap = Recurrence.monthly(29, since: DateTime(2027, 1, 1));
      expect(leap.from(DateTime(2027, 1, 30)).take(2),
          [DateTime(2027, 3, 29), DateTime(2027, 4, 29)]);
      expect(leap.firstOnOrAfter(DateTime(2028, 2, 1)), DateTime(2028, 2, 29));
    });

    test('has a streak of months in a row, over the ones it skips', () {
      final last = Recurrence.monthly(31, since: DateTime(2026, 1, 1));
      final done = {DateTime(2026, 1, 31), DateTime(2026, 3, 31)};
      expect(last.streak(DateTime(2026, 4, 30), done: done), 2);
    });
  });

  group('a task that stops', () {
    final course = Recurrence.daily(since: may(10), until: may(14));

    test('comes round up to its last day, and no more', () {
      expect(course.from(today), [may(13), may(14)]);
      expect(course.occursOn(may(15)), isFalse);
      expect(course.hasEndedBy(may(14)), isFalse);
      expect(course.hasEndedBy(may(15)), isTrue);
      expect(Recurrence.daily().hasEndedBy(DateTime(3000)), isFalse);
    });

    test('stands for its last time from then on', () {
      expect(course.currentAsOf(DateTime(2026, 6, 1)), may(14));
    });

    test('never comes round when it stops before it would', () {
      final never =
          Recurrence.weekly({DateTime.friday}, since: today, until: may(14));
      expect(never.currentAsOf(today), isNull);
      expect(never.hasEndedBy(today), isTrue);
      expect(never.statusOf(today, today, done: {}), DayStatus.untracked);
      expect(never.streak(today, done: {}), 0);
    });
  });

  group('a while', () {
    test('ends on the day before as many days, weeks or months on', () {
      // A Friday.
      final start = DateTime(2026, 11, 20);
      expect(RepeatUnit.days.lastDay(start, 1), start);
      expect(RepeatUnit.days.lastDay(start, 10), DateTime(2026, 11, 29));
      expect(RepeatUnit.weeks.lastDay(start, 1), DateTime(2026, 11, 26));
      expect(RepeatUnit.weeks.lastDay(start, 2), DateTime(2026, 12, 3));
      expect(RepeatUnit.months.lastDay(start, 3), DateTime(2027, 2, 19));
    });

    test('of months from a day the last month lacks ends before its end', () {
      expect(RepeatUnit.months.lastDay(DateTime(2027, 1, 31), 1),
          DateTime(2027, 2, 27));
      expect(RepeatUnit.months.lastDay(DateTime(2027, 1, 30), 13),
          DateTime(2028, 2, 28));
    });
  });

  test('tells whether two come round on the same days', () {
    expect(
        Recurrence.weekly({1, 3}, since: may(1))
            .repeatsLike(Recurrence.weekly({3, 1}, until: may(30))),
        isTrue);
    expect(
        Recurrence.weekly({1}).repeatsLike(Recurrence.weekly({1, 3})), isFalse);
    expect(Recurrence.monthly(1).repeatsLike(Recurrence.monthly(2)), isFalse);
    expect(Recurrence.daily().repeatsLike(Recurrence.weekly({1})), isFalse);
  });

  test('needs the days it comes round on', () {
    expect(() => Recurrence.weekly({}), throwsArgumentError);
    expect(() => Recurrence.weekly({0}), throwsArgumentError);
    expect(() => Recurrence.monthly(0), throwsArgumentError);
    expect(() => Recurrence.monthly(32), throwsArgumentError);
  });
}
