import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/result.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/recurrence.dart';
import 'package:todo/models/reminder_plan.dart';
import 'package:todo/models/repeat_progress.dart';
import 'package:todo/models/task_filters.dart';
import 'package:todo/models/task_listing.dart';
import 'package:todo/models/task_sort.dart';
import 'package:todo/models/task_tree.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/trashed.dart';
import 'package:todo/repositories/tasks_repository.dart';
import 'package:todo/services/file_service.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/services/notification_service.dart';
import 'package:todo/view_model/tasks_view_model.dart';

/// The tasks table, in memory. Like the real one, rewriting it gives every
/// task a new id.
class FakeTasksRepository extends TasksRepository {
  final rows = <TodoItem>[];
  var _nextId = 1;

  TodoItem _withId(TodoItem task) =>
      TodoItem.fromMap({...task.toMap(), 'id': _nextId++});

  /// Whether adding or changing tasks fails, as when the disk is full, and
  /// whether reading them does.
  bool failWrites = false;
  bool failReads = false;

  @override
  Future<int> insertItem(TodoItem item) async {
    if (failWrites) throw StateError("Disk full");
    final row = _withId(item);
    rows.add(row);
    return row.id!;
  }

  @override
  Future<List<TodoItem>> getItems() async {
    if (failReads) throw StateError("Can't read the tasks");
    return List.of(rows);
  }

  /// How the tasks were last listed, as its table keeps it, and whether
  /// keeping it fails, as when the disk is full.
  TaskListing? listing;
  bool failListing = false;

  @override
  Future<TaskListing?> getListing() async => listing;

  @override
  Future<void> saveListing(TaskListing listing) async {
    if (failListing) throw StateError("Disk full");
    this.listing = listing;
  }

  @override
  Future<void> deleteItem(int id) async =>
      rows.removeWhere((row) => row.id == id);

  @override
  Future<void> updateItem(TodoItem item) async {
    if (failWrites) throw StateError("Disk full");
    final index = rows.indexWhere((row) => row.id == item.id);
    if (index != -1) rows[index] = item;
  }

  /// All of them or, as the real one does when it fails, none.
  @override
  Future<void> updateItems(Iterable<TodoItem> items) async {
    if (failWrites) throw StateError("Disk full");
    for (final item in items) {
      await updateItem(item);
    }
  }

  @override
  Future<void> refreshAllItems(List<TodoItem> items) async {
    rows
      ..clear()
      ..addAll(items.map(_withId));
  }

  @override
  Future<void> importItems(
    List<TodoItem> items, {
    required bool overwrite,
  }) async {
    if (overwrite) rows.clear();
    rows.addAll(items.map(_withId));
  }

  /// The trash, the first deleted first. Like the real one, it keeps a task
  /// as backups do, with the tasks in it, and never gives an entry's id to
  /// another.
  final trash = <Trashed<TaskBranch>>[];
  var _nextTrashId = 1;
  bool failMoves = false;

  @override
  Future<Trashed<TaskBranch>> moveToTrash(
    TaskBranch branch, {
    required DateTime deletedAt,
  }) async {
    if (failMoves) throw StateError("Disk full");
    final ids = {for (final task in branch.all) task.id};
    if (rows.every((row) => row.id != branch.task.id)) {
      throw StateError("No task ${branch.task.id}");
    }
    rows.removeWhere((row) => ids.contains(row.id));
    final id = _nextTrashId++;
    trash.add(
      Trashed(
        id: id,
        // As it's read back: from its JSON, with the id its task had.
        item: TaskBranch.fromMap({...branch.toMap(), 'id': branch.task.id}),
        deletedAt: deletedAt,
      ),
    );
    return Trashed(id: id, item: branch, deletedAt: deletedAt);
  }

  @override
  Future<List<Trashed<TaskBranch>>> getTrash() async => trash.reversed.toList();

  /// Back with the ids they had when no task has any of them, among the
  /// tasks in the order of their ids, as the table lists them; or else at
  /// the end.
  @override
  Future<int?> restoreFromTrash(int id, TaskBranch branch) async {
    final index = trash.indexWhere((entry) => entry.id == id);
    if (index == -1) return null;
    trash.removeAt(index);
    final free = branch.all.every(
      (task) => task.id != null && rows.every((row) => row.id != task.id),
    );
    if (!free) {
      // Past every id there is, as some rows come with their own.
      _nextId = rows.fold(
        _nextId,
        (top, row) => top > row.id! ? top : row.id! + 1,
      );
    }
    int? first;
    for (final task in branch.all) {
      final row = TodoItem.fromMap({
        ...task.toMap(),
        'id': free ? task.id : _nextId++,
      });
      final after = rows.indexWhere((each) => each.id! > row.id!);
      rows.insert(after == -1 ? rows.length : after, row);
      first ??= row.id;
    }
    return first;
  }

  @override
  Future<void> deleteFromTrash(Iterable<int> ids) async {
    final gone = ids.toSet();
    trash.removeWhere((entry) => gone.contains(entry.id));
  }
}

/// A file picker that picks [records], as a backup from before backups
/// were locked.
class FakeFiles extends FileService {
  FakeFiles(this.records);

  final List<Map<String, Object>> records;

  @override
  Future<Uint8List?> pickJsonFile() async => utf8.encode(jsonEncode(records));
}

class FakeNotifications extends NotificationService {
  final once = <int, DateTime>{};
  final repeating = <int, ({DateTime first, RepeatEvery every})>{};
  final bodies = <int, String?>{};

  /// The times of the reminders that repeat every day.
  Map<int, ClockTime> get daily => _times(RepeatEvery.day);

  /// The first times of the reminders that repeat every week, or month.
  Map<int, DateTime> get weekly => _firsts(RepeatEvery.week);
  Map<int, DateTime> get monthly => _firsts(RepeatEvery.month);

  Map<int, ClockTime> _times(RepeatEvery every) => {
    for (final MapEntry(:key, :value) in repeating.entries)
      if (value.every == every)
        key: ClockTime(value.first.hour, value.first.minute),
  };

  Map<int, DateTime> _firsts(RepeatEvery every) => {
    for (final MapEntry(:key, :value) in repeating.entries)
      if (value.every == every) key: value.first,
  };

  @override
  String timeZone = "Africa/Cairo";

  /// The time zone the reminders were all set in: the phone's, unless a test
  /// says otherwise.
  String? setIn = "Africa/Cairo";

  @override
  Future<String?> remindersTimeZone() async => setIn;

  @override
  Future<void> setRemindersTimeZone(String timeZone) async => setIn = timeZone;

  /// How the reminders' ids were made when they were all last set: the way
  /// the app makes them now, unless a test says otherwise.
  int idVersion = ReminderPlan.idVersion;

  @override
  Future<int> remindersIdVersion() async => idVersion;

  @override
  Future<void> setRemindersIdVersion(int version) async => idVersion = version;

  /// Whether setting a reminder fails, as when the phone won't let the app
  /// set exact alarms.
  bool failSchedules = false;

  @override
  Future<void> scheduleNotification(
    int id,
    String title,
    String? body,
    DateTime scheduledTime,
  ) async {
    if (failSchedules) throw StateError("Can't set alarms");
    once[id] = scheduledTime;
    bodies[id] = body;
  }

  @override
  Future<void> scheduleRepeatingNotification(
    int id,
    String title,
    String? body,
    DateTime first,
    RepeatEvery every,
  ) async {
    if (failSchedules) throw StateError("Can't set alarms");
    repeating[id] = (first: first, every: every);
    bodies[id] = body;
  }

  @override
  Future<void> cancelNotification(int id) async {
    once.remove(id);
    repeating.remove(id);
    bodies.remove(id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    once.clear();
    repeating.clear();
    bodies.clear();
  }

  @override
  Future<void> cancelPendingNotifications() async {
    once.clear();
    repeating.clear();
    bodies.clear();
  }
}

class FakeLock extends LockService {
  FakeLock() : super.withClock(() => throw StateError("No waits"));

  AppLock lock = AppLock.off;
  final changed = StreamController<AppLock>.broadcast();

  @override
  Future<AppLock> getLock() async => lock;

