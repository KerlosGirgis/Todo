import 'dart:async';
import 'dart:collection';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../services/file_service.dart';
import '../repositories/tasks_repository.dart';

import 'package:uuid/v4.dart';

import '../core/prompts.dart';
import '../core/utils/date_time_utils.dart';
import '../models/app_lock.dart';
import '../models/clock_time.dart';
import '../models/recurrence.dart';
import '../models/reminder_plan.dart';
import '../models/repeat_progress.dart';
import '../models/task_filters.dart';
import '../models/task_listing.dart';
import '../models/task_sort.dart';
import '../models/task_tree.dart';
import '../core/tasks_widget_snapshot.dart';
import '../models/todo_item.dart';
import '../models/trashed.dart';
import '../services/authentication_service.dart';
import '../services/backup_service.dart';
import '../services/home_widget_service.dart';
import '../services/lock_service.dart';
import '../services/notification_service.dart';

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

class TasksViewModel with ChangeNotifier {
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
       _backupService = backupService ?? BackupService(),
       _fileService = fileService ?? FileService(),
       _lockService = lockService ?? LockService(),
       _authService = authService ?? AuthenticationService(),
       _notificationService = notificationService ?? NotificationService(),
       _homeWidgetService = homeWidgetService ?? HomeWidgetService(),
       _now = clock ?? DateTime.now {
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

  List<Trashed<TaskBranch>> _trash = [];

  /// The tasks in the trash, each with the tasks in it, the last deleted
  /// first, once [getTrash] has read them in.
  List<Trashed<TaskBranch>> get trash => UnmodifiableListView(_trash);

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
  final BackupService _backupService;
  final FileService _fileService;
  final LockService _lockService;
  final AuthenticationService _authService;
  final NotificationService _notificationService;
  final HomeWidgetService _homeWidgetService;
  final DateTime Function() _now;

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

  Future<void> get() async {
    if (!_listingKnown) {
      _listingKnown = true;
      try {
        _listing = await _tasksRepository.getListing() ?? _listing;
      } catch (e) {
        // Listed as usual, then.
      }
    }
    final today = _dateOf(_now());
    _setDay(today, await _tasksRepository.getItems());
    _awaitNewDay();
    // Reminders set in another time zone, or before reminders went by the
    // phone's, keep to another clock, and a one-time one from back then goes
    // off again every year. Ones set under ids made another way can't be
    // found by their tasks to be cancelled. So they're all set afresh.
    // Otherwise, a reminder set before reminders went by the App Lock, or one
    // whose change of lock didn't get to it, may still say which task it's
    // for.
    if (!_remindersChecked) {
      _remindersChecked = true;
      try {
        final timeZone = _notificationService.timeZone;
        if (await _notificationService.remindersTimeZone() != timeZone ||
            await _notificationService.remindersIdVersion() !=
                ReminderPlan.idVersion) {
          await _notificationService.cancelPendingNotifications();
          // Until they all are, they're set afresh at each start.
          if (await refreshReminders()) {
            await _notificationService.setRemindersTimeZone(timeZone);
            await _notificationService.setRemindersIdVersion(
              ReminderPlan.idVersion,
            );
          }
        } else if (await _lockService.getLock() != AppLock.off) {
          await refreshReminders();
        } else {
          // The days have gone by since they were last set.
          await _refreshEndingReminders();
        }
      } catch (e) {
        // The reminders stay as they were.
      }
    }
  }

  /// Reads the tasks in again once a change has been saved, or has failed,
  /// to show them as they now are. Should that fail, they're shown as they
  /// were until they're next read in: the change has gone through, or the
  /// user has been told it hasn't, either way.
  Future<void> _reload() async {
    try {
      await get();
    } catch (e) {
      // Shown as they were, until they're next read in.
    }
  }

  /// Brings each repeating task up to date if a new day has begun since the
  /// tasks were: at midnight, or as the app comes back after it. A daily
  /// task starts over, not done yet, as does one that comes round today.
  void checkForNewDay() {
    if (_day == null) return;
    final today = _dateOf(_now());
    if (today != _day) {
      _setDay(today, _allTasks);
      unawaited(_refreshEndingReminders());
    }
    _awaitNewDay();
  }

  /// Sets afresh the reminders of the repeating tasks that stop on a day, as
  /// the days go by: nearing their last day, their last times are set one
  /// by one, so that they stop with them, and once those have gone, they're
  /// off.
  Future<void> _refreshEndingReminders() async {
    for (final task in _allTasks) {
      if (!task.reminder.repeats || task.until == null) continue;
      try {
        await _scheduleReminder(task);
      } catch (e) {
        // The others are set all the same.
      }
    }
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
  /// own order: sorted otherwise, a task's place isn't up to them.
  Future<void> syncAfterReorder(int oldIndex, int newIndex) async {
    if (sort != TaskSort.custom) return;
    final nodes = _shown.nodes;
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= nodes.length) {
      return;
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
      return;
    }
    if (below == null) {
      await moveInto(moved.task, null);
    } else {
      await moveBeside(moved.task, below.task, after: false);
    }
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
        return const Failure("Couldn't add the task");
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
      return const Failure("Couldn't save the task");
    }
    try {
      // Whichever it had, in case it's been turned off, or it's changed.
      await _cancelReminders(task);
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
  /// put back or deleted for good, and turns their reminders off. Gives the
  /// entry they're in the trash as, which puts them back, or null if they
  /// couldn't be moved, which leaves them on the list.
  Future<Trashed<TaskBranch>?> delete(TodoItem task) async {
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
      return null;
    }
    for (final each in branch.all) {
      if (each.reminder == Reminder.none) continue;
      try {
        await _cancelReminders(each);
      } catch (e) {
        // It's in the trash all the same.
      }
    }
    await _reloadTrash();
    await _reload();
    return trashed;
  }

  /// Reads in the tasks in the trash.
  Future<void> getTrash() async {
    _trash = await _tasksRepository.getTrash();
    notifyListeners();
  }

  /// Reads in the trash again once it's changed, as [_reload] does the
  /// tasks.
  Future<void> _reloadTrash() async {
    try {
      await getTrash();
    } catch (e) {
      // Shown as it was, until it's next read in.
    }
  }

  /// Puts the task [entry] holds back on the list, with the tasks in it,
  /// where they were when they can be, with their reminders, if those are
  /// still to come. In the task it was a subtask of, if that's on the list.
  Future<Result> restoreFromTrash(Trashed<TaskBranch> entry) async {
    final TaskBranch? branch;
    try {
      branch = await _putBack(entry, await _uuidsInUse());
    } catch (e) {
      return Failure("Couldn't restore the task");
    }
    await _reloadTrash();
    await _reload();
    if (branch == null) return Info("That task isn't in the Trash anymore");
    final reminded = await _remindAgain(branch.all);
    await _settle();
    if (!reminded) {
      return Failure(
        branch.subtasks.isEmpty
            ? "Task restored, but its reminder couldn't be set"
            : "Task restored, but not every reminder could be set",
      );
    }
    return Success("Task Restored");
  }

  /// Puts every task in the trash back on the list, with their reminders.
  Future<Result> restoreAllFromTrash() async {
    final restored = <TaskBranch>[];
    var allBack = true;
    try {
      final uuids = await _uuidsInUse();
      // The first deleted first, so a task deleted later can't take the
      // place it had.
      for (final entry in (await _tasksRepository.getTrash()).reversed) {
        try {
          if (await _putBack(entry, uuids) case final branch?) {
            restored.add(branch);
          }
        } catch (e) {
          allBack = false;
        }
      }
    } catch (e) {
      allBack = false;
    }
    await _reloadTrash();
    await _reload();
    final remindersSet = await _remindAgain([
      for (final branch in restored) ...branch.all,
    ]);
    await _settle();
    if (!allBack) {
      return Failure(
        restored.isEmpty
            ? "Couldn't restore the tasks"
            : "Couldn't restore every task",
      );
    }
    if (!remindersSet) {
      return Failure("Tasks restored, but not every reminder could be set");
    }
    return Success(
      restored.length == 1
          ? "Task Restored"
          : "${restored.length} Tasks Restored",
    );
  }

  /// Deletes the task [entry] holds for good, with the tasks in it.
  Future<Result> deleteForever(Trashed<TaskBranch> entry) async {
    try {
      await _tasksRepository.deleteFromTrash([entry.id]);
    } catch (e) {
      return Failure("Couldn't delete the task");
    }
    await _reloadTrash();
    return Info("Task Deleted Forever");
  }

  /// Deletes every task in the trash for good.
  Future<Result> emptyTrash() async {
    final int count;
    try {
      // The ones there are now, as the user saw them.
      final ids = [for (final entry in _trash) entry.id];
      await _tasksRepository.deleteFromTrash(ids);
      count = ids.length;
    } catch (e) {
      return Failure("Couldn't delete the tasks");
    }
    await _reloadTrash();
    return Info(
      count == 1 ? "1 Task Deleted Forever" : "$count Tasks Deleted Forever",
    );
  }

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

  /// Sets the reminders of [tasks] again, as they're put back from the
  /// trash, or as they were, if they're still to come. Whether every one
  /// could be.
  Future<bool> _remindAgain(Iterable<TodoItem> tasks) async {
    var allSet = true;
    for (final task in tasks) {
      try {
        await _scheduleReminder(task);
      } catch (e) {
        // The others are set all the same.
        allSet = false;
      }
    }
    return allSet;
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
        ? (task.repeats ? "Done for ${_occasionOf(task)}" : "Task done")
        : "Task undone";
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
        await _cancelReminders(each);
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

  /// The day that stands for a repeating [task] today, as a message names
  /// it: "today", "yesterday", "tomorrow", or "Fri, Oct 24".
  String _occasionOf(TodoItem task) =>
      DateTimeUtils.dayInSentence(task.occurrenceOn(today) ?? today, today);

  /// [task]'s title in quotes, cut short if it's long, to name it in a
  /// message.
  static String _named(TodoItem task) {
    final title = task.title.characters;
    return title.length > 24 ? "“${title.take(23)}…”" : "“$title”";
  }

  /// Marks each of [tasks] done or not as it is here, as it was before a
  /// change that's being taken back, with the reminder it had then.
  Future<Result> _markAs(List<TodoItem> tasks) async {
    final List<TodoItem> restored;
    try {
      await get();
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
    if (!await _remindAgain(restored)) {
      return Failure("Undone, but not every reminder could be set");
    }
    return Success("Undone");
  }

  /// Reminds the user of [task] once, on its day at its time, or turns its
  /// reminder off when it has one.
  Future<Result> toggleReminder(TodoItem task) {
    task = _current(task);
    return task.reminder == Reminder.none
        ? _remindOnce(task)
        : _cancelReminder(task);
  }

  /// Reminds the user of [task] every day, at its time.
  Future<Result> remindDaily(TodoItem task) =>
      _repeat(_current(task), Recurrence.daily());

  /// Saves the tasks to a file locked with a password that
  /// [askForBackupPassword] gets from the user, once the App Lock lets them
  /// through: with [askForPassword], for an app locked with a password. Null
  /// if the user cancels.
  Future<Result?> backup({
    required PasswordPrompt askForPassword,
    required NewBackupPasswordPrompt askForBackupPassword,
  }) async {
    final pass = await _authService.passAppLock(askForPassword);
    if (pass == null) return null;
    if (!pass.passed) return Failure("Authentication failed");
    try {
      final tasks = await _tasksRepository.getItems();
      final file = await _backupService.write(
        [for (final task in tasks) task.toMap()],
        kind: BackupKind.tasks,
        askForPassword: askForBackupPassword,
      );
      if (file == null) return null;
      final outputPath = await _fileService.saveFile(file, 'todo.json');
      if (outputPath == null || outputPath.isEmpty) {
        return Info("You didn't choose a directory");
      }
      return Success("Backup Created");
    } catch (e) {
      return Failure("Couldn't back up the tasks");
    }
  }

  /// Adds the tasks from a backup file the user picks, once
  /// [askForBackupPassword] gets the password it's locked with, in place of
  /// every task there is when [overwrite] is set. Null if the user cancels.
  Future<Result?> restore(
    bool overwrite, {
    required BackupPasswordPrompt askForBackupPassword,
  }) async {
    try {
      final bytes = await _fileService.pickJsonFile();
      if (bytes == null) {
        return Info("You didn't choose a file");
      }
      final records = await _backupService.read(
        bytes,
        kind: BackupKind.tasks,
        askForPassword: askForBackupPassword,
      );
      if (records == null) return null;
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
    } on WrongBackupKindException {
      return Failure("That's a backup of notes, not tasks");
    } catch (e) {
      return Failure("Couldn't restore the backup");
    }
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
        await _notificationService.cancelAllNotifications();
      } catch (e) {
        oldRemindersOff = false;
      }
    }
    final failed = <String>[];
    for (final item in tasks) {
      try {
        await _scheduleReminder(item);
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

  static const _reminderTitle = "Don't Forget Your Task!";

  /// Sets the reminders [item] needs, if it has any still to come. Those of
  /// a repeating task that it needs no more, as when its last times are set
  /// one by one, or once they've gone, are cancelled.
  Future<void> _scheduleReminder(TodoItem item) async {
    final alarms = ReminderPlan.of(item, _now());
    if (alarms.isNotEmpty) {
      final body = await _reminderText(item);
      for (final alarm in alarms) {
        switch (alarm) {
          case OnceAlarm(:final id, :final at):
            await _notificationService.scheduleNotification(
              id,
              _reminderTitle,
              body,
              at,
            );
          case RepeatingAlarm(:final id, :final first, :final every):
            await _notificationService.scheduleRepeatingNotification(
              id,
              _reminderTitle,
              body,
              first,
              every,
            );
        }
      }
    }
    if (!item.reminder.repeats) return;
    final kept = {for (final alarm in alarms) alarm.id};
    for (final id in ReminderPlan.idsOf(item.uuid)) {
      if (!kept.contains(id)) {
        await _notificationService.cancelNotification(id);
      }
    }
  }

  /// Cancels the reminders [task] has on the phone: every one a repeating
  /// task's can be, or a one-time reminder.
  Future<void> _cancelReminders(TodoItem task) async {
    final ids = task.reminder.repeats
        ? ReminderPlan.idsOf(task.uuid)
        : [ReminderPlan.idOf(task.uuid)];
    for (final id in ids) {
      await _notificationService.cancelNotification(id);
    }
  }

  /// What [task]'s reminder says under its title: which task it is, but not
  /// while the app is locked, as the lock screen and the notification shade
  /// would show it to anyone with the phone.
  Future<String?> _reminderText(TodoItem task) async =>
      await _lockService.getLock() == AppLock.off ? task.title : null;

  /// Sets every reminder again, as whether they say which task they're for
  /// goes by the App Lock: for once it's turned on or off. Whether every one
  /// was set.
  Future<bool> refreshReminders() async {
    var allSet = true;
    try {
      for (final task in await _tasksRepository.getItems()) {
        try {
          await _scheduleReminder(task);
        } catch (e) {
          // The others are set all the same.
          allSet = false;
        }
      }
    } catch (e) {
      // The reminders stay as they were.
      return false;
    }
    return allSet;
  }

  /// Reminds the user of [task] once, on its day at its time, if that's
  /// still to come. A task done already is to do again, as a reminder of it
  /// means it isn't done.
  Future<Result> _remindOnce(TodoItem task) async {
    try {
      final day = task.day;
      final time = task.time;
      if (day != null && time != null) {
        DateTime scheduledTime = time.on(day);
        if (scheduledTime.isAfter(_now())) {
          await _notificationService.scheduleNotification(
            ReminderPlan.idOf(task.uuid),
            _reminderTitle,
            await _reminderText(task),
            scheduledTime,
          );
          await _tasksRepository.updateItem(
            task.copyWith(done: false, reminder: Reminder.once),
          );
          await _reload();
          final remaining =
              "Time remaining:\n "
              "${DateTimeUtils.durationToString(scheduledTime.difference(_now()))}";
          return Info(task.done ? "Task undone. $remaining" : remaining);
        } else {
          return Info("Please set time and date in the future");
        }
      } else {
        return Info("Please set time and date");
      }
    } catch (e) {
      return Failure("Couldn't set the reminder");
    }
  }

  /// Has [task] come round as [rule] has it, with the user reminded at its
  /// time each time, and [progress] as its days, or else the days
  /// [_progressAs] gives it. Not when it would stop before it comes round.
  Future<Result> _repeat(
    TodoItem task,
    Recurrence rule, {
    RepeatProgress? progress,
  }) async {
    if (task.time == null) return Info("Please set time");
    final repeating = task.repeatingAs(
      rule,
      progress: progress ?? _progressAs(task, rule),
    );
    if (repeating.occurrenceOn(today) == null) {
      return Info("Please set an end after its next time");
    }
    try {
      await _scheduleReminder(repeating);
      // Without its day, as a repeating task has none.
      await _tasksRepository.updateItem(repeating);
      await _reload();
      // One whose last time has gone has nothing more to remind of.
      return repeating.recurrence!.hasEndedBy(today)
          ? Info("Task Updated")
          : Success("Reminder Set");
    } catch (e) {
      return Failure("Couldn't set the reminder");
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

  Future<Result> _cancelReminder(TodoItem task) async {
    try {
      await _cancelReminders(task);
      await _tasksRepository.updateItem(task.copyWith(reminder: Reminder.none));
      await _reload();
      return Info("Reminder Turned Off");
    } catch (e) {
      return Failure("Couldn't turn the reminder off");
    }
  }
}

DateTime _dateOf(DateTime time) => DateTime(time.year, time.month, time.day);

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

  /// Whether there's a title to save the task with.
  bool get canSave => _title.trim().isNotEmpty;

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
