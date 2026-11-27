import 'dart:async';
import 'dart:collection';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/v4.dart';

import '../core/prompts.dart';
import '../core/result.dart';
import '../core/tasks_widget_snapshot.dart';
import '../core/utils/date_time_utils.dart';
import '../models/app_lock.dart';
import '../models/clock_time.dart';
import '../models/recurrence.dart';
import '../models/repeat_progress.dart';
import '../models/task_filters.dart';
import '../models/task_listing.dart';
import '../models/task_sort.dart';
import '../models/task_tree.dart';
import '../models/todo_item.dart';
import '../models/trashed.dart';
import '../repositories/tasks_repository.dart';
import '../services/authentication_service.dart';
import '../services/backup_service.dart';
import '../services/file_service.dart';
import '../services/home_widget_service.dart';
import '../services/lock_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_scheduler.dart';
import 'backup_flow.dart';
import 'trash_bin.dart';

part 'task_draft.dart';

/// Why there are no tasks to list.
enum EmptyTasksReason {
  /// There are no tasks at all.
  noTasks,

  /// The Done filter is on, and no task is done yet.
  noneDone,

  /// The Undone filter is on, and every task is done.
  allDone,

  /// The Daily filter is on, and no task comes round every day.
  noneDaily,

  /// The Weekly filter is on, and no task comes round every week.
  noneWeekly,

  /// The Monthly filter is on, and no task comes round every month.
  noneMonthly,

  /// The Once filter is on, and every task repeats.
  noneOnce,
}

class TasksViewModel with ChangeNotifier implements TrashOwner<TaskBranch> {
  TasksViewModel({
    TasksRepository? repository,
    BackupService? backupService,
    FileService? fileService,
    LockService? lockService,
    AuthenticationService? authService,
    NotificationService? notificationService,
    HomeWidgetService? homeWidgetService,
    DateTime Function()? clock,
  }) : _tasksRepository = repository ?? TasksRepository(),
       _lockService = lockService ?? LockService(),
       _homeWidgetService = homeWidgetService ?? HomeWidgetService(),
       _now = clock ?? DateTime.now,
       _reminders = ReminderScheduler(
         notifications: notificationService,
         lockService: lockService,
         clock: clock,
       ),
       _backups = BackupFlow(
         BackupKind.tasks,
         authService: authService,
         backupService: backupService,
         fileService: fileService,
       ) {
    // Reminders say which task they're for only while the app isn't locked,
    // and so does the widget.
    _lockChanges = _lockService.changes.listen((_) {
      refreshReminders();
      _refreshWidget();
    });
  }

  late final StreamSubscription<AppLock> _lockChanges;

  @override
  void dispose() {
    _lockChanges.cancel();
    _dayEnd?.cancel();
    super.dispose();
  }

  List<TodoItem> _allTasks = [];
  List<TodoItem> _items = [];

  /// Every task, each in the task it's a subtask of.
  TaskTree _tree = TaskTree.empty;

  /// The tasks the filter lets through, in the sort's order.
  TaskTree _shown = TaskTree.empty;

  /// The tasks the filter lets through, each ahead of its subtasks, in the
  /// sort's order.
  List<TodoItem> get items => UnmodifiableListView(_items);

  /// The tasks the filter lets through, each in the task it's a subtask
  /// of, or in the nearest of the tasks that one's in that the filter lets
  /// through, or on its own when it lets none of them through; each among
  /// the tasks it's next to in the sort's order.
  TaskTree get tree => _shown;

  /// Which tasks are listed, and what by, as the page's buttons last had
  /// them, which the database keeps: read in with the tasks, the first time.
  /// Until then, all of them, in the user's own order.
  TaskListing _listing = const TaskListing();

  /// Whether [_listing] is as the user last chose: read in, or chosen since.
  bool _listingKnown = false;

  TaskFilter get filter => _listing.filter;
  TaskSort get sort => _listing.sort;

  /// Which way the tasks are sorted, when they're sorted by due date. It's
  /// kept while they aren't, for when they are again.
  SortDirection get sortDirection => _listing.direction;

  int get finishedTasksCount => countOf(TaskFilter.done);
  int get unfinishedTasksCount => countOf(TaskFilter.undone);

  /// How many tasks [filter] lets through, subtasks included.
  int countOf(TaskFilter filter) => _allTasks.where(filter.shows).length;

  /// The tasks in the trash, each with the tasks in it.
  late final _trash = TrashBin<TaskBranch>(
    noun: "task",
    read: () => _tasksRepository.getTrash(),
    delete: (ids) => _tasksRepository.deleteFromTrash(ids),
    changed: notifyListeners,
  );

  /// The tasks in the trash, each with the tasks in it, the last deleted
  /// first, once [getTrash] has read them in.
  @override
  List<Trashed<TaskBranch>> get trash => _trash.entries;

