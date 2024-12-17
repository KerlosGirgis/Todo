import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:todo/models/user_profile.dart';
import '../services/color_provider.dart';
import '../services/database_service.dart';

class UserProvider with ChangeNotifier {
  UserProfile user = UserProfile(name: "user", pic: "000", theme: 1,autoSave: 1, casual: 0);

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

  editName(String name) async {
    user.name = name;
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
  changeAutoSave() async {
    if(user.autoSave==1){
      user.autoSave=0;
      await DatabaseService().updateUser(user);
      notifyListeners();
    }
    else{
      user.autoSave=1;
      await DatabaseService().updateUser(user);
      notifyListeners();
    }
  }

  changeFont() async {
    if(user.casual==1){
      user.casual=0;
      await DatabaseService().updateUser(user);
      notifyListeners();
    }
    else{
      user.casual=1;
      await DatabaseService().updateUser(user);
      notifyListeners();
    }
  }

  DateTime stringToDateTime(String date, String time12Hour) {
    DateFormat format12Hour = DateFormat('h:mm a');
    DateTime dateTime = format12Hour.parse(time12Hour);
    DateFormat format24Hour = DateFormat('HH:mm:ss');
    String time24Hour = format24Hour.format(dateTime);
    return DateTime.parse("$date $time24Hour");
  }

  _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kDebugMode) {
        print("file returned");
      }
      return File(pickedFile.path);
    }
    return null;
  }

  _saveImageToAppStorage(File image) async {
    final appDir = await getApplicationDocumentsDirectory();

    final fileName = image.path.split('/').last;

    final savedImage = await image.copy('${appDir.path}/$fileName');

    return savedImage;
  }

  pickAndSaveImage() async {
    final image = await _pickImage();
    if (image != null) {
      final savedImage = await _saveImageToAppStorage(image);
      editPic(savedImage!.path);
    }
  }

}