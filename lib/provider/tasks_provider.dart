import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../models/todo_item.dart';
import '../services/authentication_service.dart';
import '../services/database_service.dart';
import '../services/lock_manager.dart';
import '../services/notification.dart';

class TasksProvider with ChangeNotifier {
  List<TodoItem> items = [];

  Future<void> get() async {
    items = await DatabaseService().getItems();
    notifyListeners();
  }

  Future<void> updateTask(TodoItem todo) async {
    await DatabaseService().updateItem(todo);
    get();
  }

  Future<void> deleteTask(int id) async {
    await DatabaseService().deleteItem(id);
    notifyListeners();
  }

  Future<void> syncAfterReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final oldTodo = items.removeAt(oldIndex);
    items.insert(newIndex, oldTodo);
    await DatabaseService().deleteAllItems();
    for (var item in items) {
      await DatabaseService().insertItem(item); // Reinsert items in new order
    }
    get();
  }

  Future<void> addTask(TodoItem todo) async {
    await DatabaseService().insertItem(todo);
    get();
  }

  Future<void> dismissTask(int index, int id) async {
    cancelNotification(index);
    items.removeAt(index);
    notifyListeners();
    await DatabaseService().deleteItem(id);
    get();
  }

  Future<void> backup() async {
    if (await LockManager().isLockEnabled()) {
      if (await AuthenticationService().authenticate()) {
        try {
          await DatabaseService().exportToDoToJson().then((s) {
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
        await DatabaseService().exportToDoToJson().then((s) {
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
  }

  Future<void> restore() async {
    try {
      await DatabaseService().importToDoFromJson().then((s) {
        if (s) {
          Fluttertoast.showToast(
              msg: "Data Restored",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.green,
              textColor: Colors.white,
              fontSize: 18.0);
        } else {
          Fluttertoast.showToast(
              msg: "Failed To Restore",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
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
  DateTime stringToDateTime(String date, String time12Hour) {
    DateFormat format12Hour = DateFormat('h:mm a');
    DateTime dateTime = format12Hour.parse(time12Hour);
    DateFormat format24Hour = DateFormat('HH:mm:ss');
    String time24Hour = format24Hour.format(dateTime);
    return DateTime.parse("$date $time24Hour");
  }

  Future<void> changeNotification(int index) async {
    if (items[index].notification == 0) {

      try{
        if(items[index].time.isNotEmpty){
          DateTime scheduledTime=stringToDateTime(items[index].date, items[index].time);
          if(scheduledTime.isAfter(DateTime.now())&&items[index].status==0){
            NotificationService.scheduleNotification(
              items[index].uuid.hashCode,
              "Don't Forget Your Task!",
              items[index].title,
              scheduledTime,
            ).then((onValue){
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
                  msg: "Notification Enabled",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                  fontSize: 19.0,
                );
              });
            });
          }
          else{
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
        else{
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
      catch(e){
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
      FlutterLocalNotificationsPlugin().cancel(items[index].uuid.hashCode).then((onValue){
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
  void cancelNotification(int index){
    if(items[index].notification==1){
      FlutterLocalNotificationsPlugin().cancel(items[index].uuid.hashCode);
    }
  }
}
