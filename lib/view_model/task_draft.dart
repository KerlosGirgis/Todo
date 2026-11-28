part of 'tasks_view_model.dart';

/// How a task's reminder stands, as its form has it.
enum ReminderStatus {
  off,

  /// A one-time reminder without its day or its time.
  needsDayAndTime,

  /// A repeating reminder without its time.
  needsTime,

  /// A one-time reminder for a time that's already gone.
  inPast,

  /// A repeating reminder that stops before the task would come round.
  endsTooSoon,

  /// A repeating reminder whose last time has gone: the task keeps its
  /// days, with nothing more to remind the user of.
  ended,

  /// A reminder that will go off.
  ready,
}

/// A task as its form has it, being added or changed, with the form's
/// rules: a time on its own is for today, a repeating task has no day, a
/// weekly one comes round on one day of the week at least, and a monthly one
/// on a day of the month.
class TaskDraft with ChangeNotifier {
  TaskDraft._(this.task, this._now, this._tree, TodoItem? parent)
    : _title = task?.title ?? "",
      _description = task?.desc ?? "",
      _day = task?.day,
      _time = task?.time,
      _reminder = task?.reminder ?? Reminder.none,
      _weekdays = task?.weekdays ?? const {},
      _monthDay = task?.monthDay,
      _until = task?.until,
      _was = parent,
      _parent = parent {
    if (_reminder.repeats) {
      _lastRepeat = _reminder;
      _fillRepeatDays(_today);
    }
  }

  /// The task being changed, or null for a new one.
  final TodoItem? task;
  final DateTime Function() _now;

  /// Every task, as the form opened.
  final TaskTree _tree;

  /// The task it was a subtask of as the form opened.
  final TodoItem? _was;

  bool get adding => task == null;

  String _title;
  String get title => _title;
  String _description;
  String get description => _description;
  DateTime? _day;
  DateTime? get day => _day;
  ClockTime? _time;
  ClockTime? get time => _time;
  Reminder _reminder;
  Reminder get reminder => _reminder;

  /// The days of the week a weekly task comes round on, from
  /// [DateTime.monday] to [DateTime.sunday].
  Set<int> get weekdays => UnmodifiableSetView(_weekdays);
  Set<int> _weekdays;

  /// The day of the month a monthly task comes round on, from 1 to 31.
  int? get monthDay => _monthDay;
  int? _monthDay;

  /// The last day a repeating task is to repeat on, or null for good.
  DateTime? get until => _until;
  DateTime? _until;

  /// How the task last repeated on the form, to go back to.
  Reminder _lastRepeat = Reminder.daily;

  DateTime get _today => _dateOf(_now());

  /// The time as the form goes by it: the tasks' clock.
  DateTime get now => _now();

  /// The task it's a subtask of, or null for a task of its own.
  TodoItem? get parent => _parent;
  TodoItem? _parent;

  /// Whether the task is to go into another task than the one it's in, or
  /// out of it.
  bool get moved => !adding && _parent?.uuid != _was?.uuid;

  /// The tasks it can be a subtask of, each ahead of its own subtasks:
  /// every task but itself and the ones in it.
  List<TaskNode> get places {
    final own = task == null ? null : _tree.nodeOf(task!);
    return [
      for (final node in _tree.nodes)
        if (own == null || !node.isOrIsIn(own)) node,
    ];
  }

  /// Whether the task can be saved as the form has it: it has a title, and
  /// one that's to repeat has a reminder it can repeat by, which needs a
  /// time, and to come round before it stops. Saved without it, the task
  /// wouldn't repeat at all. A one-time reminder that can't be set doesn't
  /// keep the task from being saved: it's saved without it.
  bool get canSave =>
      _title.trim().isNotEmpty &&
      switch (reminderStatus()) {
        ReminderStatus.needsTime || ReminderStatus.endsTooSoon => false,
        _ => true,
      };

  /// Whether the task can have a day: not while it repeats.
  bool get hasDay => !_reminder.repeats;

  /// Whether the task is to come round again and again.
  bool get repeats => _reminder.repeats;

  void setTitle(String title) {
    final could = canSave;
    _title = title;
    if (canSave != could) notifyListeners();
  }

  void setDescription(String description) => _description = description;

  /// Sets the day the task is for, or takes it away with null.
  void setDay(DateTime? day) {
    _day = day == null ? null : DateTime(day.year, day.month, day.day);
    notifyListeners();
  }

  /// Sets the task's time, or takes it away with null. A time on its own is
  /// for today, unless the task repeats.
  void setTime(ClockTime? time) {
    _time = time;
    if (time != null && _day == null && hasDay) _day = _today;
    notifyListeners();
  }

  /// Makes the task a subtask of [parent], or a task of its own with null.
  void setParent(TodoItem? parent) {
    _parent = parent;
    notifyListeners();
  }

  /// A repeating reminder goes off at the task's time each time it comes
  /// round, so the task has no day. One that's to come round on days of
  /// the week, or of the month, starts out on the day the task was for, or
  /// on today.
  void setReminder(Reminder reminder) {
    _reminder = reminder;
    if (reminder.repeats) {
      _lastRepeat = reminder;
      _fillRepeatDays(_day ?? _today);
      _day = null;
    }
    notifyListeners();
  }

  /// Has the reminder repeat again, as it last did on the form, or daily.
  void setRepeating() => setReminder(_lastRepeat);

  void _fillRepeatDays(DateTime day) {
    if (_weekdays.isEmpty) _weekdays = {day.weekday};
    _monthDay ??= day.day;
  }

