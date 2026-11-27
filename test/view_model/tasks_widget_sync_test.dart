import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/tasks_widget_snapshot.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/task_sort.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/services/home_widget_service.dart';
import 'package:todo/view_model/tasks_view_model.dart';

import 'tasks_view_model_test.dart'
    show FakeLock, FakeNotifications, FakeTasksRepository, now;

/// The to-do widget, which keeps each snapshot it's shown.
class FakeTasksWidget extends HomeWidgetService {
  final shown = <TasksWidgetSnapshot>[];

  /// Whether showing them fails, as when the phone's storage is full.
  bool fail = false;

  @override
  Future<void> showTasks(TasksWidgetSnapshot snapshot) async {
    if (fail) throw StateError("Storage full");
    shown.add(snapshot);
  }
}

void main() {
  late FakeTasksRepository repository;
  late FakeLock lock;
  late FakeTasksWidget widget;
  late TasksViewModel tasks;

  setUp(() {
    repository = FakeTasksRepository();
    lock = FakeLock();
    widget = FakeTasksWidget();
    tasks = TasksViewModel(
      repository: repository,
      notificationService: FakeNotifications(),
      lockService: lock,
      homeWidgetService: widget,
      clock: () => now,
    );
  });

  tearDown(() => tasks.dispose());

  /// Lets the widget be shown the tasks, as it is once a change is made.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  List<String> titles() => [
    for (final task in widget.shown.last.tasks) task.title,
  ];

  test('is shown the tasks once they\'re read in, and not before', () async {
    await repository.insertItem(TodoItem(uuid: "a", title: "Water the plants"));
    await settle();
    // An empty list would wipe it while the app opens.
    expect(widget.shown, isEmpty);

    await tasks.get();
    await settle();
    expect(titles(), ["Water the plants"]);
    expect(widget.shown.last.from, DateTime(2026, 5, 13));
  });

  test('is shown each change, once for the changes made together', () async {
    await tasks.get();
    await settle();
    final draft = tasks.draft()
      ..setTitle("Call the bank")
      ..setTime(const ClockTime(15, 0));
    await tasks.save(draft);
    await settle();
    expect(titles(), ["Call the bank"]);
    final shown = widget.shown.length;

    await tasks.toggleDone(tasks.items.single);
    await settle();
    expect(widget.shown.last.tasks.single.doneOn(0), isTrue);
    expect(widget.shown.last.left.first, 0);
    // Marking it done rereads the tasks, which is one change.
    expect(widget.shown.length, shown + 1);
  });

  test('lists them as the to-do page sorts them', () async {
    await repository.insertItem(
      TodoItem(uuid: "x", title: "Later", day: DateTime(2026, 5, 20)),
    );
    await repository.insertItem(
      TodoItem(uuid: "y", title: "Sooner", day: DateTime(2026, 5, 14)),
    );
    await tasks.get();
    await settle();
    expect(titles(), ["Later", "Sooner"]);
    await tasks.setSort(TaskSort.dueDate);
    await settle();
    expect(titles(), ["Sooner", "Later"]);
  });

  test('only gets how many are left while the App Lock is on, and the '
      'tasks again once it\'s off', () async {
    await repository.insertItem(TodoItem(uuid: "a", title: "Secret plan"));
    lock.lock = AppLock.password;
    await tasks.get();
    await settle();
    expect(widget.shown.last.locked, isTrue);
    expect(widget.shown.last.tasks, isEmpty);
    expect(widget.shown.last.left.first, 1);

    lock.lock = AppLock.off;
    lock.changed.add(AppLock.off);
    await settle();
    await settle();
    expect(widget.shown.last.locked, isFalse);
    expect(titles(), ["Secret plan"]);
  });

  test('reads what the app is locked with once, then goes by its changes, '
      'rather than reading it for each change to the tasks', () async {
    await tasks.get();
    await settle();
    final reads = lock.reads;
    final draft = tasks.draft()..setTitle("Call the bank");
    await tasks.save(draft);
    await settle();
    await tasks.toggleDone(tasks.items.single);
    await settle();
    await tasks.toggleDone(tasks.items.single);
    await settle();
    expect(widget.shown, hasLength(greaterThan(3)));
    expect(lock.reads, reads);

    lock.lock = AppLock.password;
    lock.changed.add(AppLock.password);
    await settle();
    await settle();
    expect(widget.shown.last.locked, isTrue);
    expect(lock.reads, reads);
  });

  test('that can\'t be shown them leaves the tasks as they are', () async {
    widget.fail = true;
    await repository.insertItem(TodoItem(uuid: "a", title: "Water the plants"));
    await tasks.get();
    await settle();
    expect(tasks.items.single.title, "Water the plants");
  });
}
