import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/todo_item.dart';
import '../view_model/tasks_view_model.dart';
import 'database_service.dart';
import 'notification.dart';

class TasksRepository{

  final Database db = DatabaseService.db;

  Future<void> insertItem(TodoItem item) {
    return db.insert('ToDo', item.toMap());
  }

  Future<List<TodoItem>> getItems() async {
    List<Map<String, dynamic>> maps = await db.query('ToDo', columns: [
      'id',
      'title',
      'desc',
      'status',
      'date',
      'time',
      'uuid',
      'notification'
    ]);
    List<TodoItem> items = [];
    if (maps.isNotEmpty) {
      for (var element in maps) {
        items.add(TodoItem.fromMap(element));
      }
    }
    return items;
  }

  Future<void> deleteItem(int id) async {
    await db.delete('ToDo', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllItems() async {
    await db.delete('ToDo');
  }

  Future<void> updateItem(TodoItem item) async {
    await db
        .update('ToDo', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<bool> exportToDoToJson() async {
    List<TodoItem> items = await getItems();
    String jsonString = jsonEncode(items.map((item) => item.toMap()).toList());
    Uint8List bytes = utf8.encode(jsonString);

    String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select location to save ToDo JSON file',
        fileName: 'todo.json',
        bytes: bytes);

    if (outputPath != null) {
      if (outputPath.isEmpty) {
        return false;
      } else {
        return true;
      }
    } else {
      return false;
    }
  }

  Future<bool> importToDoFromJson() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String jsonString = await file.readAsString();
      List<dynamic> data = jsonDecode(jsonString);

      for (var itemMap in data) {
        TodoItem item = TodoItem.fromMap(itemMap);
        await insertItem(item);
        if(item.notification==1){
          if (item.time.isNotEmpty&&item.date.isNotEmpty) {
            DateTime scheduledTime =
            TasksViewModel().stringToDateTime(item.date, item.time);
            if (scheduledTime.isAfter(DateTime.now()) && item.status == 0) {
              try{
                NotificationService.scheduleNotification(
                  item.uuid.hashCode,
                  "Don't Forget Your Task!",
                  item.title,
                  scheduledTime,
                );
              }catch(e){
                Fluttertoast.showToast(
                    msg: "Couldn't enable notification for ${item.title}",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 19.0);
              }
            }
          }
        }
        else if(item.notification==2){
          if (item.time.isNotEmpty&&item.date.isNotEmpty&&item.status==0) {
            TimeOfDay time = TasksViewModel().parseTime(item.time);
            try{
              NotificationService.scheduleDailyNotification(
                  item.uuid.hashCode,
                  "Don't Forget Your Task!",
                  item.title,
                  time);
            }
            catch(e){
              Fluttertoast.showToast(
                  msg: "Couldn't enable notification for ${item.title}",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  fontSize: 19.0);
            }

          }
        }
      }
      return true;
    } else {
      return false;
    }
  }

}