  /// Has a weekly task come round on [weekday] as well, or not anymore. It
  /// keeps one day at least.
  void toggleWeekday(int weekday) {
    if (!Recurrence.isWeekday(weekday)) return;
    if (!_weekdays.contains(weekday)) {
      _weekdays = {..._weekdays, weekday};
    } else if (_weekdays.length > 1) {
      _weekdays = {..._weekdays}..remove(weekday);
    } else {
      return;
    }
    notifyListeners();
  }

  /// Has a monthly task come round on [day] of the month, from 1 to 31.
  void setMonthDay(int day) {
    if (!Recurrence.isMonthDay(day) || day == _monthDay) return;
    _monthDay = day;
    notifyListeners();
  }

  /// Has a repeating task stop after [until], or repeat for good, with
  /// null.
  void setUntil(DateTime? until) {
    _until = until == null ? null : _dateOf(until);
    notifyListeners();
  }

  /// When the task is to come round, or null when it isn't to repeat: from
  /// the day it started repeating, when it's to come round on the days it
  /// does already, or else from today, as it would once it's saved.
  Recurrence? get rule {
    final pattern = switch (_reminder) {
      Reminder.daily => Recurrence.daily(),
      Reminder.weekly => Recurrence.weekly(_weekdays),
      Reminder.monthly => Recurrence.monthly(_monthDay!),
      Reminder.none || Reminder.once => null,
    };
    if (pattern == null) return null;
    final was = task?.recurrence;
    final since = was != null && was.repeatsLike(pattern) ? was.since : _today;
    return pattern.spanning(since: since, until: _until);
  }

  /// A form for how long the task is to repeat, from today. Only for a task
  /// that's to repeat.
  RepeatEndDraft endDraft() {
    final rule = this.rule!;
    return RepeatEndDraft._(
      rule.spanning(since: rule.since, until: null),
      _today,
      _until,
    );
  }

  /// How the reminder stands now: whether it'll go off, or what it still
  /// needs.
  ReminderStatus reminderStatus() {
    final now = _now();
    final day = _day;
    final time = _time;
    final rule = this.rule;
    return switch (_reminder) {
      Reminder.none => ReminderStatus.off,
      Reminder.once when day == null || time == null =>
        ReminderStatus.needsDayAndTime,
      Reminder.once when !time!.on(day!).isAfter(now) => ReminderStatus.inPast,
      Reminder.once => ReminderStatus.ready,
      _ when time == null => ReminderStatus.needsTime,
      _ when rule!.currentAsOf(now) == null => ReminderStatus.endsTooSoon,
      _ when rule.hasEndedBy(now) => ReminderStatus.ended,
      _ => ReminderStatus.ready,
    };
  }
}

/// How long a task keeps repeating, as the form for it has it.
enum RepeatSpan {
  /// For good.
  forever,

  /// For a number of days, weeks or months, from today.
  forAWhile,

  /// Until a day.
  untilADay,
}

/// How long a task is to keep repeating, as its form has it: for good, for
/// a while from today, or until a day; with how many more times it would
/// come round, and the last of them.
class RepeatEndDraft with ChangeNotifier {
  RepeatEndDraft._(this._rule, this._today, DateTime? until)
    : _span = until == null ? RepeatSpan.forever : RepeatSpan.untilADay,
      _unit = _rule.every == RepeatEvery.month
          ? RepeatUnit.months
          : RepeatUnit.weeks,
      _amount = switch (_rule.every) {
        RepeatEvery.day => 2,
        RepeatEvery.week => 4,
        RepeatEvery.month => 6,
      } {
    _day = until ?? _unit.lastDay(_today, _amount);
  }

  /// The most days, weeks or months a while can be.
  static const maxAmount = 99;

  /// When the task comes round, for good.
  final Recurrence _rule;
  final DateTime _today;

  RepeatSpan get span => _span;
  RepeatSpan _span;

  /// How many days, weeks or months it's to repeat for, from today.
  int get amount => _amount;
  int _amount;
  RepeatUnit get unit => _unit;
  RepeatUnit _unit;

  /// The last day it's to repeat on, when it's to repeat until a day.
  DateTime get day => _day;
  late DateTime _day;

  /// The first day it can stop on, which is today.
  DateTime get firstDay => _today;

  /// The day the form goes by, as the task's form does: today.
  DateTime get today => _today;

  void setSpan(RepeatSpan span) {
    if (span == _span) return;
    _span = span;
    notifyListeners();
  }

  /// Has it repeat for [amount] days, weeks or months, from 1 to
  /// [maxAmount].
  void setAmount(int amount) {
    final clamped = amount.clamp(1, maxAmount);
    if (clamped == _amount) return;
    _amount = clamped;
    notifyListeners();
  }

  void setUnit(RepeatUnit unit) {
    if (unit == _unit) return;
    _unit = unit;
    notifyListeners();
  }

  /// Has it stop after [day], which is today at the earliest.
  void setDay(DateTime day) {
    final date = _dateOf(day);
    _day = date.isBefore(_today) ? _today : date;
    notifyListeners();
  }

  /// The last day the task is to repeat on, or null for good.
  DateTime? get until => switch (_span) {
    RepeatSpan.forever => null,
    RepeatSpan.forAWhile => _unit.lastDay(_today, _amount),
    RepeatSpan.untilADay => _day,
  };

  /// How many more times the task would come round, from today until it
  /// stops, and the last of them; null while it's to repeat for good.
  ({int count, DateTime? last})? get times {
    final until = this.until;
    if (until == null) return null;
    var count = 0;
    DateTime? last;
    for (final day
        in _rule.spanning(since: _rule.since, until: until).from(_today)) {
      count++;
      last = day;
    }
    return (count: count, last: last);
  }

  /// Whether the task would come round at all before it stopped.
  bool get canSave => times?.count != 0;
}
