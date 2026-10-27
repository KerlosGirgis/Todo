import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:todo/core/result.dart';
import 'package:todo/services/file_service.dart';
import 'package:todo/repositories/tasks_repository.dart';
import 'package:uuid/v4.dart';
import '../core/prompts.dart';
import '../core/utils/date_time_utils.dart';
import '../models/app_lock.dart';
import '../models/clock_time.dart';
import '../models/task_filters.dart';
import '../models/todo_item.dart';
import '../services/authentication_service.dart';
import '../services/backup_service.dart';
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
}

/// How a task's reminder stands, as its form has it.
enum ReminderStatus {
  off,

  /// A one-time reminder without its day or its time.
  needsDayAndTime,

  /// A daily reminder without its time.
  needsTime,

  /// A one-time reminder for a time that's already gone.
  inPast,

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
    DateTime Function()? clock,
  })  : _tasksRepository = repository ?? TasksRepository(),
        _backupService = backupService ?? BackupService(),
        _fileService = fileService ?? FileService(),
        _lockService = lockService ?? LockService(),
        _authService = authService ?? AuthenticationService(),
        _notificationService = notificationService ?? NotificationService(),
        _now = clock ?? DateTime.now;

  List<TodoItem> _allTasks = [];
  List<TodoItem> _items = [];

  /// The tasks the filter lets through.
  List<TodoItem> get items => UnmodifiableListView(_items);

  TaskFilter _currentFilter = const AllTasksFilter();
  TaskFilter get currentFilter => _currentFilter;
  int get finishedTasksCount => _allTasks.where((task) => task.done).length;
  int get unfinishedTasksCount =>
      _allTasks.where((task) => !task.done).length;

  /// Why the filter lets no task through, or null while it lets some.
  EmptyTasksReason? get emptyReason {
    if (_items.isNotEmpty) return null;
    if (_allTasks.isEmpty) return EmptyTasksReason.noTasks;
    return _currentFilter is DoneTasksFilter
        ? EmptyTasksReason.noneDone
        : EmptyTasksReason.allDone;
  }

  final TasksRepository _tasksRepository;
  final BackupService _backupService;
  final FileService _fileService;
  final LockService _lockService;
  final AuthenticationService _authService;
  final NotificationService _notificationService;
  final DateTime Function() _now;

  /// Whether the reminders have been checked against the App Lock since the
  /// app started.
  bool _remindersChecked = false;

  Future<void> get() async {
    _allTasks = await _tasksRepository.getItems();
    _applyFilter();
    // A reminder set before reminders went by the App Lock, or one whose
    // change of lock didn't get to it, still says which task it's for.
    if (!_remindersChecked) {
      _remindersChecked = true;
      try {
        if (await _lockService.getLock() != AppLock.off) {
          await refreshReminders();
        }
      } catch (e) {
        // The reminders stay as they were.
      }
    }
  }

  /// Lists only the tasks [filter] lets through.
  void setFilter(TaskFilter filter) {
    _currentFilter = filter;
    _applyFilter();
  }

  void _applyFilter() {
    _items = _currentFilter.apply(_allTasks);
    notifyListeners();
  }

  Future<void> syncAfterReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final taskToMove = _items[oldIndex];

    _items.removeAt(oldIndex);
    _items.insert(newIndex, taskToMove);
    notifyListeners();

    final oldMasterIndex = _allTasks.indexOf(taskToMove);
    if (oldMasterIndex != -1) {
      _allTasks.removeAt(oldMasterIndex);
      int insertAt;
      if (newIndex + 1 < _items.length) {
        final nextTask = _items[newIndex + 1];
        insertAt = _allTasks.indexOf(nextTask);
      } else if (newIndex > 0) {
        final prevTask = _items[newIndex - 1];
        insertAt = _allTasks.indexOf(prevTask) + 1;
      } else {
        insertAt = _allTasks.length;
      }
      _allTasks.insert(insertAt == -1 ? _allTasks.length : insertAt, taskToMove);
    }

    try {
      await _tasksRepository.refreshAllItems(_allTasks);
    } catch (e) {
      // The order stays as it was in the database.
    }
    // Rewriting the table gives every task a new id, so the tasks are read
    // back in: the ids held before would now point at other tasks.
    await get();
  }

  /// [task] as the tasks are now: found by its uuid, which outlasts a
  /// reorder, as the ids don't, or by its id when tasks share a uuid.
  TodoItem _current(TodoItem task) {
    final sameUuid = _allTasks.where((each) => each.uuid == task.uuid);
    if (sameUuid.length == 1) return sameUuid.single;
    return _allTasks.where((each) => each.id == task.id).firstOrNull ?? task;
  }

  /// A form for [task], or for a new task without one.
  TaskDraft draft([TodoItem? task]) => TaskDraft._(task, _now);

  /// Adds the task [draft] has, or saves the changes to the one it's for,
  /// then sets its reminder.
  Future<Result> save(TaskDraft draft) async {
    // All of it now, as the form may close before the task is saved.
    final task = draft.task;
    final title = draft.title.trim();
    final desc = draft.description.trim();
    final (day, time, reminder) = (draft.day, draft.time, draft.reminder);
    if (title.isEmpty) return Info("Give the task a title");
    if (task == null) {
      var added = TodoItem(
        title: title,
        desc: desc,
        day: day,
        time: time,
        uuid: const UuidV4().generate(),
      );
      added = added.copyWith(id: await _tasksRepository.insertItem(added));
      await get();
      return switch (reminder) {
        Reminder.once => _remindOnce(added),
        // Its day goes, as a daily task has none.
        Reminder.daily => _remindDaily(added),
        Reminder.none => Info("Task Added"),
      };
    }
    final updated = TodoItem(
      title: title,
      desc: desc,
      id: task.id,
      done: task.done,
      day: day,
      time: time,
      uuid: task.uuid,
      reminder: reminder,
    );
    await _tasksRepository.updateItem(updated);
    await get();
    switch (updated.reminder) {
      case Reminder.once:
        await _cancelReminder(updated);
        return await _remindOnce(updated);
      case Reminder.daily:
        await _cancelReminder(updated);
        return await _remindDaily(updated);
      case Reminder.none:
        // In case the reminder was just turned off.
        await _notificationService.cancelNotification(updated.uuid.hashCode);
        return Info("Task Updated");
    }
  }

  /// Deletes [task], and its reminder.
  Future<void> delete(TodoItem task) async {
    task = _current(task);
    // Off the list straight away, as its card has been swiped away.
    _items.removeWhere((each) => each.uuid == task.uuid && each.id == task.id);
    notifyListeners();
    if (task.reminder != Reminder.none) {
      await _notificationService.cancelNotification(task.uuid.hashCode);
    }
    await _tasksRepository.deleteItem(task.id!);
    await get();
  }

  /// Marks [task] done, which turns its reminder off, or not done again.
  Future<Result> toggleDone(TodoItem task) async {
    task = _current(task);
    if (task.done) {
      await _tasksRepository.updateItem(task.copyWith(done: false));
      await get();
      return Info("Task undone");
    }
    if (task.reminder != Reminder.none) {
      await _notificationService.cancelNotification(task.uuid.hashCode);
    }
    await _tasksRepository
        .updateItem(task.copyWith(done: true, reminder: Reminder.none));
    await get();
    return Success("Task done");
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
  Future<Result> remindDaily(TodoItem task) => _remindDaily(_current(task));

  /// Saves the tasks to a file locked with a password that
  /// [askForBackupPassword] gets from the user, once the App Lock lets them
  /// through: with [password], for an app locked with one. Null if the user
  /// cancels.
  Future<Result?> backup({
    String? password,
    required NewBackupPasswordPrompt askForBackupPassword,
  }) async {
    if (!await _authService.passesAppLock(password: password)) {
      return Failure("Authentication Failed");
    }
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
      return Failure("Backup Failed");
    }
  }

  /// Adds the tasks from a backup file the user picks, once
  /// [askForBackupPassword] gets the password it's locked with, in place of
  /// every task there is when [overwrite] is set. Null if the user cancels.
  Future<Result?> restore(bool overwrite,
      {required BackupPasswordPrompt askForBackupPassword}) async {
    try {
      final bytes = await _fileService.pickJsonFile();
      if (bytes == null) {
        return Info("You didn't choose a file");
      }
      final records = await _backupService.read(bytes,
          kind: BackupKind.tasks, askForPassword: askForBackupPassword);
      if (records == null) return null;
      final importedTasks =
          records.map<TodoItem>((e) => TodoItem.fromMap(e)).toList();

      final existingTasks =
          overwrite ? <TodoItem>[] : await _tasksRepository.getItems();
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
        return Failure("Restore failed. Data rolled back safely.");
      }
      await get();
      return await _setRestoredReminders(newTasks, replaced: overwrite);
    } on WrongBackupKindException {
      return Failure("That's a backup of notes, not tasks");
    } catch (e) {
      return Failure("Failed To Restore");
    }
  }

  /// Turns on the reminders of [tasks], which have just been restored, once
  /// the reminders of the tasks they [replaced] are off. A reminder that
  /// can't be set leaves its task restored without it, and is named.
  Future<Result> _setRestoredReminders(List<TodoItem> tasks,
      {required bool replaced}) async {
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
      return Failure("Couldn't enable notification for $which");
    }
    if (!oldRemindersOff) {
      return Failure("Couldn't turn off the old reminders");
    }
    return Success("Data Restored");
  }

  /// Sets [item]'s reminder, if it's still to come.
  Future<void> _scheduleReminder(TodoItem item) async {
    final time = item.time;
    if (time == null || item.done) return;
    switch (item.reminder) {
      case Reminder.once:
        final day = item.day;
        if (day == null) return;
        final scheduledTime = time.on(day);
        if (scheduledTime.isAfter(_now())) {
          await _notificationService.scheduleNotification(
            item.uuid.hashCode,
            "Don't Forget Your Task!",
            await _reminderText(item),
            scheduledTime,
          );
        }
      case Reminder.daily:
        // Only its time: a daily reminder has no day.
        await _notificationService.scheduleDailyNotification(
          item.uuid.hashCode,
          "Don't Forget Your Task!",
          await _reminderText(item),
          time,
        );
      case Reminder.none:
        break;
    }
  }

  /// What [task]'s reminder says under its title: which task it is, but not
  /// while the app is locked, as the lock screen and the notification shade
  /// would show it to anyone with the phone.
  Future<String?> _reminderText(TodoItem task) async =>
      await _lockService.getLock() == AppLock.off ? task.title : null;

  /// Sets every reminder again, as whether they say which task they're for
  /// goes by the App Lock: for once it's turned on or off.
  Future<void> refreshReminders() async {
    try {
      for (final task in await _tasksRepository.getItems()) {
        try {
          await _scheduleReminder(task);
        } catch (e) {
          // That reminder stays as it was.
        }
      }
    } catch (e) {
      // The reminders stay as they were.
    }
  }

  Future<Result> _remindOnce(TodoItem task) async {
    try {
      final day = task.day;
      final time = task.time;
      if (day != null && time != null) {
        DateTime scheduledTime = time.on(day);
        if (scheduledTime.isAfter(_now()) && !task.done) {
          await _notificationService.scheduleNotification(
            task.uuid.hashCode,
            "Don't Forget Your Task!",
            await _reminderText(task),
            scheduledTime,
          );
          await _tasksRepository
              .updateItem(task.copyWith(reminder: Reminder.once));
          await get();
          return Info(
              "Time remaining:\n ${DateTimeUtils.durationToString(scheduledTime.difference(_now()))}");
        } else {
          return Info("Please set time and date in the future");
        }
      } else {
        return Info("Please set time and date");
      }
    } catch (e) {
      return Failure("Failed to Enable Notification");
    }
  }

  Future<Result> _remindDaily(TodoItem task) async {
    final time = task.time;
    if (time != null) {
      try {
        await _notificationService.scheduleDailyNotification(
          task.uuid.hashCode,
          "Don't Forget Your Task!",
          await _reminderText(task),
          time,
        );
        // Without its day, as a daily task has none.
        await _tasksRepository
            .updateItem(task.copyWith(reminder: Reminder.daily));
        await get();
        return Success("Notification Enabled");
      } catch (e) {
        return Failure("Failed to Enable Notification");
      }
    } else {
      return Info("Please set time");
    }
  }

  Future<Result> _cancelReminder(TodoItem task) async {
    try {
      await _notificationService.cancelNotification(task.uuid.hashCode);
      await _tasksRepository
          .updateItem(task.copyWith(reminder: Reminder.none));
      await get();
      return Info("Notification Disabled");
    } catch (e) {
      return Failure("Failed to disable notification");
    }
  }
}

