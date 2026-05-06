import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/user_profile.dart';
import 'database_service.dart';

class UserRepository{
  Database get db => DatabaseService.db;

  Future<void> insertUser(UserProfile user) {
    return db.insert('User', user.toMap());
  }

  Future<List<UserProfile>> getUser() async {
    List<Map<String, dynamic>> maps = await db.query('User', columns: [
      'id',
      'name',
      'pic',
      'theme',
      'autoSave',
      'casual',
      'verse',
      'count',
      'finished',
      'unFinished',
      'notesTextSize',
      'startPage',
      'descLines',
      'notesTitleSize',
      'tasksTitleSize',
      'tasksDescSize'
    ]);
    List<UserProfile> items = [];
    if (maps.isNotEmpty) {
      for (var element in maps) {
        items.add(UserProfile.fromMap(element));
      }
    }
    return items;
  }

  Future<void> updateUser(UserProfile item) async {
    await db
        .update('User', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

}