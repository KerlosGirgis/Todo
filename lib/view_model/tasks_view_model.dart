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

class TasksViewModel with ChangeNotifier {
  TasksViewModel({
    TasksRepository? repository,
    BackupService? backupService,
    FileService? fileService,
    LockService? lockService,
    AuthenticationService? authService,
    NotificationService? notificationService,
  })  : _tasksRepository = repository ?? TasksRepository(),
        _backupService = backupService ?? BackupService(),
        _fileService = fileService ?? FileService(),
        _lockService = lockService ?? LockService(),
        _authService = authService ?? AuthenticationService(),
        _notificationService = notificationService ?? NotificationService();

  List<TodoItem> _allTasks = [];
  List<TodoItem> _items = [];

  /// The tasks the filter lets through.
  List<TodoItem> get items => UnmodifiableListView(_items);

  TaskFilter _currentFilter = const AllTasksFilter();
  TaskFilter get currentFilter => _currentFilter;
  int get finishedTasksCount => _allTasks.where((task) => task.done).length;
  int get unfinishedTasksCount =>
      _allTasks.where((task) => !task.done).length;
  final TasksRepository _tasksRepository;
  final BackupService _backupService;
  final FileService _fileService;
  final LockService _lockService;
  final AuthenticationService _authService;
  final NotificationService _notificationService;

  /// Whether the reminders have been checked against the App Lock since the
  /// app started.
  bool _remindersChecked = false;

  Future<void> fetchTasks({TaskFilter? filter}) async {
    if (filter != null) {
      _currentFilter = filter;
    }
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

  void _applyFilter() {
    _items = _currentFilter.apply(_allTasks);
    notifyListeners();
  }

  Future<void> get() async {
    await fetchTasks();
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
    await fetchTasks();
  }

  /// Changes [task]'s details, and sets its [reminder].
  Future<Result> updateTask(
    TodoItem task, {
    required String title,
    required String desc,
    required DateTime? day,
    required ClockTime? time,
    required Reminder reminder,
  }) async {
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
        await cancelNotification(updated);
        return await enableOneTimeNotification(updated);
      case Reminder.daily:
        await cancelNotification(updated);
        return await enableDailyNotification(updated);
      case Reminder.none:
        // In case the reminder was just turned off.
        await _notificationService.cancelNotification(updated.uuid.hashCode);
        return Info("Task Updated");
    }
  }

  /// Adds a task that isn't done yet, then sets its [reminder].
  Future<Result> addTask({
    required String title,
    required String desc,
    required DateTime? day,
    required ClockTime? time,
    required Reminder reminder,
  }) async {
    var task = TodoItem(
      title: title,
      desc: desc,
      day: day,
      time: time,
      uuid: const UuidV4().generate(),
    );
    task = task.copyWith(id: await _tasksRepository.insertItem(task));
    await get();
    return switch (reminder) {
      Reminder.once => enableOneTimeNotification(task),
      // Its day goes, as a daily task has none.
      Reminder.daily => enableDailyNotification(task),
      Reminder.none => Info("Task Added"),
    };
  }

  Future<void> dismissTask(int index, int id) async {
    if (_items[index].reminder != Reminder.none) {
      await _notificationService
          .cancelNotification(_items[index].uuid.hashCode);
    }
    _items.removeAt(index);
    notifyListeners();
    await _tasksRepository.deleteItem(id);
    get();
  }

  Future<Result> markAsDone(int index) async {
    final task = _items[index];
    if (!task.done) {
      if (task.reminder != Reminder.none) {
        await _notificationService.cancelNotification(task.uuid.hashCode);
        await _tasksRepository
            .updateItem(task.copyWith(done: true, reminder: Reminder.none));
        get();
        return Success("Task done");
      } else {
        _tasksRepository.updateItem(task.copyWith(done: true));
        get();
        return Success("Task done");
      }
    } else {
      _tasksRepository.updateItem(task.copyWith(done: false));
      get();
      return Info("Task undone");
    }
  }

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
      get();
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
        if (scheduledTime.isAfter(DateTime.now())) {
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

  Future<Result> enableOneTimeNotification(TodoItem task) async {
    try {
      final day = task.day;
      final time = task.time;
      if (day != null && time != null) {
        DateTime scheduledTime = time.on(day);
        if (scheduledTime.isAfter(DateTime.now()) && !task.done) {
          await _notificationService.scheduleNotification(
            task.uuid.hashCode,
            "Don't Forget Your Task!",
            await _reminderText(task),
            scheduledTime,
          );
          await _tasksRepository
              .updateItem(task.copyWith(reminder: Reminder.once));
          get();
          return Info(
              "Time remaining:\n ${DateTimeUtils.durationToString(scheduledTime.difference(DateTime.now()))}");
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

  Future<Result> enableDailyNotification(TodoItem task) async {
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
        get();
        return Success("Notification Enabled");
      } catch (e) {
        return Failure("Failed to Enable Notification");
      }
    } else {
      return Info("Please set time");
    }
  }

  Future<Result> cancelNotification(TodoItem task) async {
    try {
      await _notificationService.cancelNotification(task.uuid.hashCode);
      await _tasksRepository
          .updateItem(task.copyWith(reminder: Reminder.none));
      get();
      return Info("Notification Disabled");
    } catch (e) {
      return Failure("Failed to disable notification");
    }
  }
}