/// A task as its form has it, being added or changed, with the form's
/// rules: a time on its own is for today, and a daily task has no day.
class TaskDraft with ChangeNotifier {
  TaskDraft._(this.task, this._now)
      : _title = task?.title ?? "",
        _description = task?.desc ?? "",
        _day = task?.day,
        _time = task?.time,
        _reminder = task?.reminder ?? Reminder.none;

  /// The task being changed, or null for a new one.
  final TodoItem? task;
  final DateTime Function() _now;

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

  /// Whether there's a title to save the task with.
  bool get canSave => _title.trim().isNotEmpty;

  /// Whether the task can have a day: not while it's for every day.
  bool get hasDay => _reminder != Reminder.daily;

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
  /// for today, unless the task is for every day.
  void setTime(ClockTime? time) {
    _time = time;
    if (time != null && _day == null && hasDay) {
      final now = _now();
      _day = DateTime(now.year, now.month, now.day);
    }
    notifyListeners();
  }

  /// A daily reminder goes off at the task's time every day, so the task
  /// has no day.
  void setReminder(Reminder reminder) {
    _reminder = reminder;
    if (!hasDay) _day = null;
    notifyListeners();
  }

  /// How the reminder stands at [now]: whether it'll go off, or what it
  /// still needs.
  ReminderStatus reminderStatus(DateTime now) {
    final day = _day;
    final time = _time;
    return switch (_reminder) {
      Reminder.none => ReminderStatus.off,
      Reminder.once when day == null || time == null =>
        ReminderStatus.needsDayAndTime,
      Reminder.once when !time!.on(day!).isAfter(now) => ReminderStatus.inPast,
      Reminder.daily when time == null => ReminderStatus.needsTime,
      _ => ReminderStatus.ready,
    };
  }
}
