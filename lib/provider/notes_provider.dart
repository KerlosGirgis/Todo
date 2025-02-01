import 'package:fluttertoast/fluttertoast.dart';
import 'package:home_widget/home_widget.dart';

import '../models/note.dart';
import '../services/authentication_service.dart';
import '../services/database_service.dart';
import 'package:flutter/material.dart';

import '../services/lock_manager.dart';

class NotesProvider with ChangeNotifier {
  List<Note> notes = [];

  Future<void> get() async {
    notes = await DatabaseService().getNotes();
    notifyListeners();
  }

  void updateAndroidWidget(String note) {
    HomeWidget.saveWidgetData("note", note);
    HomeWidget.updateWidget(
      androidName: "Note",
    );
  }

  Future<void> addNote(Note note) async {
    await DatabaseService().insertNote(note);
    get();
  }

  Future<void> updateNote(Note note) async {
    await DatabaseService().updateNote(note);
    get();
  }

  Future<void> deleteNote(int id) async {
    await DatabaseService().deleteNote(id);
    get();
  }

  Future<void> syncAfterReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final oldNote = notes.removeAt(oldIndex);
    notes.insert(newIndex, oldNote);
    await DatabaseService().deleteAllNotes();
    for (var note in notes) {
      await DatabaseService().insertNote(note); // Reinsert items in new order
    }
    get();
  }

  Future<void> backup() async {
    if (await LockManager().isLockEnabled()) {
      if (await AuthenticationService().authenticate()) {
        try {
          await DatabaseService().exportNotesToJson().then((s) {
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
        await DatabaseService().exportNotesToJson().then((s) {
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
      await DatabaseService().importNotesFromJson().then((s) {
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
}
