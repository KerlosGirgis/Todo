import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/result.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/task_filters.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/repositories/tasks_repository.dart';
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
  Future<void> refreshAllItems(List<TodoItem> items) async {
    rows
      ..clear()
      ..addAll(items.map(_withId));
  }
}

class FakeNotifications extends NotificationService {
  final once = <int, DateTime>{};
  final daily = <int, ClockTime>{};
  final bodies = <int, String?>{};

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

  setUp(() {
    repository = FakeTasksRepository();
    notifications = FakeNotifications();
    lock = FakeLock();
    tasks = TasksViewModel(
      repository: repository,
      notificationService: notifications,
      lockService: lock,
      clock: () => now,
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
}