  /// Why the filter lets no task through, or null while it lets some.
  EmptyTasksReason? get emptyReason {
    if (_items.isNotEmpty) return null;
    if (_allTasks.isEmpty) return EmptyTasksReason.noTasks;
    return switch (filter) {
      // All lets every task through.
      TaskFilter.all => EmptyTasksReason.noTasks,
      TaskFilter.done => EmptyTasksReason.noneDone,
      TaskFilter.undone => EmptyTasksReason.allDone,
      TaskFilter.daily => EmptyTasksReason.noneDaily,
      TaskFilter.weekly => EmptyTasksReason.noneWeekly,
      TaskFilter.monthly => EmptyTasksReason.noneMonthly,
      TaskFilter.once => EmptyTasksReason.noneOnce,
    };
  }

  final TasksRepository _tasksRepository;
  final LockService _lockService;
  final HomeWidgetService _homeWidgetService;
  final DateTime Function() _now;

  /// The tasks' reminders on the phone.
  final ReminderScheduler _reminders;

  /// Backing the tasks up, and restoring them.
  final BackupFlow _backups;

  /// Whether the reminders have been checked against the phone's time zone
  /// and the App Lock since the app started.
  bool _remindersChecked = false;

  /// The day the tasks stand on, which a daily task is done or not for.
  DateTime get today => _day ?? _dateOf(_now());

  /// The time as the tasks go by it, which the pages show them as of: the
  /// clock this was made with, which tests can set.
  DateTime get now => _now();
  DateTime? _day;

  /// Goes off as the next day begins, to start the daily tasks over.
  Timer? _dayEnd;

  /// Reads in the tasks, as the to-do page does as it opens. Why they
  /// couldn't be, or null: then they're shown as they were.
  Future<Result?> get() async {
    if (!_listingKnown) {
      _listingKnown = true;
      try {
        _listing = await _tasksRepository.getListing() ?? _listing;
      } catch (e) {
        // Listed as usual, then.
      }
    }
    final List<TodoItem> items;
    try {
      items = await _tasksRepository.getItems();
    } catch (e) {
      return const Failure("Couldn't read your tasks");
    }
    _setDay(_dateOf(_now()), items);
    _awaitNewDay();
    if (!_remindersChecked) {
      _remindersChecked = true;
      try {
        await _reminders.checkAsAppStarts(
          all: _tasksRepository.getItems,
          current: _allTasks,
        );
      } catch (e) {
        // The reminders stay as they were.
      }
    }
    return null;
  }

  /// Reads the tasks in again once a change has been saved, or has failed,
  /// to show them as they now are. Should that fail, they're shown as they
  /// were until they're next read in: the change has gone through, or the
  /// user has been told it hasn't, either way.
  Future<void> _reload() => get();

  /// Brings each repeating task up to date if a new day has begun since the
  /// tasks were: at midnight, or as the app comes back after it. A daily
  /// task starts over, not done yet, as does one that comes round today.
  void checkForNewDay() {
    if (_day == null) return;
    final today = _dateOf(_now());
    if (today != _day) {
      _setDay(today, _allTasks);
      unawaited(_reminders.setEnding(_allTasks));
    }
    _awaitNewDay();
  }

  /// Lists [tasks] as they stand on [today].
  void _setDay(DateTime today, List<TodoItem> tasks) {
    _day = today;
    _setTasks([for (final task in tasks) task.asOf(today)]);
  }

  /// Lists [tasks], as they stand today.
  void _setTasks(List<TodoItem> tasks) {
    _allTasks = tasks;
    _arrange();
  }

