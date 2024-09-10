import 'package:flutter/material.dart';
import 'package:todo/services/notification_service.dart';

import '../models/todo_item.dart';
import '../services/database_service.dart';

class TasksProvider with ChangeNotifier{
  List<TodoItem> items = [];



  Future<void> get() async {
    items = await DatabaseService().getItems();
    NotificationService().syncNotifications(items);
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


  }