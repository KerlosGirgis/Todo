import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:todo/core/result.dart';
import 'package:todo/services/file_service.dart';
import 'package:todo/repositories/tasks_repository.dart';
import 'package:todo/view_model/user_view_model.dart';
import '../core/errors/exceptions/notification_exception.dart';
import '../core/utils/date_time_utils.dart';
import '../models/task_filters.dart';
import '../models/todo_item.dart';
import '../services/authentication_service.dart';
import '../services/lock_service.dart';
import '../services/notification_service.dart';

class TasksViewModel with ChangeNotifier {
  List<TodoItem> _allTasks = [];
  List<TodoItem> items = [];

  TaskFilter _currentFilter = const AllTasksFilter();
  TaskFilter get currentFilter => _currentFilter;
  int get finishedTasksCount =>
      _allTasks.where((task) => task.status == 1).length;
  int get unfinishedTasksCount =>
      _allTasks.where((task) => task.status == 0).length;
  TasksRepository tasksRepository = TasksRepository();

  Future<void> fetchTasks({TaskFilter? filter}) async {
    if (filter != null) {
      _currentFilter = filter;
    }
    _allTasks = await tasksRepository.getItems();
    _applyFilter();
  }

  void _applyFilter() {
    items = _currentFilter.apply(_allTasks);
    notifyListeners();
  }

  Future<void> get() async {
    await fetchTasks();
  }


  Future<void> syncAfterReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final taskToMove = items[oldIndex];

    int effectiveNewIndex = newIndex;
    if (oldIndex < newIndex) {
      effectiveNewIndex -= 1;
    }

    items.removeAt(oldIndex);
    items.insert(effectiveNewIndex, taskToMove);
    notifyListeners();

    final oldMasterIndex = _allTasks.indexOf(taskToMove);
    if (oldMasterIndex != -1) {
      _allTasks.removeAt(oldMasterIndex);
      int insertAt;
      if (effectiveNewIndex + 1 < items.length) {
        final nextTask = items[effectiveNewIndex + 1];
        insertAt = _allTasks.indexOf(nextTask);
      } else if (effectiveNewIndex > 0) {
        final prevTask = items[effectiveNewIndex - 1];
        insertAt = _allTasks.indexOf(prevTask) + 1;
      } else {
        insertAt = _allTasks.length;
      }
      _allTasks.insert(insertAt == -1 ? _allTasks.length : insertAt, taskToMove);
    }

    try {
      await tasksRepository.refreshAllItems(_allTasks);
    } catch (e) {
      await fetchTasks();
    }
  }

  Future<Result> updateTask(TodoItem task) async {
    await tasksRepository.updateItem(task);
    await get();
    if (task.notification == 1) {
      await cancelNotification(task);
      return await enableOneTimeNotification(task);
    } else if (task.notification == 2) {
      await cancelNotification(task);
      return  await enableDailyNotification(task);
    }
    else{
      return Info("Task Updated");
    }
  }

  Future<void> addTask(TodoItem todo) async {
    await tasksRepository.insertItem(todo);
    get();
  }

  Future<void> dismissTask(int index, int id) async {
    if (items[index].notification == 1 || items[index].notification == 2) {
      await FlutterLocalNotificationsPlugin()
          .cancel(id: items[index].uuid.hashCode);
    }
    items.removeAt(index);
    notifyListeners();
    await tasksRepository.deleteItem(id);
    get();
  }

  Future<Result> markAsDone(int index, UserViewModel user) async {
    if (items[index].status == 0) {
      if (items[index].notification == 1 || items[index].notification == 2) {
        await FlutterLocalNotificationsPlugin()
            .cancel(id: items[index].uuid.hashCode);
        await tasksRepository.updateItem(
          TodoItem(
            title: items[index].title,
            desc: items[index].desc,
            id: items[index].id,
            status: 1,
            date: items[index].date,
            time: items[index].time,
            uuid: items[index].uuid,
            notification: 0,
          ),
        );
        get();
        return Success("Task done");
      } else {
        tasksRepository.updateItem(
          TodoItem(
            title: items[index].title,
            desc: items[index].desc,
            id: items[index].id,
            status: 1,
            date: items[index].date,
            time: items[index].time,
            uuid: items[index].uuid,
            notification: items[index].notification,
          ),
        );
        get();
        return Success("Task done");
      }
    } else {
      tasksRepository.updateItem(
        TodoItem(
          title: items[index].title,
          desc: items[index].desc,
          id: items[index].id,
          status: 0,
          date: items[index].date,
          time: items[index].time,
          uuid: items[index].uuid,
          notification: items[index].notification,
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
      final bytes = await tasksRepository.exportToDoToJson();
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

      final oldTasks = await tasksRepository.getItems();

      try {
        if (overwrite) {
          await tasksRepository.deleteAllItems();
          await NotificationService.cancelAllNotifications();
        }

        final existingTasks = overwrite ? [] : oldTasks;

        for (final item in importedTasks) {
          final exists = existingTasks.any((task) => task.uuid == item.uuid);

          if (exists) continue;

          await tasksRepository.insertItem(item);
          try {
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
              if (item.time.isNotEmpty &&
                  item.date.isNotEmpty &&
                  item.status == 0) {
                final time = DateTimeUtils.parseTime(item.time);

                await NotificationService.scheduleDailyNotification(
                  item.uuid.hashCode,
                  "Don't Forget Your Task!",
                  item.title,
                  time,
                );
              }
            }
          } catch (e) {
            throw NotificationException(item.title);
          }
        }
        get();
        return Success("Data Restored");
      } catch (e) {
        await _rollback(oldTasks);
        return Failure("Restore failed. Data rolled back safely.");
      }
    } on NotificationException catch (e) {
      return Failure("Couldn't enable notification for ${e.title}");
    } catch (e) {
      return Failure("Failed To Restore");
    }
  }

  Future<void> _rollback(List<TodoItem> oldTasks) async {
    await tasksRepository.deleteAllItems();
    await NotificationService.cancelAllNotifications();

    for (final item in oldTasks) {
      await tasksRepository.insertItem(item);
      try {
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
          if (item.time.isNotEmpty &&
              item.date.isNotEmpty &&
              item.status == 0) {
            final time = DateTimeUtils.parseTime(item.time);

            await NotificationService.scheduleDailyNotification(
              item.uuid.hashCode,
              "Don't Forget Your Task!",
              item.title,
              time,
            );
          }
        }
      } catch (e) {
        throw NotificationException(item.title);
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
          await tasksRepository.updateItem(
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
        await tasksRepository.updateItem(
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
      await FlutterLocalNotificationsPlugin()
          .cancel(id: task.uuid.hashCode);
      await tasksRepository.updateItem(
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