  void _awaitNewDay() {
    _dayEnd?.cancel();
    final now = _now();
    _dayEnd = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      checkForNewDay,
    );
  }

  /// Lists only the tasks [filter] lets through, from now on and when the
  /// app opens again.
  Future<void> setFilter(TaskFilter filter) =>
      _setListing(_listing.copyWith(filter: filter));

  /// Lists the tasks by [sort], [direction] first if given, or else the way
  /// they were last sorted, from now on and when the app opens again.
  Future<void> setSort(TaskSort sort, {SortDirection? direction}) =>
      _setListing(_listing.copyWith(sort: sort, direction: direction));

  /// Lists the tasks as [listing] has it, straight away, then keeps it.
  Future<void> _setListing(TaskListing listing) async {
    _listingKnown = true;
    if (listing == _listing) return;
    _listing = listing;
    _arrange();
    try {
      await _tasksRepository.saveListing(listing);
    } catch (e) {
      // It holds until the app closes all the same.
    }
  }

  void _arrange() {
    _tree = TaskTree(_allTasks);
    final filter = this.filter;
    var shown = filter == TaskFilter.all ? _tree : _tree.where(filter.shows);
    final compare = sort.compare(today, sortDirection);
    if (compare != null) shown = shown.sorted(compare);
    _shown = shown;
    _items = _shown.tasks;
    notifyListeners();
    _refreshWidget();
  }

  /// Whether the widget is to be shown the tasks as they are once the
  /// change being made has been.
  bool _widgetDue = false;

  /// Shows the home screen's to-do widget the tasks as they stand, in the
  /// page's order, a week ahead, or only how many are left while the App
  /// Lock is on. Once for all the changes made together, and not before the
  /// tasks are read in, as the widget would be emptied.
  void _refreshWidget() {
    if (_day == null || _widgetDue) return;
    _widgetDue = true;
    scheduleMicrotask(() async {
      _widgetDue = false;
      try {
        final locked = await _lockService.getLock() != AppLock.off;
        await _homeWidgetService.showTasks(
          TasksWidgetSnapshot.of(
            _allTasks,
            now: _now(),
            sort: sort,
            direction: sortDirection,
            locked: locked,
          ),
        );
      } catch (e) {
        // The widget's own trouble, which the tasks go ahead without.
      }
    });
  }

  /// Moves the task at [oldIndex] among the [tree]'s tasks, as a list has
  /// them, to [newIndex], with the tasks in it. It lines up with the task
  /// then below it, going into the task that one's in, ahead of it; with
  /// none below it, it goes last, as a task of its own. Tasks that are
  /// folded away don't count: one dropped between the same two tasks on
  /// show as it was picked up from stays where it is. Only in the user's
  /// own order: sorted otherwise, a task's place isn't up to them. Why it
  /// couldn't be moved, or null; then the tasks go back as they were.
  Future<Result?> syncAfterReorder(int oldIndex, int newIndex) async {
    if (sort != TaskSort.custom) return null;
    final nodes = _shown.nodes;
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= nodes.length) {
      return null;
    }
    final moved = nodes[oldIndex];
    // The tasks it could be next to: not the ones that go with it, nor ones
    // folded away, which aren't where it was dropped.
    bool beside(TaskNode node) =>
        !node.isOrIsIn(moved) &&
        !node.ancestors.any((each) => each.task.folded);
    final rest = [...nodes]..removeAt(oldIndex);
    final above = rest.take(newIndex).where(beside).lastOrNull;
    final below = rest.skip(newIndex).where(beside).firstOrNull;
    if (above == nodes.take(oldIndex).where(beside).lastOrNull &&
        below == nodes.skip(oldIndex).where(beside).firstOrNull) {
      return null;
    }
    if (below == null) return moveInto(moved.task, null);
    return moveBeside(moved.task, below.task, after: false);
  }

  /// Makes [task] a subtask of [parent], the last one, or a task of its own
  /// for null, the last of those. The tasks in it go with it. Null when
  /// there's nothing to say: it's moved, or was there already.
  Future<Result?> moveInto(TodoItem task, TodoItem? parent) =>
      _move(task, parent: parent);

  /// Moves [task] next to [sibling], into the task that one's in: ahead of
  /// it, or right [after] it. The tasks in it go with it. Null when there's
  /// nothing to say.
  Future<Result?> moveBeside(
    TodoItem task,
    TodoItem sibling, {
    required bool after,
  }) async {
    final node = _tree.nodeOf(_current(task));
    final beside = _tree.nodeOf(_current(sibling));
    if (node == null || beside == null) return _gone;
    if (identical(node, beside)) return null;
    var before = beside;
    if (after) {
      final siblings = beside.parent?.children ?? _tree.roots;
      final next = siblings
          .skip(siblings.indexOf(beside) + 1)
          .where((each) => !identical(each, node))
          .firstOrNull;
      if (next == null) return _move(task, parent: beside.parent?.task);
      before = next;
    }
    return _move(task, parent: beside.parent?.task, before: before.task);
  }

  static const _gone = Info("That task isn't on the list anymore");

  Future<Result?> _move(
    TodoItem task, {
    required TodoItem? parent,
    TodoItem? before,
  }) async {
    final node = _tree.nodeOf(_current(task));
    final into = parent == null ? null : _tree.nodeOf(_current(parent));
    if (node == null || (parent != null && into == null)) return _gone;
    if (into != null && into.isOrIsIn(node)) {
      return const Info("A task can't go inside itself");
    }
    // Its subtasks find it by its uuid.
    if (into != null && into.task.uuid.isEmpty) {
      return const Failure("Couldn't move the task");
    }
    var tasks = _tree.moving(
      node,
      parent: into,
      before: before == null ? null : _tree.nodeOf(_current(before)),
    );
    if (tasks == null) return null;
    if (into != null && into.task.folded) {
      // Unfolded, so the task shows where it's gone.
      tasks = [
        for (final each in tasks)
          identical(each, into.task) ? each.copyWith(folded: false) : each,
      ];
    }
    tasks = _settled(tasks);
    // There straight away, as that's where it was dropped.
    _setTasks(tasks);
    Result? result;
    try {
      await _tasksRepository.refreshAllItems(tasks);
    } catch (e) {
      // The order stays as it was in the database.
      result = const Failure("Couldn't move the task");
    }
    // Rewriting the table gives every task a new id, so the tasks are read
    // back in: the ids held before would now point at other tasks.
    await _reload();
    return result;
  }

  /// [tasks] with none of them done while a task in it isn't.
  List<TodoItem> _settled(List<TodoItem> tasks) {
    final ahead = {
      for (final node in TaskTree(tasks).doneAheadOfSubtasks) node.task,
    };
    if (ahead.isEmpty) return tasks;
    return [
      for (final task in tasks)
        ahead.contains(task) ? task.marked(done: false, today: today) : task,
    ];
  }

  /// Marks not done any task that's done while a task in it isn't, as one
  /// with a task still to do added to it, or put back in it.
  Future<void> _settle() async {
    final ahead = _tree.doneAheadOfSubtasks;
    if (ahead.isEmpty) return;
    try {
      await _tasksRepository.updateItems([
        for (final node in ahead) node.task.marked(done: false, today: today),
      ]);
    } catch (e) {
      // They stay done.
    }
    await _reload();
  }

  /// Folds [task]'s subtasks away, on the list and on the map, or brings
  /// them back out.
  Future<void> setFolded(TodoItem task, bool folded) async {
    task = _current(task);
    if (task.folded == folded) return;
    final changed = task.copyWith(folded: folded);
    // Straight away, as it's what was tapped.
    _setTasks([
      for (final each in _allTasks) identical(each, task) ? changed : each,
    ]);
    try {
      await _tasksRepository.updateItem(changed);
    } catch (e) {
      await _reload();
    }
  }

  /// [task] as the tasks are now: found by its uuid, which outlasts a
  /// reorder, as the ids don't, or by its id when tasks share a uuid.
  TodoItem _current(TodoItem task) {
    final sameUuid = _allTasks.where((each) => each.uuid == task.uuid);
    if (sameUuid.length == 1) return sameUuid.single;
    return _allTasks.where((each) => each.id == task.id).firstOrNull ?? task;
  }

  /// A form for [task], or for a new task without one.
  TaskDraft draft([TodoItem? task]) => TaskDraft._(
    task,
    _now,
    _tree,
    task == null ? null : _tree.nodeOf(task)?.parent?.task,
  );

  /// A form for a new subtask of [parent].
  TaskDraft subtaskDraft(TodoItem parent) =>
      TaskDraft._(null, _now, _tree, _current(parent));

  /// Adds the task [draft] has, or saves the changes to the one it's for,
  /// in the task the draft has it in, then sets its reminder.
  Future<Result> save(TaskDraft draft) async {
    // All of it now, as the form may close before the task is saved.
    final task = draft.task;
    final title = draft.title.trim();
    final desc = draft.description.trim();
    final (day, time, reminder) = (draft.day, draft.time, draft.reminder);
    final rule = draft.rule;
    final parent = draft.parent;
    final moved = draft.moved;
    if (title.isEmpty) return Info("Give the task a title");
    if (task == null) {
      var added = TodoItem(
        title: title,
        desc: desc,
        day: day,
        time: time,
        uuid: const UuidV4().generate(),
        parent: parent?.uuid,
      );
      try {
        added = added.copyWith(id: await _tasksRepository.insertItem(added));
      } catch (e) {
        return const Unsaved("Couldn't add the task");
      }
      await _reload();
      // Unfolded, so the new task shows.
      if (parent != null) await setFolded(parent, false);
      final result = await switch (rule) {
        // Its day goes, as a repeating task has none.
        final rule? => _repeat(added, rule),
        _ when reminder == Reminder.once => _remindOnce(added),
        _ => Future.value(Info("Task Added")),
      };
      await _settle();
      return result;
    }
    // Without a reminder until its own is set, so one that can't be leaves
    // it without any, with its days as they'd be from now on.
    final progress = _progressAs(task, rule);
    final updated = TodoItem(
      title: title,
      desc: desc,
      id: task.id,
      done: task.done,
      day: day,
      time: time,
      uuid: task.uuid,
      progress: progress,
      parent: task.parent,
      folded: task.folded,
    );
    try {
      await _tasksRepository.updateItem(updated);
    } catch (e) {
      // As it was, reminder and all.
      return const Unsaved("Couldn't save the task");
    }
    try {
      // Whichever it had, in case it's been turned off, or it's changed.
      await _reminders.cancel(task);
    } catch (e) {
      // It gets its own all the same.
    }
    await _reload();
    final result = await switch (rule) {
      final rule? => _repeat(updated, rule, progress: progress),
      _ when reminder == Reminder.once => _remindOnce(updated),
      _ => Future.value(Info("Task Updated")),
    };
    // Last, as moving it gives every task a new id, and it keeps its
    // reminder.
    if (moved) {
      final moving = await moveInto(_current(updated), parent);
      if (moving != null) return moving;
    }
    await _settle();
    return result;
  }

  /// Moves [task] to the trash, with the tasks in it, where they wait to be
  /// put back or deleted for good, and turns their reminders off. Says so
  /// with a [Deleted], whose undo puts them back where they were; or why
  /// they couldn't be moved, which leaves them on the list.
  Future<Result> delete(TodoItem task) async {
    task = _current(task);
    final branch = _tree.nodeOf(task)?.branch ?? TaskBranch(task);
    final going = branch.all.toSet();
    // Off the list straight away, as its card has been swiped away.
    _setTasks([
      for (final each in _allTasks)
        if (!going.contains(each)) each,
    ]);
    final Trashed<TaskBranch> trashed;
    try {
      trashed = await _tasksRepository.moveToTrash(branch, deletedAt: _now());
    } catch (e) {
      // Back on the list, as they're still there.
      await _reload();
      return const Failure("Couldn't delete the task");
    }
    for (final each in branch.all) {
      if (each.reminder == Reminder.none) continue;
      try {
        await _reminders.cancel(each);
      } catch (e) {
        // It's in the trash all the same.
      }
    }
    await _trash.reload();
    await _reload();
    final subtasks = branch.subtasks.length;
    return Deleted(switch (subtasks) {
      0 => "Task moved to Trash",
      1 => "Task and its subtask moved to Trash",
      _ => "Task and its $subtasks subtasks moved to Trash",
    }, undo: () => restoreFromTrash(trashed));
  }

  /// Reads in the tasks in the trash.
  @override
  Future<Result?> getTrash() => _trash.load();

  /// Puts the task [entry] holds back on the list, with the tasks in it,
  /// where they were when they can be, with their reminders, if those are
  /// still to come. In the task it was a subtask of, if that's on the list.
  @override
  Future<Result> restoreFromTrash(Trashed<TaskBranch> entry) async {
    final TaskBranch? branch;
    try {
      branch = await _putBack(entry, await _uuidsInUse());
    } catch (e) {
      return _trash.unrestorable;
    }
    await _trash.reload();
    await _reload();
    if (branch == null) return _trash.gone;
    final reminded = await _reminders.setEach(branch.all);
    await _settle();
    if (!reminded) {
      return Failure(
        branch.subtasks.isEmpty
            ? "Task restored, but its reminder couldn't be set"
            : "Task restored, but not every reminder could be set",
      );
    }
    return _trash.restored;
  }

  /// Puts every task in the trash back on the list, with their reminders.
  @override
  Future<Result> restoreAllFromTrash() async {
    final Set<String> uuids;
    try {
      uuids = await _uuidsInUse();
    } catch (e) {
      return _trash.restoredAll(0, all: false);
    }
    final restored = <TaskBranch>[];
    final (:back, :all) = await _trash.putBackAll((entry) async {
      final branch = await _putBack(entry, uuids);
      if (branch != null) restored.add(branch);
      return branch != null;
    });
    await _reload();
    final remindersSet = await _reminders.setEach([
      for (final branch in restored) ...branch.all,
    ]);
    await _settle();
    if (all && !remindersSet) {
      return const Failure(
        "Tasks restored, but not every reminder could be set",
      );
    }
    return _trash.restoredAll(back, all: all);
  }

  /// Deletes the task [entry] holds for good, with the tasks in it. Nothing
  /// in the tasks' trash takes a password: [askForPassword] goes unused.
  @override
  Future<Result> deleteForever(
    Trashed<TaskBranch> entry, {
    PasswordPrompt? askForPassword,
  }) => _trash.deleteForever(entry);

  /// Deletes every task in the trash for good.
  @override
  Future<Result> emptyTrash({PasswordPrompt? askForPassword}) => _trash.empty();

  /// The uuids of the tasks on the list, which a task put back can't share.
  Future<Set<String>> _uuidsInUse() async => {
    for (final task in await _tasksRepository.getItems()) task.uuid,
  };

  /// Puts [entry]'s tasks back on the list, any of them under a new uuid if
  /// a task on the list has its own, [uuids] being theirs: one restored from
  /// a backup since, say. A task's reminder goes by its uuid, so they can't
  /// share one. The tasks as they're back, or null if they aren't in the
  /// trash anymore.
  Future<TaskBranch?> _putBack(
    Trashed<TaskBranch> entry,
    Set<String> uuids,
  ) async {
    final renamed = <String, String>{};
    // A task ahead of its subtasks, which follow it to its new uuid.
    TodoItem own(TodoItem task) {
      if (renamed[task.parent] case final parent?) task = task.under(parent);
      if (!uuids.contains(task.uuid)) return task;
      final uuid = const UuidV4().generate();
      renamed[task.uuid] = uuid;
      return task.copyWith(uuid: uuid);
    }

    final task = own(entry.item.task);
    final branch = TaskBranch(task, [
      for (final subtask in entry.item.subtasks) own(subtask),
    ]);
    final id = await _tasksRepository.restoreFromTrash(entry.id, branch);
    if (id == null) return null;
    uuids.addAll(branch.all.map((each) => each.uuid));
    return TaskBranch(task.copyWith(id: id), branch.subtasks);
  }

  /// Marks [task] done, which turns its reminder off, or not done again. A
  /// repeating task is done for the time that stands for it only, and keeps
  /// reminding the user each time it comes round.
  ///
  /// A task that's done has nothing left to do in it, so its subtasks are
  /// done with it, and the task it's in is done once its last subtask is;
  /// one that isn't done again leaves the tasks it's in still to do. When
  /// other tasks change with it, the result is an [Undoable], which puts
  /// them all back.
  Future<Result> toggleDone(TodoItem task) async {
    task = _current(task);
    final done = !task.done;
    final node = _tree.nodeOf(task);
    final nodes = node == null
        ? const <TaskNode>[]
        : _tree.marking(node, done: done);
    final changing = node == null
        ? [task]
        : [for (final each in nodes) each.task];
    // Before they're marked, as the time that stands for a repeating task
    // may be another once it's done.
    final said = done
        ? (task.repeats ? "Done for ${_occasionOf(task)}" : "Task Done")
        : "Task Undone";
    try {
      await _tasksRepository.updateItems([
        for (final each in changing) each.marked(done: done, today: today),
      ]);
    } catch (e) {
      // None of them is marked, so they keep their reminders.
      return const Failure("Couldn't update the task");
    }
    // Only now that they're marked: had that failed, they'd keep reminding.
    for (final each in changing) {
      if (!done || each.repeats || each.reminder == Reminder.none) continue;
      try {
        await _reminders.cancel(each);
      } catch (e) {
        // It's done all the same.
      }
    }
    await _reload();
    if (node == null || changing.length < 2) {
      return done ? Success(said) : Info(said);
    }
    final inIt = nodes.where((each) => each != node && each.isOrIsIn(node));
    final around = nodes.where((each) => !each.isOrIsIn(node)).toList();
    final String message;
    if (inIt.isNotEmpty) {
      // All of its subtasks, or the ones that were still to do.
      final count = inIt.length;
      final last = count < node.subtaskCount ? "last " : "";
      message = count == 1
          ? "$said, with its ${last}subtask"
          : "$said, with its $last$count subtasks";
    } else if (done) {
      message = "$said. That finishes ${_named(around.first.task)}";
    } else {
      message = around.length == 1
          ? "$said, and ${_named(around.first.task)} with it"
          : "$said, and the ${around.length} tasks it's in";
    }
    return Undoable(message, undo: () => _markAs(changing));
  }

  /// The day that stands for a repeating [task] today, as a message's title
  /// names it: "Today", "Yesterday", "Tomorrow", or "Fri, Oct 24".
  String _occasionOf(TodoItem task) =>
      DateTimeUtils.friendlyDay(task.occurrenceOn(today) ?? today, today);

  /// [task]'s title in quotes, cut short if it's long, to name it in a
  /// message.
  static String _named(TodoItem task) {
    final title = task.title.characters;
    return title.length > 24 ? "“${title.take(23)}…”" : "“$title”";
  }

  /// Marks each of [tasks] done or not as it is here, as it was before a
  /// change that's being taken back, with the reminder it had then.
  Future<Result> _markAs(List<TodoItem> tasks) async {
    // As they are now, not as they were when the change was made.
    if (await get() != null) return const Failure("Couldn't undo that");
    final List<TodoItem> restored;
    try {
      restored = [
        for (final was in tasks)
          // Not one that's been deleted since.
          if (_tree.nodeOf(was)?.task case final now?)
            now.copyWith(
              done: was.done,
              reminder: was.reminder,
              progress: was.progress,
            ),
      ];
      await _tasksRepository.updateItems(restored);
    } catch (e) {
      return Failure("Couldn't undo that");
    }
    await _reload();
    if (!await _reminders.setEach(restored)) {
      return Failure("Undone, but not every reminder could be set");
    }
    return Success("Undone");
  }

  /// Reminds the user of [task] once, on its day at its time, or turns its
  /// reminder off when it has one. Turning one on asks the user to let the
  /// app post notifications, while they're off: see [_askToShow].
  Future<Result> toggleReminder(TodoItem task) {
    task = _current(task);
    return task.reminder == Reminder.none
        ? _remindOnce(task)
        : _cancelReminder(task);
  }

  /// Reminds the user of [task] every day, at its time, asking to post
  /// notifications as [toggleReminder] does.
  Future<Result> remindDaily(TodoItem task) =>
      _repeat(_current(task), Recurrence.daily());

  /// Saves the tasks to a file locked with a password that
  /// [askForBackupPassword] gets from the user, once the App Lock lets them
  /// through: with [askForPassword], for an app locked with a password. Null
  /// if the user cancels.
  Future<Result?> backup({
    required PasswordPrompt askForPassword,
    required NewBackupPasswordPrompt askForBackupPassword,
  }) => _backups.backUp(
    askForPassword: askForPassword,
    askForBackupPassword: askForBackupPassword,
    records: (_) async => Granted([
      for (final task in await _tasksRepository.getItems()) task.toMap(),
    ]),
  );

  /// Adds the tasks from a backup file the user picks, once
  /// [askForBackupPassword] gets the password it's locked with, in place of
  /// every task there is when [overwrite] is set. Null if the user cancels.
  Future<Result?> restore(
    bool overwrite, {
    required BackupPasswordPrompt askForBackupPassword,
  }) => _backups.restore(
    askForBackupPassword: askForBackupPassword,
    putBack: (records) => _putBackRestored(records, overwrite: overwrite),
  );

  /// Adds the tasks [records] has, from a backup, in place of every task
  /// there is when [overwrite] is set, with their reminders.
  Future<Result> _putBackRestored(
    List<dynamic> records, {
    required bool overwrite,
  }) async {
    final importedTasks = records.map<TodoItem>((e) {
      final task = TodoItem.fromMap(e);
      // A daily task from a backup older than tasks' days counts its days
      // from today on.
      return task.repeats && task.progress.since == null
          ? task.copyWith(progress: task.progress.startingOn(today))
          : task;
    }).toList();

    final existingTasks = overwrite
        ? <TodoItem>[]
        : await _tasksRepository.getItems();
    final newTasks = <TodoItem>[];

    for (final item in importedTasks) {
      // From a backup older than uuids, which reminders need their own of.
      if (item.uuid.isEmpty) {
        newTasks.add(item.copyWith(uuid: const UuidV4().generate()));
        continue;
      }
      final exists = existingTasks.any((task) => task.uuid == item.uuid);

      if (exists) continue;

      newTasks.add(item);
    }

    try {
      // All or nothing, so a restore that fails part-way through leaves
      // the tasks as they were.
      await _tasksRepository.importItems(newTasks, overwrite: overwrite);
    } catch (e) {
      return Failure("Couldn't restore the backup. Nothing was changed.");
    }
    await _reload();
    final result = await _setRestoredReminders(newTasks, replaced: overwrite);
    await _settle();
    return result;
  }

  /// Turns on the reminders of [tasks], which have just been restored, once
  /// the reminders of the tasks they [replaced] are off. A reminder that
  /// can't be set leaves its task restored without it, and is named.
  Future<Result> _setRestoredReminders(
    List<TodoItem> tasks, {
    required bool replaced,
  }) async {
    var oldRemindersOff = true;
    if (replaced) {
      try {
        await _reminders.cancelAll();
      } catch (e) {
        oldRemindersOff = false;
      }
    }
    final failed = <String>[];
    for (final item in tasks) {
      try {
        await _reminders.set(item);
      } catch (e) {
        failed.add(item.title);
      }
    }
    if (failed.isNotEmpty) {
      final which = failed.length == 1
          ? failed.first
          : "${failed.first} and ${failed.length - 1} more";
      return Failure("Couldn't set the reminder for $which");
    }
    if (!oldRemindersOff) {
      return Failure("Couldn't turn off the old reminders");
    }
    return Success("Data Restored");
  }

  /// Sets every reminder again, as whether they say which task they're for
  /// goes by the App Lock: for once it's turned on or off. Whether every one
  /// was set.
  Future<bool> refreshReminders() async {
    try {
      return await _reminders.setEach(await _tasksRepository.getItems());
    } catch (e) {
      // The reminders stay as they were.
      return false;
    }
  }

  /// Reminds the user of [task] once, on its day at its time, if that's
  /// still to come. A task done already is to do again, as a reminder of it
  /// means it isn't done.
  Future<Result> _remindOnce(TodoItem task) async {
    final day = task.day;
    final time = task.time;
    if (day == null || time == null) {
      return const Info("A reminder needs a date and a time");
    }
    final scheduledTime = time.on(day);
    if (!scheduledTime.isAfter(_now())) {
      return const Info("A reminder needs a date and time in the future");
    }
    final reminding = task.copyWith(done: false, reminder: Reminder.once);
    final shown = await _askToShow();
    if (await _setReminder(reminding, was: task) case final failed?) {
      return failed;
    }
    final undone = task.done ? "Task Undone. " : "";
    if (!shown) return Failure("$undone$_notShown");
    final away = DateTimeUtils.durationToString(
      scheduledTime.difference(_now()),
    );
    return Success("${undone}Reminder Set\nIn $away");
  }

  /// Has [task] come round as [rule] has it, with the user reminded at its
  /// time each time, and [progress] as its days, or else the days
  /// [_progressAs] gives it. Not when it would stop before it comes round.
  Future<Result> _repeat(
    TodoItem task,
    Recurrence rule, {
    RepeatProgress? progress,
  }) async {
    if (task.time == null) return const Info("A reminder needs a time");
    final repeating = task.repeatingAs(
      rule,
      progress: progress ?? _progressAs(task, rule),
    );
    if (repeating.occurrenceOn(today) == null) {
      return const Info("The reminder ends before the task comes round");
    }
    // One whose last time has gone has nothing more to remind of.
    final ended = repeating.recurrence!.hasEndedBy(today);
    final shown = ended || await _askToShow();
    // Without its day, as a repeating task has none.
    if (await _setReminder(repeating, was: task) case final failed?) {
      return failed;
    }
    if (ended) return const Info("Task Updated");
    return shown ? const Success("Reminder Set") : const Failure(_notShown);
  }

  /// Saves [task] with its reminder, then sets that reminder on the phone:
  /// in that order, so the task never has a reminder going off that it
  /// doesn't show. Should the phone not take it, or not all of it, the task
  /// goes back as it [was], with the reminders it had. Why it couldn't be
  /// set, or null.
  Future<Result?> _setReminder(TodoItem task, {required TodoItem was}) async {
    try {
      await _tasksRepository.updateItem(task);
    } catch (e) {
      // Nothing's changed, on the phone or off it.
      return const Failure("Couldn't set the reminder");
    }
    try {
      await _reminders.set(task);
    } catch (e) {
      try {
        await _reminders.cancel(task);
        await _tasksRepository.updateItem(was);
        await _reminders.set(was);
      } catch (e) {
        // As far as it got.
      }
      await _reload();
      return const Failure("Couldn't set the reminder");
    }
    await _reload();
    return null;
  }

  /// What's said of a reminder that's set, but that the phone won't show
  /// while the app's notifications are off. It's set all the same, so it
  /// goes off once they're on again.
  static const _notShown =
      "Reminder set, but notifications are off for this app";

  /// Whether the phone will show a reminder being turned on, once the user
  /// has been asked to let the app post notifications, if they're off: then,
  /// rather than as the app starts. True when that can't be told, as when
  /// it's being asked already, since nothing can be said of it then.
  Future<bool> _askToShow() async {
    try {
      return await _reminders.askToShow();
    } catch (e) {
      return true;
    }
  }

  /// [task]'s days once it comes round as [rule] has it, or once it doesn't
  /// repeat, for null. One that starts repeating, or starts coming round on
  /// other days, counts its times from today on, with today done if the
  /// task was and today is one of them. Any other keeps its days.
  RepeatProgress _progressAs(TodoItem task, Recurrence? rule) {
    final was = task.recurrence;
    if (rule == null || (was != null && was.repeatsLike(rule))) {
      return task.progress;
    }
    final fresh = task.progress.startingOn(today);
    return rule.fits(today) ? fresh.withDay(today, done: task.done) : fresh;
  }

  /// Turns [task]'s reminder off: saved first, then cancelled on the phone,
  /// so the task never shows a reminder that's no longer set. Should the
  /// phone not cancel it, or not all of it, the reminder's back on, saved
  /// and set as it was.
  Future<Result> _cancelReminder(TodoItem task) async {
    const failure = Failure("Couldn't turn the reminder off");
    try {
      await _tasksRepository.updateItem(task.copyWith(reminder: Reminder.none));
    } catch (e) {
      // Still on, and still set.
      return failure;
    }
    try {
      await _reminders.cancel(task);
    } catch (e) {
      try {
        await _tasksRepository.updateItem(task);
        await _reminders.set(task);
      } catch (e) {
        // As far as it got.
      }
      await _reload();
      return failure;
    }
    await _reload();
    return const Info("Reminder Turned Off");
  }
}

DateTime _dateOf(DateTime time) => DateTime(time.year, time.month, time.day);
