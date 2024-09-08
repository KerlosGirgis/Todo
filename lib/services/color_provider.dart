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
  Color? editTaskAlertBackground;
  Color? addTaskAlertBackground;
  Color? editPicButtonBackground;
  Color? profilePageText;
  Color? homePageText;
  Color? noteEditorBackButton;
  Color? noteEditorText;
  Color? noteEditorButtons;

  ColorProvider(this.theme) {
    if (theme == 1) {
      floatingActionButtonBackground = const Color.fromARGB(255, 64, 64, 64);
      floatingActionButtonForeground = Colors.grey.shade300;
      taskTitle = Colors.white;
      date = Colors.white;
      appTitle = Colors.white;
      subtitle = Colors.grey.shade200;
      pageBackground = const Color.fromARGB(255, 24, 24, 24);
      userNameAlert = Colors.white;
      profileAlertBackground = Colors.grey.shade800.withOpacity(.8);
      cardBackground = Colors.grey.shade700.withOpacity(.5);
      alertButtonsBackground = Colors.black;
      profilePageButtonsBackground = Colors.grey[50];
      profilePageName = Colors.blue[100];
      addTaskAlertText = Colors.black;
      editTaskAlertBackground = Colors.grey;
      addTaskAlertBackground = Colors.grey;
      editPicButtonBackground = Colors.white;
      profilePageName = Colors.blue[100];
      profilePageText = Colors.white;
      homePageText = Colors.white;
      noteEditorBackButton= Colors.white;
      noteEditorText=Colors.white;
      noteEditorButtons=Colors.white;



    } else {
      floatingActionButtonBackground = Colors.blue.shade300;
      floatingActionButtonForeground = Colors.white;
      taskTitle = Colors.black;
      date = Colors.black;
      appTitle = Colors.black;
      subtitle = Colors.grey.shade800;
      pageBackground = Colors.white;
      userNameAlert = Colors.white;
      profileAlertBackground = Colors.grey;
      cardBackground = Colors.blue.shade200;
      alertButtonsBackground = Colors.white;
      profilePageButtonsBackground = Colors.white;
      profilePageName = Colors.blue;
      addTaskAlertText = Colors.black;
      editTaskAlertBackground = Colors.white;
      addTaskAlertBackground = Colors.white;
      editPicButtonBackground = Colors.white;
      profilePageName = Colors.blue;
      profilePageText = Colors.black;
      homePageText = Colors.black;
      noteEditorBackButton= Colors.black;
      noteEditorText=Colors.black;
      noteEditorButtons=Colors.black;
    }
  }
}
