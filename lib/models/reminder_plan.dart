import 'recurrence.dart';
import 'todo_item.dart';

/// A reminder to set on the phone. A task's reminders are told apart by
/// their [id]s, which setting one again under the same id replaces.
sealed class Alarm {
  const Alarm(this.id);

  final int id;
}

/// A reminder that goes off once, [at] a time.
final class OnceAlarm extends Alarm {
  const OnceAlarm(super.id, this.at);

  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is OnceAlarm && other.id == id && other.at == at;

  @override
  int get hashCode => Object.hash(id, at);

  @override
  String toString() => "OnceAlarm($id, $at)";
}

/// A reminder that goes off at its [first] time, then at that time again
/// [every] day, every week on that day, or every month on that day, until
/// it's cancelled.
final class RepeatingAlarm extends Alarm {
  const RepeatingAlarm(super.id, this.first, this.every);

  final DateTime first;
  final RepeatEvery every;

  @override
  bool operator ==(Object other) =>
      other is RepeatingAlarm &&
      other.id == id &&
      other.first == first &&
      other.every == every;

  @override
  int get hashCode => Object.hash(id, first, every);

  @override
  String toString() => "RepeatingAlarm($id, $first, ${every.name})";
}

/// The reminders a task needs on the phone, as of a time.
abstract final class ReminderPlan {
  /// How many times a repeating task has left before its last day when its
  /// reminders are set one by one, so that they stop with it. Until then,
  /// they repeat by themselves, as they do for a task that repeats for good,
  /// and they're set afresh each day the app is opened on.
  static const lastTimes = 8;

  /// The reminders [task] needs as of [now], each under an id of [idsOf]:
  ///
  /// * A one-time reminder that's still to come, unless the task is done.
  /// * A repeating task's at its time each time it comes round from now
  ///   on, done or not: one that repeats every day or every month, and one
  ///   for each of the days a week it comes round on. Once it has no more
  ///   than [lastTimes] times left before its last day, one for each of
  ///   those instead, and none once they've gone.
  ///
  /// None for a task without a time.
  static List<Alarm> of(TodoItem task, DateTime now) {
    final time = task.time;
    if (time == null) return const [];
    final uuid = task.uuid;
    if (task.reminder == Reminder.once) {
      final day = task.day;
      if (day == null || task.done) return const [];
      final at = time.on(day);
      return at.isAfter(now) ? [OnceAlarm(uuid.hashCode, at)] : const [];
    }
    final recurrence = task.recurrence;
    if (recurrence == null) return const [];
    final times = recurrence
        .from(DateTime(now.year, now.month, now.day))
        .map(time.on)
        .where((at) => at.isAfter(now));
    if (recurrence.until != null) {
      final left = times.take(lastTimes + 1).toList();
      if (left.length <= lastTimes) {
        return [
          for (final (index, at) in left.indexed)
            OnceAlarm(_timeId(uuid, index), at),
        ];
      }
    }
    final first = times.firstOrNull;
    if (first == null) return const [];
    return switch (recurrence.every) {
      RepeatEvery.week => [
          for (final weekday in recurrence.weekdays.toList()..sort())
            if (times.where((at) => at.weekday == weekday).firstOrNull
                case final first?)
              RepeatingAlarm(
                  _weekdayId(uuid, weekday), first, RepeatEvery.week),
        ],
      final every => [RepeatingAlarm(uuid.hashCode, first, every)],
    };
  }

  /// Every id a reminder of the task with [uuid] can have: the one a
  /// one-time, daily or monthly reminder goes by, then one for each day of
  /// the week, then one for each of its last times.
  static List<int> idsOf(String uuid) => [
        uuid.hashCode,
        for (var weekday = DateTime.monday;
            weekday <= DateTime.sunday;
            weekday++)
          _weekdayId(uuid, weekday),
        for (var index = 0; index < lastTimes; index++) _timeId(uuid, index),
      ];

  static int _weekdayId(String uuid, int weekday) => "$uuid#w$weekday".hashCode;

  static int _timeId(String uuid, int index) => "$uuid#t$index".hashCode;
}
