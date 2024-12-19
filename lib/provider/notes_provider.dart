import 'package:fluttertoast/fluttertoast.dart';

import '../models/note.dart';
import '../services/authentication_service.dart';
import '../services/database_service.dart';
import 'package:flutter/material.dart';

import '../services/lock_manager.dart';

class NotesProvider with ChangeNotifier{
  List<Note> notes = [];

  Future<void> get() async {
    notes = await DatabaseService().getNotes();
    notifyListeners();
  }
  Future<void> addNote(Note note) async {
    DatabaseService().insertNote(note);
    get();
    notifyListeners();
  }
  Future<void> updateNote(Note note) async {
    DatabaseService().updateNote(note);
    get();
    notifyListeners();
  }
  Future<void> deleteNote(int id) async {
    DatabaseService().deleteNote(id);
    get();
    notifyListeners();
  }

  Future<void> backup()async {
    if(await LockManager().isLockEnabled()){
      if(await AuthenticationService().authenticate()){
        try{
          await DatabaseService().exportNotesToJson();
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
        await DatabaseService().exportNotesToJson();
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
      await DatabaseService().importNotesFromJson();
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