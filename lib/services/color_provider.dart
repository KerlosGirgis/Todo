import 'package:flutter/material.dart';

class ColorProvider {
  int theme;
  Color? floatingActionButtonBackground;
  Color? floatingActionButtonForeground;
  Color? taskTitle;
  Color? date;
  Color? appTitle;
  Color? cardBackground;
  Color? subtitle;
  Color? pageBackground;
  Color? userNameAlert;
  Color? profileAlertBackground;
  Color? alertButtonsBackground;
  Color? profilePageButtonsBackground;
  Color? profilePageName;
  Color? addTaskAlertText;
  Color? addTaskAlertBackground;
  Color? editPicButtonBackground;
  Color? profilePageText;
  Color? homePageText;
  Color? noteEditorBackButton;
  Color? noteEditorText;
  Color? noteEditorButtons;
  Color? appBarIcons;
  Color? moreLess;

  ColorProvider(this.theme) {
    if (theme == 1) {
      floatingActionButtonBackground = const Color.fromARGB(255, 64, 64, 64);
      floatingActionButtonForeground = Colors.grey.shade300;
      taskTitle = Colors.white;
      date = Colors.white;
      appTitle = Colors.white;
      subtitle = Colors.grey.shade200;
      pageBackground = const Color(0xff121212);
      userNameAlert = Colors.white;
      profileAlertBackground = Colors.grey.shade800.withValues(alpha: .8);
      cardBackground = const Color(0xff1E1E1E);
      alertButtonsBackground = Colors.black;
      profilePageButtonsBackground = Colors.grey[50];
      profilePageName = Colors.blue[100];
      addTaskAlertText = Colors.black;
      addTaskAlertBackground = const Color(0xffF8F9FF);
      editPicButtonBackground = Colors.white;
      profilePageName = Colors.blue[100];
      profilePageText = Colors.white;
      homePageText = Colors.white;
      noteEditorBackButton= Colors.white;
      noteEditorText=Colors.white;
      noteEditorButtons=Colors.white;
      appBarIcons=Colors.grey;
      moreLess = const Color(0xff90CAF9);

    } else {
      floatingActionButtonBackground = Color(0xff3D5AFE);
      floatingActionButtonForeground = Colors.white;
      taskTitle = Colors.black;
      date = Colors.black;
      appTitle = Colors.black;
      subtitle = Colors.grey.shade800;
      pageBackground = Color(0xffEDEDED);
      userNameAlert = Colors.white;
      profileAlertBackground = Colors.grey;
      cardBackground = const Color(0xffF5F5F5);
      alertButtonsBackground = Colors.white;
      profilePageButtonsBackground = Colors.white;
      profilePageName = Colors.blue;
      addTaskAlertText = Colors.black;
      addTaskAlertBackground = const Color(0xffF8F9FF);
      editPicButtonBackground = Colors.white;
      profilePageName = Colors.blue;
      profilePageText = Colors.black;
      homePageText = Colors.black;
      noteEditorBackButton= Colors.black;
      noteEditorText=Colors.black;
      noteEditorButtons=Colors.black;
      appBarIcons=const Color(0xff616161);
      moreLess = const Color(0xff3D5AFE);
    }
  }
}
