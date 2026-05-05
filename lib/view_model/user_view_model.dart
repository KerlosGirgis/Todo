import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/lock_manager.dart';
import 'package:todo/services/user_repository.dart';
import '../core/result.dart';
import '../services/color_manager.dart';

class UserViewModel with ChangeNotifier {
  UserProfile user = UserProfile(name: "user", pic: "000", theme: 1,autoSave: 1, casual: 0, verse: 1, count: 0, finished: 0, unFinished: 0, notesTextSize: 1,startPage: 0, descLines: 2, tasksTitleSize: 1, tasksDescSize: 1, notesTitleSize: 1);

  ColorManager colorManager =ColorManager(isDark: true);

  late bool isEnabled;
  late double tempNotesTextSize;
  late double tempTasksTitleSize;
  late double tempTasksDescSize;
  late double tempNotesTitleSize;


  UserRepository userRepository = UserRepository();

  Future<void> get() async {
    List users;
    users = await userRepository.getUser();
    if(users.isEmpty){
      userRepository.insertUser(user);
      users = await userRepository.getUser();
      user = users.first;
      colorManager =ColorManager(isDark: true);
    }
    else{
      user = users.first;
      colorManager =ColorManager(isDark: user.theme==1?true:false);
    }
    isEnabled=await LockManager().isLockEnabled();
    tempNotesTextSize=user.notesTextSize;
    tempTasksTitleSize=user.tasksTitleSize;
    tempTasksDescSize=user.tasksDescSize;
    tempNotesTitleSize=user.notesTitleSize;
    notifyListeners();
  }

  Future<void> editName(String name) async {
    user.name = name;
    await userRepository.updateUser(user);
    notifyListeners();
  }

  Future<void> editPic(String pic) async {
    user.pic = pic;
    await userRepository.updateUser(user);
    notifyListeners();
  }

  Future<void> changeTheme() async {
    if(user.theme==1){
      user.theme=0;
      colorManager =ColorManager(isDark: false);
      await userRepository.updateUser(user);
      notifyListeners();
    }
    else{
      user.theme=1;
      colorManager =ColorManager(isDark: true);
      await userRepository.updateUser(user);
      notifyListeners();
    }
  }
  Future<void> changeAutoSave() async {
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
  Future<void> changeStartPage(int startPage) async {
      user.startPage=startPage;
      await userRepository.updateUser(user);
      notifyListeners();
  }
  Future<void> setFontPreference(bool useCasual) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCasualFont', useCasual);
    // Update the home widget after changing the font preference
    await HomeWidget.saveWidgetData('useCasualFont', useCasual);
    await HomeWidget.updateWidget(name: 'Note');
  }
  Future<void> changeFont() async {
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

  Future<void> changeCount() async {
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

  Future<void> changeVerse() async {
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

  Future<void> increaseFinished() async {
    user.finished++;
    if(user.unFinished>0){
      user.unFinished--;
    }
    await userRepository.updateUser(user);
    notifyListeners();
  }

  Future<void> increaseUnFinished() async {
    user.unFinished++;
    await userRepository.updateUser(user);
    notifyListeners();
  }

  Future<void> decreaseFinished() async {
    user.unFinished++;
    if(user.finished>0){
      user.finished--;
    }
    await userRepository.updateUser(user);
    notifyListeners();
  }

  Future<void> resetPlot() async {
    user.unFinished=0;
    user.finished=0;
    await userRepository.updateUser(user);
    notifyListeners();
  }

  Future<Result> changeLock() async {
    final bool auth=await AuthenticationService().authenticate();
    if(auth){
      if(isEnabled){
        await LockManager().disableLock();
        isEnabled=false;
        notifyListeners();
        return Info("Lock Disabled");
      }
      else{
        await LockManager().enableLock();
        isEnabled=true;
        notifyListeners();
        return Success("Lock Enabled");
      }
    }
    else{
      return Failure("Authentication Failed");
    }
  }
  Future<Result> setNotesTextSize()async{
    if(tempNotesTextSize>=0.25&&tempNotesTextSize<=2){
      user.notesTextSize=tempNotesTextSize;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widgetTextSize', (user.notesTextSize).toStringAsFixed(2));
      await HomeWidget.saveWidgetData('widgetTextSize', (user.notesTextSize).toStringAsFixed(2));
      await HomeWidget.updateWidget(name: 'Note');
      await userRepository.updateUser(user);
      notifyListeners();
      return Success("Font Changed");
    }
    else{
      return Failure("Enter Valid Value");
    }
  }

  Future<Result> setNotesTitleSize()async{
    if(tempNotesTitleSize>=0.25&&tempNotesTitleSize<=2){
      user.notesTitleSize=tempNotesTitleSize;
      await userRepository.updateUser(user);
      notifyListeners();
      return Success("Font Changed");
    }
    else{
      return Failure("Enter Valid Value");
    }
  }

  Future<Result> setTasksTitleSize()async{
    if(tempTasksTitleSize>=0.25&&tempTasksTitleSize<=2){
      user.tasksTitleSize=tempTasksTitleSize;
      await userRepository.updateUser(user);
      notifyListeners();
      return Success("Font Changed");
    }
    else{
      return Failure("Enter Valid Value");
    }
  }

  Future<Result> setTasksDescSize()async{
    if(tempTasksDescSize>=0.25&&tempTasksDescSize<=2){
      user.tasksDescSize=tempTasksDescSize;
      await userRepository.updateUser(user);
      notifyListeners();
      return Success("Font Changed");
    }
    else{
      return Failure("Enter Valid Value");
    }
  }

  void setTempNotesSize(double size){
    if(size>=0.25&&size<=2){
      tempNotesTextSize=size;
      notifyListeners();
    }
  }

  void setTempNotesTitleSize(double size){
    if(size>=0.25&&size<=2){
      tempNotesTitleSize=size;
      notifyListeners();
    }
  }

  void setTempTasksTitleSize(double size){
    if(size>=0.25&&size<=2){
      tempTasksTitleSize=size;
      notifyListeners();
    }
  }

  void setTempTasksDescSize(double size){
    if(size>=0.25&&size<=2){
      tempTasksDescSize=size;
      notifyListeners();
    }
  }


  Future<File?>? _pickImage() async {
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

  Future<File?> cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarColor: Colors.black,
          statusBarLight: false,
          backgroundColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: Color(0xff3D5AFE),
          initAspectRatio: CropAspectRatioPreset.original,
          cropStyle: CropStyle.circle,
          lockAspectRatio: false,
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }

  Future<File> _saveImageToAppStorage(File image) async {
    final appDir = await getApplicationDocumentsDirectory();

    final fileName = image.path.split('/').last;
    final oldFile = File(user.pic);
    if (await oldFile.exists()) {
      await oldFile.delete();
    }
    final savedImage = await image.copy('${appDir.path}/$fileName');

    return savedImage;
  }

  Future<void> pickAndSaveImage() async {
    final image = await _pickImage();
    if (image != null) {
      final croppedImage = await cropImage(image);
      if (croppedImage != null) {
        final savedImage = await _saveImageToAppStorage(croppedImage);
        editPic(savedImage.path);
      }
    }
  }

  Future<void> setDescLines(int numOfLines) async {
    if(numOfLines>=0&&numOfLines<10){
      user.descLines=numOfLines;
      await userRepository.updateUser(user);
      notifyListeners();
    }
  }

}