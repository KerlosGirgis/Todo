import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:todo/core/result.dart';
import 'package:todo/services/file_service.dart';
import 'package:todo/repositories/tasks_repository.dart';
import 'package:uuid/v4.dart';
import '../core/utils/date_time_utils.dart';
import '../models/task_filters.dart';
import '../models/todo_item.dart';
import '../services/authentication_service.dart';
import '../services/lock_service.dart';
import '../services/notification_service.dart';

class TasksViewModel with ChangeNotifier {
  List<TodoItem> _allTasks = [];
  List<TodoItem> _items = [];

  /// The tasks the filter lets through.
  List<TodoItem> get items => UnmodifiableListView(_items);

  TaskFilter _currentFilter = const AllTasksFilter();
  TaskFilter get currentFilter => _currentFilter;
  int get finishedTasksCount =>
      _allTasks.where((task) => task.status == 1).length;
  int get unfinishedTasksCount =>
      _allTasks.where((task) => task.status == 0).length;
  final TasksRepository _tasksRepository = TasksRepository();

  Future<void> fetchTasks({TaskFilter? filter}) async {
    if (filter != null) {
      _currentFilter = filter;
    }
    _allTasks = await _tasksRepository.getItems();
    _applyFilter();
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

  /// Changes [task]'s details, and sets its reminder to [notification], as
  /// [TodoItem.notification] holds it.
  Future<Result> updateTask(
    TodoItem task, {
    required String title,
    required String desc,
    required String date,
    required String time,
    required int notification,
  }) async {
    final updated = TodoItem(
      title: title,
      desc: desc,
      id: task.id,
      status: task.status,
      date: date,
      time: time,
      uuid: task.uuid,
      notification: notification,
    );
    await _tasksRepository.updateItem(updated);
    await get();
    if (updated.notification == 1) {
      await cancelNotification(updated);
      return await enableOneTimeNotification(updated);
    } else if (updated.notification == 2) {
      await cancelNotification(updated);
      return  await enableDailyNotification(updated);
    }
    else{
      // In case the reminder was just turned off.
      await NotificationService.cancelNotification(updated.uuid.hashCode);
      return Info("Task Updated");
    }
  }

  /// Adds a task that isn't done yet, then sets its reminder to
  /// [notification], as [TodoItem.notification] holds it.
  Future<Result> addTask({
    required String title,
    required String desc,
    required String date,
    required String time,
    required int notification,
  }) async {
    final task = TodoItem(
      title: title,
      desc: desc,
      status: 0,
      date: date,
      time: time,
      uuid: const UuidV4().generate(),
      notification: 0,
    );
    task.id = await _tasksRepository.insertItem(task);
    await get();
    if(notification == 1){
      return enableOneTimeNotification(task);
    }
    else if(notification == 2){
      return enableDailyNotification(task);
    }
    else{
      return Info("Task Added");
    }
  }

  Future<void> dismissTask(int index, int id) async {
    if (_items[index].notification == 1 || _items[index].notification == 2) {
      await NotificationService.cancelNotification(_items[index].uuid.hashCode);
    }
    _items.removeAt(index);
    notifyListeners();
    await _tasksRepository.deleteItem(id);
    get();
  }

  Future<Result> markAsDone(int index) async {
    if (_items[index].status == 0) {
      if (_items[index].notification == 1 || _items[index].notification == 2) {
        await NotificationService.cancelNotification(
            _items[index].uuid.hashCode);
        await _tasksRepository.updateItem(
          TodoItem(
            title: _items[index].title,
            desc: _items[index].desc,
            id: _items[index].id,
            status: 1,
            date: _items[index].date,
            time: _items[index].time,
            uuid: _items[index].uuid,
            notification: 0,
          ),
        );
        get();
        return Success("Task done");
      } else {
        _tasksRepository.updateItem(
          TodoItem(
            title: _items[index].title,
            desc: _items[index].desc,
            id: _items[index].id,
            status: 1,
            date: _items[index].date,
            time: _items[index].time,
            uuid: _items[index].uuid,
            notification: _items[index].notification,
          ),
        );
        get();
        return Success("Task done");
      }
    } else {
      _tasksRepository.updateItem(
        TodoItem(
          title: _items[index].title,
          desc: _items[index].desc,
          id: _items[index].id,
          status: 0,
          date: _items[index].date,
          time: _items[index].time,
          uuid: _items[index].uuid,
          notification: _items[index].notification,
        ),
      );
      get();
      return Info("Task undone");
    }
  }

  Future<Result> backup() async {
    if (await LockService().isLockEnabled()) {
      final isAuth = await AuthenticationService().authenticate();
      if (!isAuth) {
        return Failure("Authentication Failed");
      }
    }
    try {
      final bytes = await _tasksRepository.exportToDoToJson();
      final outputPath = await FileService().saveFile(bytes, 'todo.json');
      if (outputPath == null || outputPath.isEmpty) {
        return Info("You didn't choose a directory");
      }
      return Success("Backup Created");
    } catch (e) {
      return Failure("Backup Failed");
    }
  }

  Future<Result> restore(bool overwrite) async {
    try {
      final fileService = FileService();

      final importedTasks = await fileService.pickAndReadTodos();
      if (importedTasks == null) {
        return Info("You didn't choose a file");
      }

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
        await NotificationService.cancelAllNotifications();
      } catch (e) {
        oldRemindersOff = false;
      }
    }
    final failed = <String>[];
    for (final item in tasks) {
      try {
        await _setRestoredReminder(item);
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

  Future<void> _setRestoredReminder(TodoItem item) async {
    if (item.notification == 1) {
      if (item.time.isNotEmpty && item.date.isNotEmpty) {
        final scheduledTime =
            DateTimeUtils.stringToDateTime(item.date, item.time);

        if (scheduledTime.isAfter(DateTime.now()) && item.status == 0) {
          await NotificationService.scheduleNotification(
            item.uuid.hashCode,
            "Don't Forget Your Task!",
            item.title,
            scheduledTime,
          );
        }
      }
    } else if (item.notification == 2) {
      // Only its time: a daily reminder has no date.
      if (item.time.isNotEmpty && item.status == 0) {
        final time = DateTimeUtils.parseTime(item.time);

        await NotificationService.scheduleDailyNotification(
          item.uuid.hashCode,
          "Don't Forget Your Task!",
          item.title,
          time,
        );
      }
    }
  }

  Future<Result> enableOneTimeNotification(TodoItem task) async {
    try {
      if (task.time.isNotEmpty && task.date.isNotEmpty) {
        DateTime scheduledTime = DateTimeUtils.stringToDateTime(
            task.date, task.time);
        if (scheduledTime.isAfter(DateTime.now()) && task.status == 0) {
          await NotificationService.scheduleNotification(
            task.uuid.hashCode,
            "Don't Forget Your Task!",
            task.title,
            scheduledTime,
          );
          await _tasksRepository.updateItem(
            TodoItem(
              title: task.title,
              desc: task.desc,
              id: task.id,
              status: task.status,
              date: task.date,
              time: task.time,
              uuid: task.uuid,
              notification: 1,
            ),
          );
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
    if (task.time.isNotEmpty) {
      try {
        await NotificationService.scheduleDailyNotification(
          task.uuid.hashCode,
          "Don't Forget Your Task!",
          task.title,
          DateTimeUtils.parseTime(task.time),
        );
        await _tasksRepository.updateItem(
          TodoItem(
            title: task.title,
            desc: task.desc,
            id: task.id,
            status: task.status,
            date: "",
            time: task.time,
            uuid: task.uuid,
            notification: 2,
          ),
        );
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
      await NotificationService.cancelNotification(task.uuid.hashCode);
      await _tasksRepository.updateItem(
        TodoItem(
          title: task.title,
          desc: task.desc,
          id: task.id,
          status: task.status,
          date: task.date,
          time: task.time,
          uuid: task.uuid,
          notification: 0,
        ),
      );
      get();
      return Info("Notification Disabled");
    } catch (e) {
      return Failure("Failed to disable notification");
    }
  }
}
