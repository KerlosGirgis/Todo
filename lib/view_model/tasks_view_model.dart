import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:todo/services/tasks_repository.dart';
import 'package:todo/view_model/user_view_model.dart';
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
    cancelNotification(index);
    items.removeAt(index);
    notifyListeners();
    await tasksRepository.deleteItem(id);
    get();
  }

  Future<void> markAsDone(int index, UserViewModel user) async {
    if (items[index].status == 0) {
      if (items[index].notification == 1 || items[index].notification == 2) {
        cancelNotification(index);
        updateTask(
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
        ).then((value) {
          user.increaseFinished();
          Fluttertoast.showToast(
            msg: "Task done",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 19.0,
          );
        });
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
        ).then((value) {
          user.increaseFinished();
          Fluttertoast.showToast(
            msg: "Task done",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 19.0,
          );
        });
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
      ).then((value) {
        user.decreaseFinished();
        Fluttertoast.showToast(
          msg: "Task undone",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: const Color(0xff1E1E1E),
          textColor: Colors.white,
          fontSize: 19.0,
        );
      });
    }
  }

  Future<void> backup() async {
    if (await LockManager().isLockEnabled()) {
      if (await AuthenticationService().authenticate()) {
        try {
          await tasksRepository.exportToDoToJson().then((s) {
            if (s) {
              Fluttertoast.showToast(
                  msg: "Backup Created",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                  fontSize: 18.0);
            } else {
              Fluttertoast.showToast(
                  msg: "Backup Failed",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  fontSize: 18.0);
            }
          });
        } catch (e) {
          Fluttertoast.showToast(
              msg: "Backup Failed",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 18.0);
        }
      }
    } else {
      try {
        await tasksRepository.exportToDoToJson().then((s) {
          if (s) {
            Fluttertoast.showToast(
                msg: "Backup Created",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                backgroundColor: Colors.green,
                textColor: Colors.white,
                fontSize: 18.0);
          }
        });
      } catch (e) {
        Fluttertoast.showToast(
            msg: "Backup Failed",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 18.0);
      }
    }
  }

  Future<void> restore(bool overflow) async {
    try {
      await tasksRepository.importToDoFromJson(overflow).then((s) {
        if (s) {
          Fluttertoast.showToast(
              msg: "Data Restored",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.green,
              textColor: Colors.white,
              fontSize: 18.0);
        }
      });
      get();
    } catch (e) {
      Fluttertoast.showToast(
          msg: "Failed To Restore",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 18.0);
    }
  }

  Future<void> changeNotification(int index) async {
    if (items[index].notification == 0) {
      try {
        if (items[index].time.isNotEmpty && items[index].date.isNotEmpty) {
          DateTime scheduledTime = DateTimeUtils.stringToDateTime(
              items[index].date, items[index].time);
          if (scheduledTime.isAfter(DateTime.now()) &&
              items[index].status == 0) {
            NotificationService.scheduleNotification(
              items[index].uuid.hashCode,
              "Don't Forget Your Task!",
              items[index].title,
              scheduledTime,
            ).then((onValue) {
              updateTask(
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
              ).then((value) {
                Fluttertoast.showToast(
                  msg:
                      "Time remaining:\n ${DateTimeUtils.durationToString(scheduledTime.difference(DateTime.now()))}",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: const Color(0xff1E1E1E),
                  textColor: Colors.white,
                  fontSize: 19.0,
                );
              });
            });
          } else {
            Fluttertoast.showToast(
              msg: "Oops!!",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 19.0,
            );
          }
        } else {
          Fluttertoast.showToast(
            msg: "Oops!!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 19.0,
          );
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: "Failed to Enable Notification",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 19.0,
        );
      }
    } else {
      FlutterLocalNotificationsPlugin()
          .cancel(id:items[index].uuid.hashCode)
          .then((onValue) {
        updateTask(
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
        ).then((value) {
          Fluttertoast.showToast(
            msg: "Notification Disabled",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: const Color(0xff1E1E1E),
            textColor: Colors.white,
            fontSize: 19.0,
          );
        });
      });
    }
  }


  Future<void> changeDailyNotification(int index) async {
    if (items[index].notification == 1) {
      await changeNotification(index);
    }
    if (items[index].notification == 2) {
      FlutterLocalNotificationsPlugin()
          .cancel(id:items[index].uuid.hashCode)
          .then((onValue) {
        updateTask(
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
        ).then((value) {
          Fluttertoast.showToast(
            msg: "Notification Disabled",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: const Color(0xff1E1E1E),
            textColor: Colors.white,
            fontSize: 19.0,
          );
        });
      });
      return;
    }
    if (items[index].time.isNotEmpty) {
      try {
        NotificationService.scheduleDailyNotification(
          items[index].uuid.hashCode,
          "Don't Forget Your Task!",
          items[index].title,
          DateTimeUtils.parseTime(items[index].time),
        ).then((onValue) {
          updateTask(
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
          ).then((value) {
            Fluttertoast.showToast(
              msg: "Notification Enabled",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.green,
              textColor: Colors.white,
              fontSize: 19.0,
            );
          });
        });
      } catch (e) {
        Fluttertoast.showToast(
          msg: "Failed to Enable Notification",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 19.0,
        );
      }
    } else {
      Fluttertoast.showToast(
        msg: "Oops!!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 19.0,
      );
    }
  }

  void cancelNotification(int index) {
    if (items[index].notification == 1 || items[index].notification == 2) {
      FlutterLocalNotificationsPlugin().cancel(id:items[index].uuid.hashCode);
    }
  }
}
