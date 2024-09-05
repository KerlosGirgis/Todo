import 'package:flutter/material.dart';
import 'package:todo/models/user_profile.dart';
import '../services/color_provider.dart';
import '../services/database_service.dart';

class UserProvider with ChangeNotifier {
  UserProfile user = UserProfile(firstName: "user", lastName: "", pic: "000", theme: 1);

  ColorProvider colorProvider =ColorProvider(1);

  Future<void> get() async {
    List users;
    users = await DatabaseService().getUser();
    if(users.isEmpty){
      DatabaseService().insertUser(user);
      users = await DatabaseService().getUser();
      user = users.first;
      colorProvider =ColorProvider(1);
    }
    else{
      user = users.first;
      colorProvider =ColorProvider(user.theme);
    }
    notifyListeners();
  }

  editFirstName(String firstName) async {
    user.firstName = firstName;
    await DatabaseService().updateUser(user);
    notifyListeners();
  }

  editLastName(String lastName) async {
    user.lastName = lastName;
    await DatabaseService().updateUser(user);
    notifyListeners();
  }

  editPic(String pic) async {
    user.pic = pic;
    await DatabaseService().updateUser(user);
    notifyListeners();
  }

  changeTheme() async {
    if(user.theme==1){
      user.theme=0;
      colorProvider =ColorProvider(0);
      await DatabaseService().updateUser(user);
      notifyListeners();
    }
    else{
      user.theme=1;
      colorProvider =ColorProvider(1);
      await DatabaseService().updateUser(user);
      notifyListeners();
    }
  }

}