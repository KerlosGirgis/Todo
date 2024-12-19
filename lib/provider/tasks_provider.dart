import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/todo_item.dart';
import '../services/authentication_service.dart';
import '../services/database_service.dart';
import '../services/lock_manager.dart';

class TasksProvider with ChangeNotifier{
  List<TodoItem> items = [];

  Future<void> get() async {
    items = await DatabaseService().getItems();
    notifyListeners();
  }
  Future<void> updateTask(TodoItem todo) async {
    await DatabaseService().updateItem(todo);
    get();
    notifyListeners();
  }

  Future<void> deleteTask(int id) async {
    await DatabaseService().deleteItem(id);
    notifyListeners();
  }

  Future<void> syncAfterReorder(int oldIndex,int newIndex) async {
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
    notifyListeners();
  }
  Future<void> addTask(TodoItem todo) async {
    await DatabaseService().insertItem(todo);
    get();
    notifyListeners();
  }
  Future<void> dismissTask(int index,int id) async {
    items.removeAt(index);
    DatabaseService().deleteItem(id);
    get();
    notifyListeners();
  }

  Future<void> backup()async {
    if(await LockManager().isLockEnabled()){
      if(await AuthenticationService().authenticate()){
        try{
          await DatabaseService().exportToDoToJson().then((s){
            if(s){
              Fluttertoast.showToast(
                  msg: "Backup Created",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                  fontSize: 18.0);
            }
            else{
              Fluttertoast.showToast(
                  msg: "Backup Failed",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  fontSize: 18.0);
            }
          });
        }
        catch(e){
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
    else{
      try{
        await DatabaseService().exportToDoToJson().then((s){
          if(s){
            Fluttertoast.showToast(
                msg: "Backup Created",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                backgroundColor: Colors.green,
                textColor: Colors.white,
                fontSize: 18.0);
          }
          else{
            Fluttertoast.showToast(
                msg: "Backup Failed",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                backgroundColor: Colors.red,
                textColor: Colors.white,
                fontSize: 18.0);
          }
        });
      }
      catch(e){
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

  Future<void> restore()async {
    try{
      await DatabaseService().importToDoFromJson().then((s){
        if(s){
          Fluttertoast.showToast(
              msg: "Data Restored",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.green,
              textColor: Colors.white,
              fontSize: 18.0);
        }
        else{
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
    }
    catch(e){
      Fluttertoast.showToast(
          msg: "Failed To Restore",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 18.0);
    }
  }

}