  @override
  Stream<AppLock> get changes => changed.stream;
}

/// Noon on a Wednesday.
final now = DateTime(2026, 5, 13, 12);

void main() {
  late FakeTasksRepository repository;
  late FakeNotifications notifications;
  late FakeLock lock;
  late TasksViewModel tasks;

  /// What the view model's clock says: [now], unless a test moves it on.
  late DateTime time;

  setUp(() {
    repository = FakeTasksRepository();
    notifications = FakeNotifications();
    lock = FakeLock();
    time = now;
    tasks = TasksViewModel(
      repository: repository,
      notificationService: notifications,
      lockService: lock,
      clock: () => time,
    );
  });

  tearDown(() => tasks.dispose());

  /// Adds a task through its form.
  Future<Result> add(
    String title, {
    DateTime? day,
    ClockTime? time,
    Reminder reminder = Reminder.none,
  }) {
    final draft = tasks.draft()
      ..setTitle(title)
      ..setReminder(reminder);
    if (day != null) draft.setDay(day);
    if (time != null) draft.setTime(time);
    return tasks.save(draft);
  }

  TodoItem task(String title) =>
      tasks.items.singleWhere((task) => task.title == title);

  group('TaskDraft', () {
    test('a time on its own is for today', () {
      final draft = tasks.draft()..setTime(const ClockTime(18, 0));
      expect(draft.day, DateTime(2026, 5, 13));
    });

    test('keeps the day a time is set on', () {
      final draft = tasks.draft()
        ..setDay(DateTime(2026, 6, 1, 15, 30))
        ..setTime(const ClockTime(18, 0));
      expect(draft.day, DateTime(2026, 6, 1));
    });

    test('a daily task has no day, even when it gets a time', () {
      final draft = tasks.draft()
        ..setDay(DateTime(2026, 6, 1))
        ..setReminder(Reminder.daily);
      expect(draft.day, isNull);
      expect(draft.hasDay, isFalse);
      draft.setTime(const ClockTime(8, 0));
      expect(draft.day, isNull);
    });

    test('needs a title to save', () {
      final draft = tasks.draft();
      expect(draft.canSave, isFalse);
      draft.setTitle("   ");
      expect(draft.canSave, isFalse);
      draft.setTitle("Water the plants");
      expect(draft.canSave, isTrue);
    });

    test('says what a reminder still needs', () {
      final draft = tasks.draft();
      expect(draft.reminderStatus(), ReminderStatus.off);
      draft.setReminder(Reminder.once);
      expect(draft.reminderStatus(), ReminderStatus.needsDayAndTime);
      draft.setTime(const ClockTime(11, 0));
      expect(draft.reminderStatus(), ReminderStatus.inPast);
      draft.setTime(const ClockTime(13, 0));
      expect(draft.reminderStatus(), ReminderStatus.ready);
      draft
        ..setTime(null)
        ..setReminder(Reminder.daily);
      expect(draft.reminderStatus(), ReminderStatus.needsTime);
      draft.setTime(const ClockTime(7, 0));
      expect(draft.reminderStatus(), ReminderStatus.ready);
    });

    test('starts from the task it changes', () {
      final draft = tasks.draft(
        TodoItem(
          uuid: "u",
          title: "Old",
          desc: "d",
          day: DateTime(2026, 5, 20),
          time: const ClockTime(9, 0),
          reminder: Reminder.once,
        ),
      );
      expect(draft.adding, isFalse);
      expect(draft.title, "Old");
      expect(draft.description, "d");
      expect(draft.day, DateTime(2026, 5, 20));
      expect(draft.time, const ClockTime(9, 0));
      expect(draft.reminder, Reminder.once);
    });

    test('a repeating task starts out on the day it was for, or today', () {
      final draft = tasks.draft()
        ..setDay(DateTime(2026, 5, 15))
        ..setReminder(Reminder.weekly);
      expect(draft.weekdays, {DateTime.friday});
      expect(draft.monthDay, 15);
      expect(draft.day, isNull);
      expect(draft.hasDay, isFalse);
      expect((tasks.draft()..setReminder(Reminder.weekly)).weekdays, {
        DateTime.wednesday,
      });
      expect((tasks.draft()..setReminder(Reminder.monthly)).monthDay, 13);
    });

    test('a weekly task keeps one day of the week at least', () {
      final draft = tasks.draft()..setReminder(Reminder.weekly);
      draft.toggleWeekday(DateTime.wednesday);
      expect(draft.weekdays, {DateTime.wednesday});
      draft
        ..toggleWeekday(DateTime.monday)
        ..toggleWeekday(DateTime.wednesday);
      expect(draft.weekdays, {DateTime.monday});
    });

    test('Repeat goes back to how the form last repeated, or daily', () {
      final draft = tasks.draft()
        ..setReminder(Reminder.monthly)
        ..setReminder(Reminder.none)
        ..setRepeating();
      expect(draft.reminder, Reminder.monthly);
      expect((tasks.draft()..setRepeating()).reminder, Reminder.daily);
    });

    test('says when a repeating reminder would stop before it comes round', () {
      final draft = tasks.draft()
        ..setTime(const ClockTime(18, 0))
        ..setReminder(Reminder.weekly)
        ..toggleWeekday(DateTime.friday)
        ..toggleWeekday(DateTime.wednesday)
        ..setUntil(DateTime(2026, 5, 14));
      expect(draft.reminderStatus(), ReminderStatus.endsTooSoon);
      draft.setUntil(DateTime(2026, 5, 15));
      expect(draft.reminderStatus(), ReminderStatus.ready);
      expect(
        draft.rule,
        Recurrence.weekly(
          {DateTime.friday},
          since: DateTime(2026, 5, 13),
          until: DateTime(2026, 5, 15),
        ),
      );
    });

    test('says how long a task would keep repeating', () {
      // On Wednesdays, from today.
      final draft = tasks.draft()..setReminder(Reminder.weekly);
      final end = draft.endDraft();
      addTearDown(end.dispose);
      expect(end.span, RepeatSpan.forever);
      expect(end.until, isNull);
      expect(end.times, isNull);
      expect(end.canSave, isTrue);

      end.setSpan(RepeatSpan.forAWhile);
      expect((end.amount, end.unit), (4, RepeatUnit.weeks));
      expect(end.until, DateTime(2026, 6, 9));
      expect(end.times, (count: 4, last: DateTime(2026, 6, 3)));
      end
        ..setUnit(RepeatUnit.days)
        ..setAmount(0);
      expect(end.amount, 1);
      expect(end.times, (count: 1, last: DateTime(2026, 5, 13)));

      end
        ..setSpan(RepeatSpan.untilADay)
        ..setDay(DateTime(2026, 5, 1));
      expect(end.day, DateTime(2026, 5, 13), reason: "not before today");

      final friday =
          (tasks.draft()
                ..setReminder(Reminder.weekly)
                ..toggleWeekday(DateTime.friday)
                ..toggleWeekday(DateTime.wednesday))
              .endDraft();
      addTearDown(friday.dispose);
      friday
        ..setSpan(RepeatSpan.untilADay)
        ..setDay(DateTime(2026, 5, 14));
      expect(friday.times, (count: 0, last: null));
      expect(friday.canSave, isFalse);
    });
  });

  group('saving', () {
    test('adds a task with a reminder still to come', () async {
      final result = await add(
        "Call",
        time: const ClockTime(18, 0),
        reminder: Reminder.once,
      );
      expect(result, isA<Info>());
      expect((result as Info).message, startsWith("Time remaining"));
      final call = task("Call");
      expect(call.reminder, Reminder.once);
      expect(
        notifications.once[ReminderPlan.idOf(call.uuid)],
        DateTime(2026, 5, 13, 18),
      );
    });

    test('adds a task without a reminder that has already gone', () async {
      final result = await add(
        "Late",
        time: const ClockTime(9, 0),
        reminder: Reminder.once,
      );
      expect(
        (result as Info).message,
        "Please set time and date in the future",
      );
      expect(task("Late").reminder, Reminder.none);
      expect(notifications.once, isEmpty);
    });

    test('trims the title and description', () async {
      final draft = tasks.draft()
        ..setTitle("  Call  ")
        ..setDescription(" mum ");
      await tasks.save(draft);
      expect(tasks.items.single.title, "Call");
      expect(tasks.items.single.desc, "mum");
    });

    test('changes a task, and turns its reminder off', () async {
      await add("Call", time: const ClockTime(18, 0), reminder: Reminder.once);
      final draft = tasks.draft(task("Call"))
        ..setTitle("Call mum")
        ..setReminder(Reminder.none);
      expect((await tasks.save(draft) as Info).message, "Task Updated");
      expect(task("Call mum").reminder, Reminder.none);
      expect(notifications.once, isEmpty);
    });

    test('a done task given a reminder still to come is to do again', () async {
      await add("Call", time: const ClockTime(18, 0));
      await tasks.toggleDone(task("Call"));
      final draft = tasks.draft(task("Call"))..setReminder(Reminder.once);
      final result = await tasks.save(draft);
      expect(
        (result as Info).message,
        startsWith("Task undone. Time remaining"),
      );
      final call = task("Call");
      expect(call.done, isFalse);
      expect(call.reminder, Reminder.once);
      expect(
        notifications.once[ReminderPlan.idOf(call.uuid)],
        DateTime(2026, 5, 13, 18),
      );
    });

    test('a done task stays done when its reminder has already gone', () async {
      await add("Late", time: const ClockTime(9, 0));
      await tasks.toggleDone(task("Late"));
      final draft = tasks.draft(task("Late"))..setReminder(Reminder.once);
      final result = await tasks.save(draft);
      expect(
        (result as Info).message,
        "Please set time and date in the future",
      );
      expect(task("Late").done, isTrue);
      expect(task("Late").reminder, Reminder.none);
      expect(notifications.once, isEmpty);
    });

    test("says so when a task can't be added, rather than failing", () async {
      repository.failWrites = true;
      final result = await add("Call");
      expect((result as Failure).message, "Couldn't add the task");
      expect(tasks.items, isEmpty);
    });

    test("says so when a change can't be saved, and the task keeps its "
        "reminder", () async {
      await add("Call", time: const ClockTime(18, 0), reminder: Reminder.once);
      repository.failWrites = true;
      final draft = tasks.draft(task("Call"))
        ..setTitle("Call mum")
        ..setReminder(Reminder.none);
      final result = await tasks.save(draft);
      expect((result as Failure).message, "Couldn't save the task");
      expect(task("Call").reminder, Reminder.once);
      expect(notifications.once, hasLength(1));
    });
  });

  group('commands', () {
    test('marking a task done turns its reminder off', () async {
      await add("Call", time: const ClockTime(18, 0), reminder: Reminder.once);
      expect(await tasks.toggleDone(task("Call")), isA<Success>());
      await tasks.get();
      expect(task("Call").done, isTrue);
      expect(task("Call").reminder, Reminder.none);
      expect(notifications.once, isEmpty);
      expect(await tasks.toggleDone(task("Call")), isA<Info>());
      await tasks.get();
      expect(task("Call").done, isFalse);
    });

    test(
      "says so when a task can't be marked done, and it keeps reminding",
      () async {
        await add(
          "Call",
          time: const ClockTime(18, 0),
          reminder: Reminder.once,
        );
        repository.failWrites = true;
        final result = await tasks.toggleDone(task("Call"));
        expect((result as Failure).message, "Couldn't update the task");
        expect(task("Call").done, isFalse);
        expect(task("Call").reminder, Reminder.once);
        expect(notifications.once, hasLength(1));
      },
    );

    test(
      "says how a change went though the tasks can't be read in after it",
      () async {
        await add("Call");
        await add("Shop");
        repository.failReads = true;
        expect(await tasks.toggleDone(task("Call")), isA<Success>());
        expect(await tasks.delete(task("Shop")), isNotNull);

        repository.failReads = false;
        await tasks.get();
        expect(tasks.items.map((task) => (task.title, task.done)), [
          ("Call", true),
        ]);
      },
    );

    test('the bell turns a one-time reminder on, then off', () async {
      await add("Call", time: const ClockTime(18, 0));
      await tasks.toggleReminder(task("Call"));
      await tasks.get();
      expect(task("Call").reminder, Reminder.once);
      expect(notifications.once, hasLength(1));
      await tasks.toggleReminder(task("Call"));
      await tasks.get();
      expect(task("Call").reminder, Reminder.none);
      expect(notifications.once, isEmpty);
    });

    test('a daily reminder takes the task off its day', () async {
      await add("Stretch", time: const ClockTime(7, 0));
      await tasks.remindDaily(task("Stretch"));
      await tasks.get();
      expect(task("Stretch").reminder, Reminder.daily);
      expect(task("Stretch").day, isNull);
      expect(notifications.daily.values.single, const ClockTime(7, 0));
    });

    test('deleting a task takes it off the list straight away', () async {
      await add("Call", time: const ClockTime(18, 0), reminder: Reminder.once);
      await add("Shop");
      final deleting = tasks.delete(task("Call"));
      expect(tasks.items.map((task) => task.title), ["Shop"]);
      await deleting;
      expect(repository.rows.map((task) => task.title), ["Shop"]);
      expect(notifications.once, isEmpty);
    });

    test(
      'acts on the task it is given, after a reorder changed the ids',
      () async {
        await add("First");
        await add("Second");
        final second = task("Second");
        await tasks.syncAfterReorder(1, 0);
        expect(task("Second").id, isNot(second.id));
        await tasks.toggleDone(second);
        await tasks.get();
        expect(task("Second").done, isTrue);
        expect(task("First").done, isFalse);
      },
    );
  });

  group('reminders', () {
    test(
      "say which task they're for only while the app isn't locked",
      () async {
        await add(
          "Call",
          time: const ClockTime(18, 0),
          reminder: Reminder.once,
        );
        await add(
          "Stretch",
          time: const ClockTime(7, 0),
          reminder: Reminder.daily,
        );
        expect(notifications.bodies.values, ["Call", "Stretch"]);
        lock.lock = AppLock.password;
        lock.changed.add(AppLock.password);
        await pumpEventQueue();
        expect(notifications.bodies.values, [null, null]);
        lock.lock = AppLock.off;
        lock.changed.add(AppLock.off);
        await pumpEventQueue();
        expect(notifications.bodies.values, ["Call", "Stretch"]);
      },
    );

    /// Tasks with reminders set by an older version, or in another time
    /// zone: one still to come, one gone that went off once but is set to go
    /// off again a year on, and a daily one.
    Future<void> setEarlier() async {
      await repository.insertItem(
        TodoItem(
          uuid: "call",
          title: "Call",
          day: DateTime(2026, 5, 13),
          time: const ClockTime(18, 0),
          reminder: Reminder.once,
        ),
      );
      await repository.insertItem(
        TodoItem(
          uuid: "shop",
          title: "Shop",
          day: DateTime(2026, 5, 12),
          time: const ClockTime(9, 0),
          reminder: Reminder.once,
        ),
      );
      await repository.insertItem(
        TodoItem(
          uuid: "stretch",
          title: "Stretch",
          time: const ClockTime(7, 0),
          reminder: Reminder.daily,
        ),
      );
      notifications.once[ReminderPlan.idOf("shop")] = DateTime(2027, 5, 12, 9);
    }

    for (final (earlier, why) in [
      (null, "before reminders went by the phone's time zone"),
      ("Europe/London", "in another time zone"),
    ]) {
      test("set $why are all set afresh in the phone's", () async {
        await setEarlier();
        notifications.setIn = earlier;
        await tasks.get();
        expect(notifications.once, {
          ReminderPlan.idOf("call"): DateTime(2026, 5, 13, 18),
        });
        expect(notifications.daily, {
          ReminderPlan.idOf("stretch"): const ClockTime(7, 0),
        });
        expect(notifications.setIn, "Africa/Cairo");
      });
    }

    test("set in the phone's time zone are left as they are", () async {
      await setEarlier();
      await tasks.get();
      expect(notifications.once, {
        ReminderPlan.idOf("shop"): DateTime(2027, 5, 12, 9),
      });
      expect(notifications.daily, isEmpty);
    });

    test("set under ids made the old way are cancelled, and set afresh under "
        "the ids made now", () async {
      await setEarlier();
      notifications
        ..idVersion = 0
        // Under the ids `String.hashCode` made, which the tasks can't find
        // to cancel anymore.
        ..once.clear()
        ..once[1001] = DateTime(2026, 5, 13, 18)
        ..repeating[1002] = (
          first: DateTime(2026, 5, 14, 7),
          every: RepeatEvery.day,
        );
      await tasks.get();
      expect(notifications.once, {
        ReminderPlan.idOf("call"): DateTime(2026, 5, 13, 18),
      });
      expect(notifications.daily, {
        ReminderPlan.idOf("stretch"): const ClockTime(7, 0),
      });
      expect(notifications.idVersion, ReminderPlan.idVersion);
    });

    test(
      "set the old way are set afresh at each start until they all can be",
      () async {
        await setEarlier();
        notifications
          ..idVersion = 0
          ..failSchedules = true;
        await tasks.get();
        expect(notifications.idVersion, 0);

        // The next time the app starts.
        notifications.failSchedules = false;
        final restarted = TasksViewModel(
          repository: repository,
          notificationService: notifications,
          lockService: lock,
          clock: () => time,
        );
        addTearDown(restarted.dispose);
        await restarted.get();
        expect(notifications.once, {
          ReminderPlan.idOf("call"): DateTime(2026, 5, 13, 18),
        });
        expect(notifications.idVersion, ReminderPlan.idVersion);
      },
    );
  });

  group('daily tasks', () {
    Future<void> addStretch() =>
        add("Stretch", time: const ClockTime(7, 0), reminder: Reminder.daily);

    test('count their days from the day they become daily', () async {
      await addStretch();
      final stretch = task("Stretch");
      expect(stretch.progress.since, DateTime(2026, 5, 13));
      expect(stretch.progress.doneDays, isEmpty);
      expect(stretch.done, isFalse);
    });

    test('are done for today only, and keep reminding every day', () async {
      await addStretch();
      final result = await tasks.toggleDone(task("Stretch"));
      expect((result as Success).message, "Done for today");
      expect(task("Stretch").done, isTrue);
      expect(task("Stretch").reminder, Reminder.daily);
      expect(notifications.daily.values.single, const ClockTime(7, 0));
      expect(repository.rows.single.progress.doneDays, {DateTime(2026, 5, 13)});

      time = DateTime(2026, 5, 14, 8);
      await tasks.get();
      expect(task("Stretch").done, isFalse);
      expect(tasks.finishedTasksCount, 0);
      await tasks.toggleDone(task("Stretch"));
      expect(repository.rows.single.progress.doneDays, {
        DateTime(2026, 5, 13),
        DateTime(2026, 5, 14),
      });
    });

    test('take today back off when checked again', () async {
      await addStretch();
      await tasks.toggleDone(task("Stretch"));
      final result = await tasks.toggleDone(task("Stretch"));
      expect((result as Info).message, "Task undone");
      expect(task("Stretch").done, isFalse);
      expect(repository.rows.single.progress.doneDays, isEmpty);
      expect(notifications.daily, hasLength(1));
    });

    test('keep the days that went by without them as missed', () async {
      await addStretch();
      time = DateTime(2026, 5, 15, 9);
      await tasks.get();
      final stretch = task("Stretch");
      DayStatus on(int day) => stretch.recurrence!.statusOf(
        DateTime(2026, 5, day),
        time,
        done: stretch.progress.doneDays,
      );
      expect(on(12), DayStatus.untracked);
      expect(on(13), DayStatus.missed);
      expect(on(14), DayStatus.missed);
      expect(on(15), DayStatus.due);
    });

    test('start over as a new day begins', () async {
      await addStretch();
      await tasks.toggleDone(task("Stretch"));
      var changes = 0;
      tasks.addListener(() => changes++);
      tasks.checkForNewDay();
      expect(changes, 0);
      time = DateTime(2026, 5, 14, 0, 0, 1);
      tasks.checkForNewDay();
      expect(changes, 1);
      expect(tasks.today, DateTime(2026, 5, 14));
      expect(task("Stretch").done, isFalse);
      expect(task("Stretch").progress.isDoneOn(DateTime(2026, 5, 13)), isTrue);
    });

    test('start out done today when a done task becomes daily', () async {
      await add("Read");
      await tasks.toggleDone(task("Read"));
      final draft = tasks.draft(task("Read"))
        ..setTime(const ClockTime(21, 0))
        ..setReminder(Reminder.daily);
      await tasks.save(draft);
      final read = task("Read");
      expect(read.isDaily, isTrue);
      expect(read.done, isTrue);
      expect(read.progress.since, DateTime(2026, 5, 13));
      expect(read.progress.doneDays, {DateTime(2026, 5, 13)});
    });

    test(
      'stay as done as they were, with their days, once not daily',
      () async {
        await addStretch();
        await tasks.toggleDone(task("Stretch"));
        await tasks.toggleReminder(task("Stretch"));
        expect(task("Stretch").reminder, Reminder.none);
        expect(task("Stretch").done, isTrue);
        expect(notifications.daily, isEmpty);
        // No longer starting over each day.
        time = DateTime(2026, 5, 14, 9);
        await tasks.get();
        expect(task("Stretch").done, isTrue);
        expect(task("Stretch").progress.doneDays, {DateTime(2026, 5, 13)});
      },
    );

    test(
      "set their reminder again with the App Lock, even when done today",
      () async {
        await addStretch();
        await tasks.toggleDone(task("Stretch"));
        lock.lock = AppLock.password;
        lock.changed.add(AppLock.password);
        await pumpEventQueue();
        expect(notifications.bodies.values.single, isNull);
      },
    );

    test('from a backup older than their days count them from today', () async {
      final restoring = TasksViewModel(
        repository: repository,
        notificationService: notifications,
        lockService: lock,
        fileService: FakeFiles([
          {
            'title': "Stretch",
            'status': 1,
            'time': "7:00 AM",
            'uuid': "u-1",
            'notification': 2,
          },
          {
            'title': "Read",
            'status': 0,
            'time': "9:00 PM",
            'uuid': "u-2",
            'notification': 2,
            'since': "2026-05-01",
            'doneDays': "2026-05-11,2026-05-12",
          },
        ]),
        clock: () => time,
      );
      addTearDown(restoring.dispose);
      final result = await restoring.restore(
        true,
        askForBackupPassword: (open) async => false,
      );
      expect(result, isA<Success>());
      TodoItem restored(String title) =>
          restoring.items.singleWhere((task) => task.title == title);
      expect(restored("Stretch").progress.since, DateTime(2026, 5, 13));
      expect(restored("Stretch").done, isFalse);
      expect(restored("Read").progress.since, DateTime(2026, 5, 1));
      final read = restored("Read");
      expect(read.recurrence!.streak(time, done: read.progress.doneDays), 2);
      expect(notifications.daily, hasLength(2));
    });
  });

  group('weekly and monthly tasks', () {
    /// Adds a task at [time] through its form, repeating as [shape] has it.
    Future<Result> addRepeating(
      String title,
      void Function(TaskDraft) shape, {
      ClockTime time = const ClockTime(18, 0),
    }) {
      final draft = tasks.draft()
        ..setTitle(title)
        ..setTime(time);
      shape(draft);
      return tasks.save(draft);
    }

    /// Gym on Mondays, since the Monday before last, May 4.
    Future<TodoItem> addGym() async {
      await repository.insertItem(
        TodoItem(
          uuid: "gym",
          title: "Gym",
          time: const ClockTime(18, 0),
          reminder: Reminder.weekly,
          weekdays: {DateTime.monday},
          progress: RepeatProgress(since: DateTime(2026, 5, 4)),
        ),
      );
      await tasks.get();
      return task("Gym");
    }

    test(
      'come round on their days of the week, each with its reminder',
      () async {
        final result = await addRepeating(
          "Gym",
          (draft) => draft
            ..setReminder(Reminder.weekly)
            ..toggleWeekday(DateTime.monday)
            ..toggleWeekday(DateTime.thursday)
            ..toggleWeekday(DateTime.wednesday),
        );
        expect(result, isA<Success>());
        final gym = task("Gym");
        expect(gym.reminder, Reminder.weekly);
        expect(gym.weekdays, {DateTime.monday, DateTime.thursday});
        expect(gym.day, isNull);
        expect(gym.progress.since, DateTime(2026, 5, 13));
        final ids = ReminderPlan.idsOf(gym.uuid);
        expect(notifications.weekly, {
          ids[DateTime.monday]: DateTime(2026, 5, 18, 18),
          ids[DateTime.thursday]: DateTime(2026, 5, 14, 18),
        });
        // Until its first time, that one stands for it.
        expect(gym.occurrenceOn(now), DateTime(2026, 5, 14));
        expect(gym.isPastDue(now), isFalse);
      },
    );

    test('come round monthly on their day of the month', () async {
      await addRepeating(
        "Rent",
        (draft) => draft
          ..setReminder(Reminder.monthly)
          ..setMonthDay(1),
        time: const ClockTime(9, 0),
      );
      final rent = task("Rent");
      expect(rent.monthDay, 1);
      expect(notifications.monthly, {
        ReminderPlan.idOf(rent.uuid): DateTime(2026, 6, 1, 9),
      });
    });

    test('are done for today when they come round today', () async {
      await addRepeating("Swim", (draft) => draft.setReminder(Reminder.weekly));
      final result = await tasks.toggleDone(task("Swim"));
      expect((result as Success).message, "Done for today");
      expect(task("Swim").done, isTrue);
      expect(notifications.weekly, hasLength(1), reason: "they keep reminding");
    });

    test('can be done late, until their next time comes', () async {
      final missed = await addGym();
      expect(missed.done, isFalse);
      expect(missed.isPastDue(now), isTrue);
      final result = await tasks.toggleDone(missed);
      expect((result as Success).message, "Done for Mon, May 11");
      expect(task("Gym").done, isTrue);
      expect(repository.rows.single.progress.doneDays, {DateTime(2026, 5, 11)});

      // Monday comes round afresh.
      time = DateTime(2026, 5, 18, 9);
      tasks.checkForNewDay();
      final gym = task("Gym");
      expect(gym.done, isFalse);
      expect(gym.isPastDue(time), isFalse);
      expect(
        gym.recurrence!.statusOf(
          DateTime(2026, 5, 4),
          time,
          done: gym.progress.doneDays,
        ),
        DayStatus.missed,
      );
    });

    test('count from today once they come round on other days', () async {
      final before = await addGym();
      await tasks.save(tasks.draft(before)..toggleWeekday(DateTime.friday));
      final after = task("Gym");
      expect(after.weekdays, {DateTime.monday, DateTime.friday});
      expect(after.progress.since, DateTime(2026, 5, 13));
      // Monday's was from before, so the next one stands for it.
      expect(after.occurrenceOn(now), DateTime(2026, 5, 15));
      expect(after.isPastDue(now), isFalse);
      // Saved again as it is, it keeps counting from then.
      time = DateTime(2026, 5, 20, 9);
      await tasks.save(tasks.draft(task("Gym"))..setTitle("Gym!"));
      expect(task("Gym!").progress.since, DateTime(2026, 5, 13));
    });

    test('lose the reminders they had once they are changed', () async {
      await addRepeating(
        "Gym",
        (draft) => draft
          ..setReminder(Reminder.weekly)
          ..toggleWeekday(DateTime.friday),
      );
      expect(notifications.weekly, hasLength(2));
      await tasks.save(
        tasks.draft(task("Gym"))
          ..setReminder(Reminder.once)
          ..setDay(DateTime(2026, 5, 13)),
      );
      expect(notifications.weekly, isEmpty);
      expect(notifications.once.keys, [ReminderPlan.idOf(task("Gym").uuid)]);
      expect(task("Gym").weekdays, isEmpty);
    });

    test('lose all their reminders as they go to the trash', () async {
      await addRepeating(
        "Gym",
        (draft) => draft
          ..setReminder(Reminder.weekly)
          ..toggleWeekday(DateTime.friday),
      );
      final trashed = await tasks.delete(task("Gym"));
      expect(notifications.repeating, isEmpty);
      await tasks.restoreFromTrash(trashed!);
      expect(notifications.weekly, hasLength(2));
      expect(task("Gym").weekdays, {DateTime.wednesday, DateTime.friday});
    });

    test('are backed up and restored with their days', () async {
      final restoring = TasksViewModel(
        repository: repository,
        notificationService: notifications,
        lockService: lock,
        fileService: FakeFiles([
          {
            'title': "Gym",
            'status': 0,
            'time': "6:00 PM",
            'uuid': "u-1",
            'notification': 3,
            'weekdays': "1,4",
            'until': "2026-07-01",
            'since': "2026-05-04",
          },
        ]),
        clock: () => time,
      );
      addTearDown(restoring.dispose);
      await restoring.restore(
        true,
        askForBackupPassword: (open) async => false,
      );
      final gym = restoring.items.single;
      expect(
        gym.recurrence,
        Recurrence.weekly(
          {1, 4},
          since: DateTime(2026, 5, 4),
          until: DateTime(2026, 7, 1),
        ),
      );
      expect(notifications.weekly, hasLength(2));
    });
  });

  group('tasks that stop', () {
    /// Adds a task that reminds daily at 6 PM until [until].
    Future<Result> addPills(DateTime until) => tasks.save(
      tasks.draft()
        ..setTitle("Pills")
        ..setTime(const ClockTime(18, 0))
        ..setReminder(Reminder.daily)
        ..setUntil(until),
    );

    test('have their last few times set one by one', () async {
      await addPills(DateTime(2026, 5, 16));
      expect(task("Pills").until, DateTime(2026, 5, 16));
      expect(notifications.once.values, [
        for (var day = 13; day <= 16; day++) DateTime(2026, 5, day, 18),
      ]);
      expect(notifications.repeating, isEmpty);
    });

    test('repeat by themselves until their last few times', () async {
      await addPills(DateTime(2026, 6, 30));
      expect(notifications.daily.values, [const ClockTime(18, 0)]);
      expect(notifications.once, isEmpty);
      time = DateTime(2026, 6, 25, 0, 0, 1);
      tasks.checkForNewDay();
      await pumpEventQueue();
      expect(notifications.repeating, isEmpty);
      expect(notifications.once.values, [
        for (var day = 25; day <= 30; day++) DateTime(2026, 6, day, 18),
      ]);
    });

    test('have their reminders stop with them', () async {
      await addPills(DateTime(2026, 5, 14));
      expect(notifications.once, hasLength(2));
      time = DateTime(2026, 5, 15, 0, 0, 1);
      tasks.checkForNewDay();
      await pumpEventQueue();
      expect(notifications.once, isEmpty);
      expect(task("Pills").recurrence!.hasEndedBy(time), isTrue);
    });

    test(
      "set afresh as the app starts, as days went by while it didn't run",
      () async {
        await repository.insertItem(
          TodoItem(
            uuid: "pills",
            title: "Pills",
            time: const ClockTime(18, 0),
            reminder: Reminder.daily,
            until: DateTime(2026, 5, 12),
            progress: RepeatProgress(since: DateTime(2026, 5, 1)),
          ),
        );
        // Set to repeat by itself back when it had many times left.
        notifications.repeating[ReminderPlan.idOf("pills")] = (
          first: DateTime(2026, 5, 1, 18),
          every: RepeatEvery.day,
        );
        await tasks.get();
        expect(notifications.repeating, isEmpty);
      },
    );

    test('are saved without repeating when they would stop before they '
        'come round', () async {
      final draft = tasks.draft()
        ..setTitle("Gym")
        ..setTime(const ClockTime(18, 0))
        ..setReminder(Reminder.weekly)
        ..toggleWeekday(DateTime.friday)
        ..toggleWeekday(DateTime.wednesday)
        ..setUntil(DateTime(2026, 5, 14));
      final result = await tasks.save(draft);
      expect((result as Info).message, "Please set an end after its next time");
      expect(task("Gym").reminder, Reminder.none);
      expect(notifications.repeating, isEmpty);
    });

    test('keep their days when saved again once they have ended', () async {
      await repository.insertItem(
        TodoItem(
          uuid: "course",
          title: "Course",
          time: const ClockTime(7, 0),
          reminder: Reminder.daily,
          until: DateTime(2026, 5, 10),
          progress: RepeatProgress(
            since: DateTime(2026, 5, 1),
            doneDays: [DateTime(2026, 5, 10)],
          ),
        ),
      );
      await tasks.get();
      final draft = tasks.draft(task("Course"));
      expect(draft.reminderStatus(), ReminderStatus.ended);
      final result = await tasks.save(draft..setTitle("Course done"));
      expect((result as Info).message, "Task Updated");
      final course = task("Course done");
      expect(course.reminder, Reminder.daily);
      expect(course.until, DateTime(2026, 5, 10));
      expect(course.done, isTrue, reason: "its last time was done");
      expect(notifications.repeating, isEmpty);
      expect(notifications.once, isEmpty);
    });
  });

  group('subtasks', () {
    /// Adds a subtask to the task titled [parent], through its form.
    Future<Result> addIn(
      String parent,
      String title, {
      ClockTime? time,
      Reminder reminder = Reminder.none,
    }) {
      final draft = tasks.subtaskDraft(task(parent))
        ..setTitle(title)
        ..setReminder(reminder);
      if (time != null) draft.setTime(time);
      return tasks.save(draft);
    }

    /// The tasks on show as an outline: each task's title, two spaces in
    /// for each task it's inside of.
    String outline() => [
      for (final node in tasks.tree.nodes)
        "${"  " * node.depth}${node.task.title}",
    ].join("\n");

    /// A trip to plan, with shopping to do on the side.
    Future<void> plan() async {
      await add("Trip");
      await addIn("Trip", "Book");
      await addIn("Book", "Flights");
      await addIn("Book", "Hotel");
      await addIn("Trip", "Pack");
      await add("Shop");
      await addIn("Shop", "Milk");
    }

    const planned = """
Trip
  Book
    Flights
    Hotel
  Pack
Shop
  Milk""";

    test('go in the task they are added to, however deep', () async {
      await plan();
      expect(outline(), planned);
      expect(task("Hotel").parent, task("Book").uuid);
      expect(tasks.tree.nodeOf(task("Trip"))!.subtaskCount, 4);
      // Each one is a task like any other.
      expect(tasks.unfinishedTasksCount, 7);
      expect(tasks.items.map((each) => each.title), [
        "Trip",
        "Book",
        "Flights",
        "Hotel",
        "Pack",
        "Shop",
        "Milk",
      ]);
    });

    test(
      'are done with their task, which Undo takes back, reminders and all',
      () async {
        await add("Trip");
        await addIn(
          "Trip",
          "Book",
          time: const ClockTime(18, 0),
          reminder: Reminder.once,
        );
        await addIn("Trip", "Pack");
        await tasks.toggleDone(task("Pack"));
        expect(notifications.once, hasLength(1));

        final result = await tasks.toggleDone(task("Trip"));
        expect(result, isA<Undoable>());
        // The other one was done already.
        expect(
          (result as Undoable).message,
          "Task done, with its last subtask",
        );
        expect(tasks.items.every((each) => each.done), isTrue);
        expect(task("Book").reminder, Reminder.none);
        expect(notifications.once, isEmpty);

        expect(await result.undo(), isA<Success>());
        expect(task("Trip").done, isFalse);
        expect(task("Book").done, isFalse);
        expect(task("Pack").done, isTrue);
        expect(task("Book").reminder, Reminder.once);
        expect(notifications.once.keys, [ReminderPlan.idOf(task("Book").uuid)]);
      },
    );

    test('says how many were done with it', () async {
      await plan();
      final result = await tasks.toggleDone(task("Trip"));
      expect((result as Undoable).message, "Task done, with its 4 subtasks");
      expect(tasks.finishedTasksCount, 5);
    });

    test('says so when only the ones still to do were done with it', () async {
      await plan();
      await tasks.toggleDone(task("Flights"));
      await tasks.toggleDone(task("Pack"));
      final result = await tasks.toggleDone(task("Trip"));
      expect(
        (result as Undoable).message,
        "Task done, with its last 2 subtasks",
      );
      await result.undo();
      await tasks.toggleDone(task("Book"));
      expect(
        (await tasks.toggleDone(task("Book")) as Undoable).message,
        isNot(contains("subtask")),
      );
    });

    test('finish their task once the last of them is done', () async {
      await plan();
      expect(await tasks.toggleDone(task("Flights")), isA<Success>());
      expect(await tasks.toggleDone(task("Pack")), isNot(isA<Undoable>()));
      final result = await tasks.toggleDone(task("Hotel"));
      expect((result as Undoable).message, "Task done. That finishes “Book”");
      expect(task("Book").done, isTrue);
      expect(task("Trip").done, isTrue);
      expect(task("Shop").done, isFalse);

      await result.undo();
      expect(task("Hotel").done, isFalse);
      expect(task("Book").done, isFalse);
      expect(task("Trip").done, isFalse);
      expect(task("Flights").done, isTrue);
    });

    test('leave their task to do when one is not done after all', () async {
      await plan();
      await tasks.toggleDone(task("Trip"));
      final result = await tasks.toggleDone(task("Hotel"));
      expect(
        (result as Undoable).message,
        "Task undone, and the 2 tasks it's in",
      );
      expect(task("Hotel").done, isFalse);
      expect(task("Book").done, isFalse);
      expect(task("Trip").done, isFalse);
      expect(task("Flights").done, isTrue);
      // The tasks in a task stay done when it's to do again.
      await tasks.toggleDone(task("Trip"));
      expect(await tasks.toggleDone(task("Trip")), isA<Info>());
      expect(task("Book").done, isTrue);
    });

    test('still to do leave the done task they are added to to do', () async {
      await add("Trip");
      await addIn("Trip", "Book");
      await tasks.toggleDone(task("Trip"));
      expect(task("Trip").done, isTrue);
      await addIn("Trip", "Pack");
      expect(task("Trip").done, isFalse);
      expect(task("Book").done, isTrue);
    });

    test('are done for the day with a daily task', () async {
      await add(
        "Routine",
        time: const ClockTime(7, 0),
        reminder: Reminder.daily,
      );
      await addIn(
        "Routine",
        "Stretch",
        time: const ClockTime(7, 5),
        reminder: Reminder.daily,
      );
      await addIn("Routine", "Water");
      final result = await tasks.toggleDone(task("Stretch"));
      expect((result as Success).message, "Done for today");
      await tasks.toggleDone(task("Water"));
      expect(task("Routine").done, isTrue);
      expect(task("Routine").progress.doneDays, {DateTime(2026, 5, 13)});
      expect(notifications.daily, hasLength(2));

      // The next day starts the daily ones over, and not the other.
      time = DateTime(2026, 5, 14, 8);
      await tasks.get();
      expect(task("Routine").done, isFalse);
      expect(task("Stretch").done, isFalse);
      expect(task("Water").done, isTrue);
      final again = await tasks.toggleDone(task("Stretch"));
      expect(
        (again as Undoable).message,
        "Done for today. That finishes “Routine”",
      );
    });

    test('unfold the task they are added to', () async {
      await add("Trip");
      await addIn("Trip", "Book");
      await tasks.setFolded(task("Trip"), true);
      expect(repository.rows.first.folded, isTrue);
      await addIn("Trip", "Pack");
      expect(task("Trip").folded, isFalse);
      expect(repository.rows.first.folded, isFalse);
    });

    test('are filtered with their tasks, each kept where it belongs', () async {
      await plan();
      await tasks.toggleDone(task("Book"));
      await tasks.setFilter(TaskFilter.undone);
      expect(outline(), "Trip\n  Pack\nShop\n  Milk");
      // How far along a task is counts the ones the filter hides too.
      final trip = tasks.tree.nodeOf(task("Trip"))!;
      expect((trip.doneSubtaskCount, trip.subtaskCount), (3, 4));
      await tasks.setFilter(TaskFilter.done);
      expect(outline(), "Book\n  Flights\n  Hotel");
      await tasks.setFilter(TaskFilter.all);
      expect(outline().split("\n"), hasLength(7));
    });

    group('in the trash', () {
      test(
        'go there with their task, as one entry, and come back with it',
        () async {
          await plan();
          await addIn(
            "Hotel",
            "Pay",
            time: const ClockTime(18, 0),
            reminder: Reminder.once,
          );
          final trashed = await tasks.delete(task("Book"));
          expect(outline(), "Trip\n  Pack\nShop\n  Milk");
          expect(tasks.trash, hasLength(1));
          expect(trashed!.item.task.title, "Book");
          expect(trashed.item.subtasks.map((each) => each.title), [
            "Flights",
            "Hotel",
            "Pay",
          ]);
          expect(notifications.once, isEmpty);

          expect(await tasks.restoreFromTrash(trashed), isA<Success>());
          expect(outline(), """
Trip
  Book
    Flights
    Hotel
      Pay
  Pack
Shop
  Milk""");
          expect(notifications.once.keys, [
            ReminderPlan.idOf(task("Pay").uuid),
          ]);
          expect(tasks.trash, isEmpty);
        },
      );

      test('are off the list with their task straight away', () async {
        await plan();
        final deleting = tasks.delete(task("Trip"));
        expect(outline(), "Shop\n  Milk");
        await deleting;
        expect(repository.rows.map((each) => each.title), ["Shop", "Milk"]);
      });

      test(
        'put back without their task wait for it as tasks of their own',
        () async {
          await plan();
          final milk = await tasks.delete(task("Milk"));
          final shop = await tasks.delete(task("Shop"));
          await tasks.restoreFromTrash(milk!);
          expect(outline().split("\n").last, "Milk");
          expect(tasks.tree.nodeOf(task("Milk"))!.parent, isNull);
          await tasks.restoreFromTrash(shop!);
          expect(tasks.tree.nodeOf(task("Milk"))!.parent!.task.title, "Shop");
        },
      );

      test('all come back in their tasks with Restore All', () async {
        await plan();
        await tasks.delete(task("Hotel"));
        await tasks.delete(task("Trip"));
        final result = await tasks.restoreAllFromTrash();
        expect((result as Success).message, "2 Tasks Restored");
        final book = tasks.tree.nodeOf(task("Book"))!;
        expect(
          book.children.map((node) => node.task.title),
          unorderedEquals(["Flights", "Hotel"]),
        );
        expect(tasks.tree.nodeOf(task("Trip"))!.subtaskCount, 4);
      });

      test('follow a task put back under a new uuid', () async {
        await add("Trip");
        await addIn("Trip", "Book");
        final trashed = await tasks.delete(task("Trip"));
        // As a backup restored since might bring it back.
        await repository.insertItem(trashed!.item.task);
        await tasks.restoreFromTrash(trashed);
        final trips = tasks.tree.roots
            .where((node) => node.task.title == "Trip")
            .toList();
        expect(trips, hasLength(2));
        expect(trips.map((node) => node.task.uuid).toSet(), hasLength(2));
        final putBack = trips.singleWhere(
          (node) => node.task.uuid != trashed.item.task.uuid,
        );
        expect(putBack.children.single.task.title, "Book");
      });

      test('still to do leave the done task they come back to to do', () async {
        await add("Trip");
        await addIn("Trip", "Book");
        await addIn("Trip", "Pack");
        final book = await tasks.delete(task("Book"));
        await tasks.toggleDone(task("Trip"));
        expect(task("Trip").done, isTrue);
        await tasks.restoreFromTrash(book!);
        expect(task("Trip").done, isFalse);
        expect(task("Pack").done, isTrue);
      });
    });

    group('moving', () {
      int at(String title) =>
          tasks.items.indexWhere((each) => each.title == title);

      test('a dragged task lines up with the task below it', () async {
        await plan();
        // Dropped between Flights and Hotel: where Hotel was, as it comes
        // from below them.
        await tasks.syncAfterReorder(at("Shop"), at("Hotel"));
        expect(outline(), """
Trip
  Book
    Flights
    Shop
      Milk
    Hotel
  Pack""");
        // Then back out, ahead of Trip.
        await tasks.syncAfterReorder(at("Shop"), 0);
        expect(outline(), """
Shop
  Milk
Trip
  Book
    Flights
    Hotel
  Pack""");
        expect(task("Shop").parent, isNull);
      });

      test('a task dragged to the end is a task of its own', () async {
        await plan();
        await tasks.syncAfterReorder(at("Hotel"), tasks.items.length - 1);
        expect(outline().split("\n").last, "Hotel");
        expect(task("Hotel").parent, isNull);
      });

      test('a task dragged under its own subtasks stays where it is', () async {
        await plan();
        await tasks.syncAfterReorder(at("Book"), at("Hotel") - 1);
        expect(outline(), planned);
      });

      test(
        'a task is not dropped among the subtasks of a folded task',
        () async {
          await plan();
          await tasks.setFolded(task("Trip"), true);
          // Dropped right under Trip, whose subtasks are folded away: it
          // lines up with Shop, the next task on show.
          await add("Call");
          await tasks.syncAfterReorder(at("Call"), at("Trip") + 1);
          expect(outline(), """
Trip
  Book
    Flights
    Hotel
  Pack
Call
Shop
  Milk""");
        },
      );

      test(
        'a task dropped back by tasks that are folded away stays put',
        () async {
          await plan();
          await addIn("Trip", "Visa");
          await tasks.setFolded(task("Book"), true);
          await tasks.setFolded(task("Shop"), true);
          final before = outline();
          // Pack, between the folded Book and Visa: put down among Book's
          // folded subtasks, it's still between the two.
          await tasks.syncAfterReorder(at("Pack"), at("Hotel"));
          expect(outline(), before);
          // And Shop, last on show: put down among its own folded subtask.
          await tasks.syncAfterReorder(at("Shop"), at("Milk"));
          expect(outline(), before);
          expect(task("Shop").parent, isNull);
          // Visa, the last of Trip's, isn't taken out of it either.
          await tasks.syncAfterReorder(at("Visa"), at("Visa") - 1 + 1);
          expect(task("Visa").parent, task("Trip").uuid);
        },
      );

      test(
        'into a task makes it the last of its subtasks, and unfolds it',
        () async {
          await plan();
          await tasks.setFolded(task("Shop"), true);
          expect(await tasks.moveInto(task("Book"), task("Shop")), isNull);
          expect(outline(), """
Trip
  Pack
Shop
  Milk
  Book
    Flights
    Hotel""");
          expect(task("Shop").folded, isFalse);
          expect(await tasks.moveInto(task("Book"), null), isNull);
          expect(tasks.tree.roots.map((node) => node.task.title), [
            "Trip",
            "Shop",
            "Book",
          ]);
        },
      );

      test('next to a task puts it ahead of it, or right after it', () async {
        await plan();
        await tasks.moveBeside(task("Milk"), task("Flights"), after: true);
        expect(
          tasks.tree
              .nodeOf(task("Book"))!
              .children
              .map((node) => node.task.title),
          ["Flights", "Milk", "Hotel"],
        );
        await tasks.moveBeside(task("Milk"), task("Trip"), after: false);
        expect(tasks.tree.roots.map((node) => node.task.title), [
          "Milk",
          "Trip",
          "Shop",
        ]);
        await tasks.moveBeside(task("Milk"), task("Shop"), after: true);
        expect(tasks.tree.roots.map((node) => node.task.title), [
          "Trip",
          "Shop",
          "Milk",
        ]);
      });

      test('a task cannot go inside itself, or a task in it', () async {
        await plan();
        expect(await tasks.moveInto(task("Trip"), task("Hotel")), isA<Info>());
        expect(await tasks.moveInto(task("Trip"), task("Trip")), isA<Info>());
        expect(outline(), planned);
      });

      test('keeps reminders with their tasks, whose ids all change', () async {
        await plan();
        await addIn(
          "Shop",
          "Eggs",
          time: const ClockTime(18, 0),
          reminder: Reminder.once,
        );
        final eggs = task("Eggs");
        await tasks.moveInto(eggs, task("Trip"));
        expect(task("Eggs").id, isNot(eggs.id));
        expect(task("Eggs").reminder, Reminder.once);
        // A command given the task as it was still finds it.
        await tasks.toggleDone(eggs);
        expect(task("Eggs").done, isTrue);
        expect(notifications.once, isEmpty);
      });

      test(
        'a task still to do leaves the done task it goes into to do',
        () async {
          await plan();
          await tasks.toggleDone(task("Shop"));
          await tasks.moveInto(task("Pack"), task("Shop"));
          expect(task("Shop").done, isFalse);
          expect(task("Milk").done, isTrue);
        },
      );
    });

    group('in the form', () {
      test('a new subtask starts in the task it was added to', () async {
        await add("Trip");
        final draft = tasks.subtaskDraft(task("Trip"));
        expect(draft.adding, isTrue);
        expect(draft.parent!.title, "Trip");
        expect(draft.moved, isFalse);
      });

      test('a task can go in any task but itself and the ones in it', () async {
        await plan();
        final draft = tasks.draft(task("Book"));
        expect(draft.parent!.title, "Trip");
        expect(draft.places.map((node) => node.task.title), [
          "Trip",
          "Pack",
          "Shop",
          "Milk",
        ]);
        expect(tasks.draft().places, hasLength(7));
      });

      test('saving it with another task picked moves it there', () async {
        await plan();
        await addIn(
          "Shop",
          "Eggs",
          time: const ClockTime(18, 0),
          reminder: Reminder.once,
        );
        final draft = tasks.draft(task("Eggs"))
          ..setTitle("Fresh eggs")
          ..setParent(task("Trip"));
        expect(draft.moved, isTrue);
        final result = await tasks.save(draft);
        expect((result as Info).message, startsWith("Time remaining"));
        expect(
          tasks.tree.nodeOf(task("Fresh eggs"))!.parent!.task.title,
          "Trip",
        );
        expect(task("Fresh eggs").reminder, Reminder.once);
        expect(notifications.once.keys, [
          ReminderPlan.idOf(task("Fresh eggs").uuid),
        ]);
        expect(tasks.items.where((each) => each.title == "Eggs"), isEmpty);
      });

      test(
        'saving it with no task picked makes it a task of its own',
        () async {
          await plan();
          final draft = tasks.draft(task("Hotel"))..setParent(null);
          expect((await tasks.save(draft) as Info).message, "Task Updated");
          expect(task("Hotel").parent, isNull);
          expect(tasks.tree.roots.last.task.title, "Hotel");
        },
      );

      test('saving it as it was leaves it where it is', () async {
        await plan();
        final draft = tasks.draft(task("Flights"))..setTitle("Fly");
        expect(draft.moved, isFalse);
        await tasks.save(draft);
        expect(outline(), planned.replaceFirst("Flights", "Fly"));
      });
    });

    test('are backed up and restored in their tasks', () async {
      final restoring = TasksViewModel(
        repository: repository,
        notificationService: notifications,
        lockService: lock,
        fileService: FakeFiles([
          {'title': "Milk", 'status': 0, 'uuid': "u-2", 'parent': "u-1"},
          {'title': "Shop", 'status': 1, 'uuid': "u-1", 'folded': 1},
          {'title': "Old", 'status': 0, 'uuid': "u-3"},
        ]),
        clock: () => time,
      );
      addTearDown(restoring.dispose);
      await restoring.restore(
        true,
        askForBackupPassword: (open) async => false,
      );
      final shop = restoring.tree.roots.first;
      expect(shop.task.title, "Shop");
      expect(shop.task.folded, isTrue);
      expect(shop.children.single.task.title, "Milk");
      // Not done, with a subtask still to do.
      expect(shop.task.done, isFalse);
      expect(restoring.tree.roots.last.task.title, "Old");
      expect(repository.rows.map((row) => row.toMap()['parent']), [
        "u-1",
        "",
        "",
      ]);
    });
  });

  group('emptyReason', () {
    test('says there are no tasks, or why the filter shows none', () async {
      await tasks.get();
      expect(tasks.emptyReason, EmptyTasksReason.noTasks);
      await add("Call");
      expect(tasks.emptyReason, isNull);
      await tasks.setFilter(TaskFilter.done);
      expect(tasks.emptyReason, EmptyTasksReason.noneDone);
      await tasks.toggleDone(repository.rows.single);
      await tasks.get();
      await tasks.setFilter(TaskFilter.undone);
      expect(tasks.emptyReason, EmptyTasksReason.allDone);
      await tasks.setFilter(TaskFilter.daily);
      expect(tasks.emptyReason, EmptyTasksReason.noneDaily);
      await tasks.setFilter(TaskFilter.weekly);
      expect(tasks.emptyReason, EmptyTasksReason.noneWeekly);
      await tasks.setFilter(TaskFilter.monthly);
      expect(tasks.emptyReason, EmptyTasksReason.noneMonthly);
      await tasks.setFilter(TaskFilter.once);
      expect(tasks.emptyReason, isNull);
    });

    test('says when every task repeats, for the Once filter', () async {
      await add(
        "Stretch",
        time: const ClockTime(7, 0),
        reminder: Reminder.daily,
      );
      await tasks.setFilter(TaskFilter.once);
      expect(tasks.emptyReason, EmptyTasksReason.noneOnce);
    });
  });

  group('sorting and filtering', () {
    /// Puts [rows] in the table, then reads them in.
    Future<void> seed(List<TodoItem> rows) async {
      for (final row in rows) {
        await repository.insertItem(row);
      }
      await tasks.get();
    }

    List<String> titles() => [for (final task in tasks.items) task.title];

    /// The tasks on show as an outline: each task's title, two spaces in
    /// for each task it's inside of.
    String outline() => [
      for (final node in tasks.tree.nodes)
        "${"  " * node.depth}${node.task.title}",
    ].join("\n");

    TodoItem on(
      String title,
      int? day, {
      ClockTime? time,
      String? parent,
      bool done = false,
    }) => TodoItem(
      uuid: title.toLowerCase(),
      title: title,
      day: day == null ? null : DateTime(2026, 5, day),
      time: time,
      parent: parent,
      done: done,
    );

    /// Since the start of the month, at 6 PM.
    TodoItem repeating(
      String title,
      Reminder reminder, {
      Set<int> weekdays = const {},
      int? monthDay,
    }) => TodoItem(
      uuid: title.toLowerCase(),
      title: title,
      time: const ClockTime(18, 0),
      reminder: reminder,
      weekdays: weekdays,
      monthDay: monthDay,
      progress: RepeatProgress(since: DateTime(2026, 5, 1)),
    );

    test('start with every task, in the user\'s own order', () async {
      await tasks.get();
      expect(tasks.filter, TaskFilter.all);
      expect(tasks.sort, TaskSort.custom);
      expect(tasks.sortDirection, SortDirection.ascending);
      // Nothing's kept until they're changed.
      expect(repository.listing, isNull);
    });

    test('are kept, and the next start lists the tasks by them', () async {
      await seed([
        on("Later", 20),
        on("Done", 13, done: true),
        on("Sooner", 14),
      ]);
      await tasks.setFilter(TaskFilter.undone);
      await tasks.setSort(
        TaskSort.dueDate,
        direction: SortDirection.descending,
      );
      const kept = TaskListing(
        filter: TaskFilter.undone,
        sort: TaskSort.dueDate,
        direction: SortDirection.descending,
      );
      expect(repository.listing, kept);

      final next = TasksViewModel(
        repository: repository,
        notificationService: notifications,
        lockService: lock,
        clock: () => time,
      );
      addTearDown(next.dispose);
      await next.get();
      expect(
        (next.filter, next.sort, next.sortDirection),
        (TaskFilter.undone, TaskSort.dueDate, SortDirection.descending),
      );
      expect([for (final task in next.items) task.title], ["Later", "Sooner"]);
    });

    test('hold until the app closes when they can\'t be kept', () async {
      await seed([on("Later", 20), on("Sooner", 14)]);
      repository.failListing = true;
      await tasks.setSort(TaskSort.dueDate);
      expect(titles(), ["Sooner", "Later"]);
      expect(repository.listing, isNull);
    });

    test('filter by how often the tasks come round, counting each', () async {
      await seed([
        on("Call", null, done: true),
        on("Dentist", 20, time: const ClockTime(9, 0)),
        repeating("Stretch", Reminder.daily),
        repeating("Gym", Reminder.weekly, weekdays: {DateTime.monday}),
        repeating("Rent", Reminder.monthly, monthDay: 1),
      ]);
      expect(
        {for (final filter in TaskFilter.values) filter: tasks.countOf(filter)},
        {
          TaskFilter.all: 5,
          TaskFilter.done: 1,
          TaskFilter.undone: 4,
          TaskFilter.daily: 1,
          TaskFilter.weekly: 1,
          TaskFilter.monthly: 1,
          TaskFilter.once: 2,
        },
      );
      await tasks.setFilter(TaskFilter.daily);
      expect(titles(), ["Stretch"]);
      await tasks.setFilter(TaskFilter.weekly);
      expect(titles(), ["Gym"]);
      await tasks.setFilter(TaskFilter.monthly);
      expect(titles(), ["Rent"]);
      await tasks.setFilter(TaskFilter.once);
      expect(titles(), ["Call", "Dentist"]);
      // The counts don't go by the filter.
      expect(tasks.countOf(TaskFilter.all), 5);
    });

    test('sort by due date, each task among the ones next to it, '
        'and those without a day last', () async {
      await seed([
        on("Trip", 20),
        on("Pack", 19, parent: "trip"),
        on("Book", 14, parent: "trip"),
        on("Visa", null, parent: "trip"),
        on("Shop", null),
        on("Milk", 13, time: const ClockTime(8, 0), parent: "shop"),
        on("Call", 13, time: const ClockTime(17, 0)),
      ]);
      const custom = "Trip\n  Pack\n  Book\n  Visa\nShop\n  Milk\nCall";
      expect(outline(), custom);

      await tasks.setSort(TaskSort.dueDate);
      expect(outline(), "Call\nTrip\n  Book\n  Pack\n  Visa\nShop\n  Milk");
      await tasks.setSort(
        TaskSort.dueDate,
        direction: SortDirection.descending,
      );
      expect(outline(), "Trip\n  Pack\n  Book\n  Visa\nCall\nShop\n  Milk");
      expect(tasks.items.first.title, "Trip");

      // With a filter as well.
      await tasks.toggleDone(task("Pack"));
      await tasks.setFilter(TaskFilter.undone);
      expect(outline(), "Trip\n  Book\n  Visa\nCall\nShop\n  Milk");

      await tasks.setFilter(TaskFilter.all);
      await tasks.setSort(TaskSort.custom);
      expect(outline(), custom);
      // The table keeps the user's own order all along.
      expect(repository.rows.map((row) => row.title), [
        "Trip",
        "Pack",
        "Book",
        "Visa",
        "Shop",
        "Milk",
        "Call",
      ]);
    });

    test('keep which way they were sorted, for the next time', () async {
      await seed([on("Later", 20), on("Sooner", 14)]);
      await tasks.setSort(
        TaskSort.dueDate,
        direction: SortDirection.descending,
      );
      await tasks.setSort(TaskSort.custom);
      expect(tasks.sortDirection, SortDirection.descending);
      expect(titles(), ["Later", "Sooner"]);
      await tasks.setSort(TaskSort.dueDate);
      expect(tasks.sortDirection, SortDirection.descending);
      expect(titles(), ["Later", "Sooner"]);
      await tasks.setSort(TaskSort.dueDate, direction: SortDirection.ascending);
      expect(titles(), ["Sooner", "Later"]);
    });

    test(
      'go by the time that stands for a repeating task, day by day',
      () async {
        await seed([
          on("Dentist", 12, time: const ClockTime(9, 0)),
          // Monday the 11th stands for it, until the 18th.
          repeating("Gym", Reminder.weekly, weekdays: {DateTime.monday}),
        ]);
        await tasks.setSort(TaskSort.dueDate);
        expect(titles(), ["Gym", "Dentist"]);
        time = DateTime(2026, 5, 18, 12);
        tasks.checkForNewDay();
        expect(titles(), ["Dentist", "Gym"]);
      },
    );

    test(
      "can't be reordered by hand while they're sorted by due date",
      () async {
        await seed([on("Later", 20), on("Sooner", 14), on("Someday", null)]);
        await tasks.setSort(TaskSort.dueDate);
        expect(titles(), ["Sooner", "Later", "Someday"]);
        await tasks.syncAfterReorder(0, 3);
        expect(titles(), ["Sooner", "Later", "Someday"]);
        expect(repository.rows.map((row) => row.title), [
          "Later",
          "Sooner",
          "Someday",
        ]);

        await tasks.setSort(TaskSort.custom);
        await tasks.syncAfterReorder(0, 3);
        expect(titles(), ["Sooner", "Someday", "Later"]);
      },
    );
  });

  group('trash', () {
    List<String> titles() => [for (final task in tasks.items) task.title];
    List<String> inTrash() => [
      for (final entry in tasks.trash) entry.item.task.title,
    ];

    test(
      'deleting a task moves it there, and turns its reminder off',
      () async {
        await add(
          "Call",
          time: const ClockTime(18, 0),
          reminder: Reminder.once,
        );
        await add("Shop");
        final trashed = await tasks.delete(task("Call"));
        expect(trashed!.item.task.title, "Call");
        expect(trashed.deletedAt, now);
        expect(titles(), ["Shop"]);
        expect(inTrash(), ["Call"]);
        expect(notifications.once, isEmpty);
      },
    );

    test('a task that cannot be moved there stays on the list', () async {
      await add("Call");
      repository.failMoves = true;
      expect(await tasks.delete(task("Call")), isNull);
      expect(titles(), ["Call"]);
      expect(tasks.trash, isEmpty);
    });

    test('lists the last deleted first', () async {
      await add("First");
      await add("Second");
      await tasks.delete(task("First"));
      await tasks.delete(task("Second"));
      expect(inTrash(), ["Second", "First"]);
    });

    test('undo puts a task back where it was, with its reminder', () async {
      await add("First");
      await add("Call", time: const ClockTime(18, 0), reminder: Reminder.once);
      await add("Last");
      final trashed = await tasks.delete(task("Call"));
      expect(await tasks.restoreFromTrash(trashed!), isA<Success>());
      expect(titles(), ["First", "Call", "Last"]);
      expect(task("Call").reminder, Reminder.once);
      expect(notifications.once.keys, [ReminderPlan.idOf(task("Call").uuid)]);
      expect(tasks.trash, isEmpty);
    });

    test("puts a task back once, however often it's asked", () async {
      await add("Call");
      final trashed = await tasks.delete(task("Call"));
      await tasks.restoreFromTrash(trashed!);
      expect(await tasks.restoreFromTrash(trashed), isA<Info>());
      expect(titles(), ["Call"]);
    });

    test("doesn't remind of a task put back after its time has gone", () async {
      await add("Call", time: const ClockTime(18, 0), reminder: Reminder.once);
      final trashed = await tasks.delete(task("Call"));
      time = DateTime(2026, 5, 13, 19);
      expect(await tasks.restoreFromTrash(trashed!), isA<Success>());
      expect(notifications.once, isEmpty);
    });

    test(
      'a task put back takes a new uuid when one on the list has its own',
      () async {
        await add(
          "Call",
          time: const ClockTime(18, 0),
          reminder: Reminder.once,
        );
        final trashed = await tasks.delete(task("Call"));
        // As a backup restored since might bring it back.
        await repository.insertItem(trashed!.item.task);
        notifications.once.clear();
        await tasks.restoreFromTrash(trashed);
        final calls = tasks.items.where((task) => task.title == "Call");
        expect(calls, hasLength(2));
        final putBack = calls.singleWhere(
          (task) => task.uuid != trashed.item.task.uuid,
        );
        expect(notifications.once.keys, [ReminderPlan.idOf(putBack.uuid)]);
      },
    );

    test("a daily task put back keeps its days, and reminds again", () async {
      await add(
        "Stretch",
        time: const ClockTime(7, 0),
        reminder: Reminder.daily,
      );
      await tasks.toggleDone(task("Stretch"));
      final trashed = await tasks.delete(task("Stretch"));
      expect(notifications.daily, isEmpty);
      await tasks.restoreFromTrash(trashed!);
      expect(task("Stretch").done, isTrue);
      expect(task("Stretch").progress.doneDays, {DateTime(2026, 5, 13)});
      expect(notifications.daily.values.single, const ClockTime(7, 0));
    });

    test('puts every task back', () async {
      await add("First");
      await add("Second");
      await add("Third");
      await tasks.delete(task("Third"));
      await tasks.delete(task("First"));
      final result = await tasks.restoreAllFromTrash();
      expect((result as Success).message, "2 Tasks Restored");
      expect(titles(), ["First", "Second", "Third"]);
      expect(tasks.trash, isEmpty);
    });

    test('deletes a task for good, or all of them', () async {
      await add("First");
      await add("Second");
      await add("Third");
      final first = await tasks.delete(task("First"));
      await tasks.delete(task("Second"));
      await tasks.delete(task("Third"));
      expect(await tasks.deleteForever(first!), isA<Info>());
      expect(inTrash(), ["Third", "Second"]);
      expect(await tasks.restoreFromTrash(first), isA<Info>());
      expect(titles(), isEmpty);
      final result = await tasks.emptyTrash();
      expect((result as Info).message, "2 Tasks Deleted Forever");
      expect(tasks.trash, isEmpty);
      expect(repository.trash, isEmpty);
    });
  });
}
