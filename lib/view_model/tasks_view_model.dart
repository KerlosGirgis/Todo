import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:todo/core/result.dart';
import 'package:todo/services/file_service.dart';
import 'package:todo/services/tasks_repository.dart';
import 'package:todo/view_model/user_view_model.dart';
import '../core/errors/exceptions/notification_exception.dart';
import '../core/utils/date_time_utils.dart';
import '../models/todo_item.dart';
import '../services/authentication_service.dart';
import '../services/lock_manager.dart';
import '../services/notification_service.dart';

class TasksViewModel with ChangeNotifier {
  List<TodoItem> items = [];

  TasksRepository tasksRepository = TasksRepository();

  Future<void> get() async {
    items = await tasksRepository.getItems();
    notifyListeners();
  }

  Future<void> updateTask(TodoItem todo) async {
    await tasksRepository.updateItem(todo);
    get();
  }

  Future<void> deleteTask(int id) async {
    await tasksRepository.deleteItem(id);
    notifyListeners();
  }

  Future<void> syncAfterReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final oldTodo = items.removeAt(oldIndex);
    items.insert(newIndex, oldTodo);
    await tasksRepository.deleteAllItems();
    for (var item in items) {
      await tasksRepository.insertItem(item);
    }
    get();
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
        await updateTask(
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
        user.increaseFinished();
        return Success("Task done");
      } else {
        updateTask(
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
        user.increaseFinished();
        return Success("Task done");
      }
    } else {
      updateTask(
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
      user.decreaseFinished();
      return Info("Task undone");
    }
  }

  Future<Result> backup() async {
    if (await LockManager().isLockEnabled()) {
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

  Future<Result> enableOneTimeNotification(int index) async {
    try {
      if (items[index].time.isNotEmpty && items[index].date.isNotEmpty) {
        DateTime scheduledTime = DateTimeUtils.stringToDateTime(
            items[index].date, items[index].time);
        if (scheduledTime.isAfter(DateTime.now()) && items[index].status == 0) {
          await NotificationService.scheduleNotification(
            items[index].uuid.hashCode,
            "Don't Forget Your Task!",
            items[index].title,
            scheduledTime,
          );
          await updateTask(
            TodoItem(
              title: items[index].title,
              desc: items[index].desc,
              id: items[index].id,
              status: items[index].status,
              date: items[index].date,
              time: items[index].time,
              uuid: items[index].uuid,
              notification: 1,
            ),
          );
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

  Future<Result> enableDailyNotification(int index) async {
    if (items[index].time.isNotEmpty) {
      try {
        await NotificationService.scheduleDailyNotification(
          items[index].uuid.hashCode,
          "Don't Forget Your Task!",
          items[index].title,
          DateTimeUtils.parseTime(items[index].time),
        );
        await updateTask(
          TodoItem(
            title: items[index].title,
            desc: items[index].desc,
            id: items[index].id,
            status: items[index].status,
            date: "",
            time: items[index].time,
            uuid: items[index].uuid,
            notification: 2,
          ),
        );
        return Success("Notification Enabled");
      } catch (e) {
        return Failure("Failed to Enable Notification");
      }
    } else {
      return Info("Please set time");
    }
  }

  Future<Result> cancelNotification(int index) async {
    try {
      await FlutterLocalNotificationsPlugin()
          .cancel(id: items[index].uuid.hashCode);
      await updateTask(
        TodoItem(
          title: items[index].title,
          desc: items[index].desc,
          id: items[index].id,
          status: items[index].status,
          date: items[index].date,
          time: items[index].time,
          uuid: items[index].uuid,
          notification: 0,
        ),
      );
      return Info("Notification Disabled");
    } catch (e) {
      return Failure("Failed to disable notification");
    }
  }
}
