import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/lock_manager.dart';
import 'package:todo/services/user_repository.dart';
import '../services/color_provider.dart';

class UserProvider with ChangeNotifier {
  UserProfile user = UserProfile(name: "user", pic: "000", theme: 1,autoSave: 1, casual: 0, verse: 1, count: 0, finished: 0, unFinished: 0, notesTextSize: 1);

  ColorProvider colorProvider =ColorProvider(1);

  late bool isEnabled;
  late double tempNotesTextSize;

  UserRepository userRepository = UserRepository();

  Future<void> get() async {
    List users;
    users = await userRepository.getUser();
    if(users.isEmpty){
      userRepository.insertUser(user);
      users = await userRepository.getUser();
      user = users.first;
      colorProvider =ColorProvider(1);
    }
    else{
      user = users.first;
      colorProvider =ColorProvider(user.theme);
    }
    isEnabled=await LockManager().isLockEnabled();
    tempNotesTextSize=user.notesTextSize;
    notifyListeners();
  }

  editName(String name) async {
    user.name = name;
    await userRepository.updateUser(user);
    notifyListeners();
  }

  editPic(String pic) async {
    user.pic = pic;
    await userRepository.updateUser(user);
    notifyListeners();
  }

  changeTheme() async {
    if(user.theme==1){
      user.theme=0;
      colorProvider =ColorProvider(0);
      await userRepository.updateUser(user);
      notifyListeners();
    }
    else{
      user.theme=1;
      colorProvider =ColorProvider(1);
      await userRepository.updateUser(user);
      notifyListeners();
    }
  }
  changeAutoSave() async {
    if(user.autoSave==1){
      user.autoSave=0;
      await userRepository.updateUser(user);
      notifyListeners();
    }
    else{
      user.autoSave=1;
      await userRepository.updateUser(user);
      notifyListeners();
    }
  }
  Future<void> setFontPreference(bool useCasual) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCasualFont', useCasual);
    // Update the home widget after changing the font preference
    await HomeWidget.saveWidgetData('useCasualFont', useCasual);
    await HomeWidget.updateWidget(name: 'Note');
  }
  changeFont() async {
    if(user.casual==1){
      user.casual=0;
      await userRepository.updateUser(user);
      setFontPreference(false);
      notifyListeners();
    }
    else{
      user.casual=1;
      await userRepository.updateUser(user);
      setFontPreference(true);
      notifyListeners();
    }
  }

  changeCount() async {
    if(user.count==1){
      user.count=0;
      await userRepository.updateUser(user);
      notifyListeners();
    }
    else{
      user.count=1;
      await userRepository.updateUser(user);
      notifyListeners();
    }
  }

  changeVerse() async {
    if(user.verse==1){
      user.verse=0;
      await userRepository.updateUser(user);
      notifyListeners();
    }
    else{
      user.verse=1;
      await userRepository.updateUser(user);
      notifyListeners();
    }
  }

  increaseFinished() async {
    user.finished++;
    if(user.unFinished>0){
      user.unFinished--;
    }
    await userRepository.updateUser(user);
    notifyListeners();
  }

  increaseUnFinished() async {
    user.unFinished++;
    await userRepository.updateUser(user);
    notifyListeners();
  }

  decreaseFinished() async {
    user.unFinished++;
    if(user.finished>0){
      user.finished--;
    }
    await userRepository.updateUser(user);
    notifyListeners();
  }

  resetPlot() async {
    user.unFinished=0;
    user.finished=0;
    await userRepository.updateUser(user);
    notifyListeners();
  }

  changeLock() async {
    final bool auth=await AuthenticationService().authenticate();
    if(auth){
      if(isEnabled){
        await LockManager().disableLock().then((e){
          isEnabled=false;
        });
        notifyListeners();
      }
      else{
        await LockManager().enableLock().then((e){
          isEnabled=true;
        });
        notifyListeners();
      }
    }
    else{
      Fluttertoast.showToast(
          msg: "Authentication Failed",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 19.0);
    }
  }
  setNotesTextSize()async{
    if(tempNotesTextSize>=0.25&&tempNotesTextSize<=2){
      user.notesTextSize=double.parse(tempNotesTextSize.toStringAsPrecision(2));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widgetTextSize', (user.notesTextSize).toStringAsFixed(2));
      await HomeWidget.saveWidgetData('widgetTextSize', (user.notesTextSize).toStringAsFixed(2));
      await HomeWidget.updateWidget(name: 'Note');
      await userRepository.updateUser(user);
      notifyListeners();
    }
    else{
      Fluttertoast.showToast(
          msg: "Enter Valid Value",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 19.0);
    }
  }

  setTempNotesSize(double size){
    if(size>=0.25&&size<=2){
      tempNotesTextSize=size;
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