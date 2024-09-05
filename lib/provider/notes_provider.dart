import '../models/note.dart';
import '../services/database_service.dart';
import 'package:flutter/material.dart';

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




  }