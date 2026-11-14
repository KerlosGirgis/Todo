import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/result.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/daily_progress.dart';
import 'package:todo/models/task_filters.dart';
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

  TodoItem _withId(TodoItem task) => TodoItem.fromMap(
      {...task.toMap(), 'id': _nextId++});

  @override
  Future<int> insertItem(TodoItem item) async {
    final row = _withId(item);
    rows.add(row);
    return row.id!;
  }

  @override
  Future<List<TodoItem>> getItems() async => List.of(rows);

  @override
  Future<void> deleteItem(int id) async =>
      rows.removeWhere((row) => row.id == id);

  @override
  Future<void> updateItem(TodoItem item) async {
    final index = rows.indexWhere((row) => row.id == item.id);
    if (index != -1) rows[index] = item;
  }

  @override
  Future<void> updateItems(Iterable<TodoItem> items) async {
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
  Future<void> importItems(List<TodoItem> items,
      {required bool overwrite}) async {
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
  Future<Trashed<TaskBranch>> moveToTrash(TaskBranch branch,
      {required DateTime deletedAt}) async {
    if (failMoves) throw StateError("Disk full");
    final ids = {for (final task in branch.all) task.id};
    if (rows.every((row) => row.id != branch.task.id)) {
      throw StateError("No task ${branch.task.id}");
    }
    rows.removeWhere((row) => ids.contains(row.id));
    final id = _nextTrashId++;
    trash.add(Trashed(
      id: id,
      // As it's read back: from its JSON, with the id its task had.
      item: TaskBranch.fromMap({...branch.toMap(), 'id': branch.task.id}),
      deletedAt: deletedAt,
    ));
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
        (task) => task.id != null && rows.every((row) => row.id != task.id));
    if (!free) {
      // Past every id there is, as some rows come with their own.
      _nextId =
          rows.fold(_nextId, (top, row) => top > row.id! ? top : row.id! + 1);
    }
    int? first;
    for (final task in branch.all) {
      final row =
          TodoItem.fromMap({...task.toMap(), 'id': free ? task.id : _nextId++});
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
  final daily = <int, ClockTime>{};
  final bodies = <int, String?>{};

  @override
  String timeZone = "Africa/Cairo";

  /// The time zone the reminders were all set in: the phone's, unless a test
  /// says otherwise.
  String? setIn = "Africa/Cairo";

  @override
  Future<String?> remindersTimeZone() async => setIn;

  @override
  Future<void> setRemindersTimeZone(String timeZone) async => setIn = timeZone;

  @override
  Future<void> scheduleNotification(
      int id, String title, String? body, DateTime scheduledTime) async {
    once[id] = scheduledTime;
    bodies[id] = body;
  }

  @override
  Future<void> scheduleDailyNotification(
      int id, String title, String? body, ClockTime scheduledTime) async {
    daily[id] = scheduledTime;
    bodies[id] = body;
  }

  @override
  Future<void> cancelNotification(int id) async {
    once.remove(id);
    daily.remove(id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    once.clear();
    daily.clear();
  }

  @override
  Future<void> cancelPendingNotifications() async {
    once.clear();
    daily.clear();
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
  Future<Result> add(String title,
      {DateTime? day, ClockTime? time, Reminder reminder = Reminder.none}) {
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
      expect(draft.reminderStatus(now), ReminderStatus.off);
      draft.setReminder(Reminder.once);
      expect(draft.reminderStatus(now), ReminderStatus.needsDayAndTime);
      draft.setTime(const ClockTime(11, 0));
      expect(draft.reminderStatus(now), ReminderStatus.inPast);
      draft.setTime(const ClockTime(13, 0));
      expect(draft.reminderStatus(now), ReminderStatus.ready);
      draft
        ..setTime(null)
        ..setReminder(Reminder.daily);
      expect(draft.reminderStatus(now), ReminderStatus.needsTime);
      draft.setTime(const ClockTime(7, 0));
      expect(draft.reminderStatus(now), ReminderStatus.ready);
    });

    test('starts from the task it changes', () {
      final draft = tasks.draft(TodoItem(
        uuid: "u",
        title: "Old",
        desc: "d",
        day: DateTime(2026, 5, 20),
        time: const ClockTime(9, 0),
        reminder: Reminder.once,
      ));
      expect(draft.adding, isFalse);
      expect(draft.title, "Old");
      expect(draft.description, "d");
      expect(draft.day, DateTime(2026, 5, 20));
      expect(draft.time, const ClockTime(9, 0));
      expect(draft.reminder, Reminder.once);
    });
  });

  group('saving', () {
    test('adds a task with a reminder still to come', () async {
      final result = await add("Call",
          time: const ClockTime(18, 0), reminder: Reminder.once);
      expect(result, isA<Info>());
      expect((result as Info).message, startsWith("Time remaining"));
      final call = task("Call");
      expect(call.reminder, Reminder.once);
      expect(notifications.once[call.uuid.hashCode], DateTime(2026, 5, 13, 18));
    });

    test('adds a task without a reminder that has already gone', () async {
      final result = await add("Late",
          time: const ClockTime(9, 0), reminder: Reminder.once);
      expect((result as Info).message, "Please set time and date in the future");
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
          (result as Info).message, startsWith("Task undone. Time remaining"));
      final call = task("Call");
      expect(call.done, isFalse);
      expect(call.reminder, Reminder.once);
      expect(notifications.once[call.uuid.hashCode], DateTime(2026, 5, 13, 18));
    });

    test('a done task stays done when its reminder has already gone', () async {
      await add("Late", time: const ClockTime(9, 0));
      await tasks.toggleDone(task("Late"));
      final draft = tasks.draft(task("Late"))..setReminder(Reminder.once);
      final result = await tasks.save(draft);
      expect(
          (result as Info).message, "Please set time and date in the future");
      expect(task("Late").done, isTrue);
      expect(task("Late").reminder, Reminder.none);
      expect(notifications.once, isEmpty);
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

    test('acts on the task it is given, after a reorder changed the ids',
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
    });
  });

  group('reminders', () {
    test("say which task they're for only while the app isn't locked",
        () async {
      await add("Call", time: const ClockTime(18, 0), reminder: Reminder.once);
      await add("Stretch",
          time: const ClockTime(7, 0), reminder: Reminder.daily);
      expect(notifications.bodies.values, ["Call", "Stretch"]);
      lock.lock = AppLock.password;
      lock.changed.add(AppLock.password);
      await pumpEventQueue();
      expect(notifications.bodies.values, [null, null]);
      lock.lock = AppLock.off;
      lock.changed.add(AppLock.off);
      await pumpEventQueue();
      expect(notifications.bodies.values, ["Call", "Stretch"]);
    });

    /// Tasks with reminders set by an older version, or in another time
    /// zone: one still to come, one gone that went off once but is set to go
    /// off again a year on, and a daily one.
    Future<void> setEarlier() async {
      await repository.insertItem(TodoItem(
        uuid: "call",
        title: "Call",
        day: DateTime(2026, 5, 13),
        time: const ClockTime(18, 0),
        reminder: Reminder.once,
      ));
      await repository.insertItem(TodoItem(
        uuid: "shop",
        title: "Shop",
        day: DateTime(2026, 5, 12),
        time: const ClockTime(9, 0),
        reminder: Reminder.once,
      ));
      await repository.insertItem(TodoItem(
        uuid: "stretch",
        title: "Stretch",
        time: const ClockTime(7, 0),
        reminder: Reminder.daily,
      ));
      notifications.once["shop".hashCode] = DateTime(2027, 5, 12, 9);
    }

    for (final (earlier, why) in [
      (null, "before reminders went by the phone's time zone"),
      ("Europe/London", "in another time zone"),
    ]) {
      test("set $why are all set afresh in the phone's", () async {
        await setEarlier();
        notifications.setIn = earlier;
        await tasks.get();
        expect(
            notifications.once, {"call".hashCode: DateTime(2026, 5, 13, 18)});
        expect(
            notifications.daily, {"stretch".hashCode: const ClockTime(7, 0)});
        expect(notifications.setIn, "Africa/Cairo");
      });
    }

    test("set in the phone's time zone are left as they are", () async {
      await setEarlier();
      await tasks.get();
      expect(notifications.once, {"shop".hashCode: DateTime(2027, 5, 12, 9)});
      expect(notifications.daily, isEmpty);
    });
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
      expect(repository.rows.single.progress.doneDays,
          {DateTime(2026, 5, 13), DateTime(2026, 5, 14)});
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
      final progress = task("Stretch").progress;
      DayStatus on(int day) => progress.statusOf(DateTime(2026, 5, day), time);
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

    test('stay as done as they were, with their days, once not daily',
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
    });

    test("set their reminder again with the App Lock, even when done today",
        () async {
      await addStretch();
      await tasks.toggleDone(task("Stretch"));
      lock.lock = AppLock.password;
      lock.changed.add(AppLock.password);
      await pumpEventQueue();
      expect(notifications.bodies.values.single, isNull);
    });

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
      final result = await restoring.restore(true,
          askForBackupPassword: (open) async => false);
      expect(result, isA<Success>());
      TodoItem restored(String title) =>
          restoring.items.singleWhere((task) => task.title == title);
      expect(restored("Stretch").progress.since, DateTime(2026, 5, 13));
      expect(restored("Stretch").done, isFalse);
      expect(restored("Read").progress.since, DateTime(2026, 5, 1));
      expect(restored("Read").progress.streak(time), 2);
      expect(notifications.daily, hasLength(2));
    });
  });

  group('subtasks', () {
    /// Adds a subtask to the task titled [parent], through its form.
    Future<Result> addIn(String parent, String title,
        {ClockTime? time, Reminder reminder = Reminder.none}) {
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
      expect(tasks.items.map((each) => each.title),
          ["Trip", "Book", "Flights", "Hotel", "Pack", "Shop", "Milk"]);
    });

    test('are done with their task, which Undo takes back, reminders and all',
        () async {
      await add("Trip");
      await addIn("Trip", "Book",
          time: const ClockTime(18, 0), reminder: Reminder.once);
      await addIn("Trip", "Pack");
      await tasks.toggleDone(task("Pack"));
      expect(notifications.once, hasLength(1));

      final result = await tasks.toggleDone(task("Trip"));
      expect(result, isA<Undoable>());
      // The other one was done already.
      expect((result as Undoable).message, "Task done, with its last subtask");
      expect(tasks.items.every((each) => each.done), isTrue);
      expect(task("Book").reminder, Reminder.none);
      expect(notifications.once, isEmpty);

      expect(await result.undo(), isA<Success>());
      expect(task("Trip").done, isFalse);
      expect(task("Book").done, isFalse);
      expect(task("Pack").done, isTrue);
      expect(task("Book").reminder, Reminder.once);
      expect(notifications.once.keys, [task("Book").uuid.hashCode]);
    });

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
          (result as Undoable).message, "Task done, with its last 2 subtasks");
      await result.undo();
      await tasks.toggleDone(task("Book"));
      expect((await tasks.toggleDone(task("Book")) as Undoable).message,
          isNot(contains("subtask")));
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
          (result as Undoable).message, "Task undone, and the 2 tasks it's in");
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
      await add("Routine",
          time: const ClockTime(7, 0), reminder: Reminder.daily);
      await addIn("Routine", "Stretch",
          time: const ClockTime(7, 5), reminder: Reminder.daily);
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
      expect((again as Undoable).message,
          "Done for today. That finishes “Routine”");
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
      tasks.setFilter(const UndoneTasksFilter());
      expect(outline(), "Trip\n  Pack\nShop\n  Milk");
      // How far along a task is counts the ones the filter hides too.
      final trip = tasks.tree.nodeOf(task("Trip"))!;
      expect((trip.doneSubtaskCount, trip.subtaskCount), (3, 4));
      tasks.setFilter(const DoneTasksFilter());
      expect(outline(), "Book\n  Flights\n  Hotel");
      tasks.setFilter(const AllTasksFilter());
      expect(outline().split("\n"), hasLength(7));
    });

    group('in the trash', () {
      test('go there with their task, as one entry, and come back with it',
          () async {
        await plan();
        await addIn("Hotel", "Pay",
            time: const ClockTime(18, 0), reminder: Reminder.once);
        final trashed = await tasks.delete(task("Book"));
        expect(outline(), "Trip\n  Pack\nShop\n  Milk");
        expect(tasks.trash, hasLength(1));
        expect(trashed!.item.task.title, "Book");
        expect(trashed.item.subtasks.map((each) => each.title),
            ["Flights", "Hotel", "Pay"]);
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
        expect(notifications.once.keys, [task("Pay").uuid.hashCode]);
        expect(tasks.trash, isEmpty);
      });

      test('are off the list with their task straight away', () async {
        await plan();
        final deleting = tasks.delete(task("Trip"));
        expect(outline(), "Shop\n  Milk");
        await deleting;
        expect(repository.rows.map((each) => each.title), ["Shop", "Milk"]);
      });

      test('put back without their task wait for it as tasks of their own',
          () async {
        await plan();
        final milk = await tasks.delete(task("Milk"));
        final shop = await tasks.delete(task("Shop"));
        await tasks.restoreFromTrash(milk!);
        expect(outline().split("\n").last, "Milk");
        expect(tasks.tree.nodeOf(task("Milk"))!.parent, isNull);
        await tasks.restoreFromTrash(shop!);
        expect(tasks.tree.nodeOf(task("Milk"))!.parent!.task.title, "Shop");
      });

      test('all come back in their tasks with Restore All', () async {
        await plan();
        await tasks.delete(task("Hotel"));
        await tasks.delete(task("Trip"));
        final result = await tasks.restoreAllFromTrash();
        expect((result as Success).message, "2 Tasks Restored");
        final book = tasks.tree.nodeOf(task("Book"))!;
        expect(book.children.map((node) => node.task.title),
            unorderedEquals(["Flights", "Hotel"]));
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
        final putBack = trips
            .singleWhere((node) => node.task.uuid != trashed.item.task.uuid);
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

      test('a task is not dropped among the subtasks of a folded task',
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
      });

      test('a task dropped back by tasks that are folded away stays put',
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
      });

      test('into a task makes it the last of its subtasks, and unfolds it',
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
        expect(tasks.tree.roots.map((node) => node.task.title),
            ["Trip", "Shop", "Book"]);
      });

      test('next to a task puts it ahead of it, or right after it', () async {
        await plan();
        await tasks.moveBeside(task("Milk"), task("Flights"), after: true);
        expect(
            tasks.tree
                .nodeOf(task("Book"))!
                .children
                .map((node) => node.task.title),
            ["Flights", "Milk", "Hotel"]);
        await tasks.moveBeside(task("Milk"), task("Trip"), after: false);
        expect(tasks.tree.roots.map((node) => node.task.title),
            ["Milk", "Trip", "Shop"]);
        await tasks.moveBeside(task("Milk"), task("Shop"), after: true);
        expect(tasks.tree.roots.map((node) => node.task.title),
            ["Trip", "Shop", "Milk"]);
      });

      test('a task cannot go inside itself, or a task in it', () async {
        await plan();
        expect(await tasks.moveInto(task("Trip"), task("Hotel")), isA<Info>());
        expect(await tasks.moveInto(task("Trip"), task("Trip")), isA<Info>());
        expect(outline(), planned);
      });

      test('keeps reminders with their tasks, whose ids all change', () async {
        await plan();
        await addIn("Shop", "Eggs",
            time: const ClockTime(18, 0), reminder: Reminder.once);
        final eggs = task("Eggs");
        await tasks.moveInto(eggs, task("Trip"));
        expect(task("Eggs").id, isNot(eggs.id));
        expect(task("Eggs").reminder, Reminder.once);
        // A command given the task as it was still finds it.
        await tasks.toggleDone(eggs);
        expect(task("Eggs").done, isTrue);
        expect(notifications.once, isEmpty);
      });

      test('a task still to do leaves the done task it goes into to do',
          () async {
        await plan();
        await tasks.toggleDone(task("Shop"));
        await tasks.moveInto(task("Pack"), task("Shop"));
        expect(task("Shop").done, isFalse);
        expect(task("Milk").done, isTrue);
      });
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
        expect(draft.places.map((node) => node.task.title),
            ["Trip", "Pack", "Shop", "Milk"]);
        expect(tasks.draft().places, hasLength(7));
      });

      test('saving it with another task picked moves it there', () async {
        await plan();
        await addIn("Shop", "Eggs",
            time: const ClockTime(18, 0), reminder: Reminder.once);
        final draft = tasks.draft(task("Eggs"))
          ..setTitle("Fresh eggs")
          ..setParent(task("Trip"));
        expect(draft.moved, isTrue);
        final result = await tasks.save(draft);
        expect((result as Info).message, startsWith("Time remaining"));
        expect(
            tasks.tree.nodeOf(task("Fresh eggs"))!.parent!.task.title, "Trip");
        expect(task("Fresh eggs").reminder, Reminder.once);
        expect(notifications.once.keys, [task("Fresh eggs").uuid.hashCode]);
        expect(tasks.items.where((each) => each.title == "Eggs"), isEmpty);
      });

      test('saving it with no task picked makes it a task of its own',
          () async {
        await plan();
        final draft = tasks.draft(task("Hotel"))..setParent(null);
        expect((await tasks.save(draft) as Info).message, "Task Updated");
        expect(task("Hotel").parent, isNull);
        expect(tasks.tree.roots.last.task.title, "Hotel");
      });

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
      await restoring.restore(true,
          askForBackupPassword: (open) async => false);
      final shop = restoring.tree.roots.first;
      expect(shop.task.title, "Shop");
      expect(shop.task.folded, isTrue);
      expect(shop.children.single.task.title, "Milk");
      // Not done, with a subtask still to do.
      expect(shop.task.done, isFalse);
      expect(restoring.tree.roots.last.task.title, "Old");
      expect(
          repository.rows.map((row) => row.toMap()['parent']), ["u-1", "", ""]);
    });
  });

  group('emptyReason', () {
    test('says there are no tasks, or why the filter shows none', () async {
      await tasks.get();
      expect(tasks.emptyReason, EmptyTasksReason.noTasks);
      await add("Call");
      expect(tasks.emptyReason, isNull);
      tasks.setFilter(const DoneTasksFilter());
      expect(tasks.emptyReason, EmptyTasksReason.noneDone);
      await tasks.toggleDone(repository.rows.single);
      await tasks.get();
      tasks.setFilter(const UndoneTasksFilter());
      expect(tasks.emptyReason, EmptyTasksReason.allDone);
    });
  });

  group('trash', () {
    List<String> titles() => [for (final task in tasks.items) task.title];
    List<String> inTrash() =>
        [for (final entry in tasks.trash) entry.item.task.title];

    test('deleting a task moves it there, and turns its reminder off',
        () async {
      await add("Call", time: const ClockTime(18, 0), reminder: Reminder.once);
      await add("Shop");
      final trashed = await tasks.delete(task("Call"));
      expect(trashed!.item.task.title, "Call");
      expect(trashed.deletedAt, now);
      expect(titles(), ["Shop"]);
      expect(inTrash(), ["Call"]);
      expect(notifications.once, isEmpty);
    });

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
      expect(notifications.once.keys, [task("Call").uuid.hashCode]);
      expect(tasks.trash, isEmpty);
    });

    test("puts a task back once, however often it's asked", () async {
      await add("Call");
      final trashed = await tasks.delete(task("Call"));
      await tasks.restoreFromTrash(trashed!);
      expect(await tasks.restoreFromTrash(trashed), isA<Info>());
      expect(titles(), ["Call"]);
    });

    test("doesn't remind of a task put back after its time has gone",
        () async {
      await add("Call", time: const ClockTime(18, 0), reminder: Reminder.once);
      final trashed = await tasks.delete(task("Call"));
      time = DateTime(2026, 5, 13, 19);
      expect(await tasks.restoreFromTrash(trashed!), isA<Success>());
      expect(notifications.once, isEmpty);
    });

    test('a task put back takes a new uuid when one on the list has its own',
        () async {
      await add("Call", time: const ClockTime(18, 0), reminder: Reminder.once);
      final trashed = await tasks.delete(task("Call"));
      // As a backup restored since might bring it back.
      await repository.insertItem(trashed!.item.task);
      notifications.once.clear();
      await tasks.restoreFromTrash(trashed);
      final calls = tasks.items.where((task) => task.title == "Call");
      expect(calls, hasLength(2));
      final putBack =
          calls.singleWhere((task) => task.uuid != trashed.item.task.uuid);
      expect(notifications.once.keys, [putBack.uuid.hashCode]);
    });

    test("a daily task put back keeps its days, and reminds again", () async {
      await add("Stretch", time: const ClockTime(7, 0), reminder: Reminder.daily);
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
