
import 'package:flutter/material.dart';

class ColorProvider{
  int theme;
   Color? taskTitle;
   Color? appTitle;
   Color? cardBackground;
   Color? subtitle;
   Color? dateAndTime;
   Color? homePageBackground;
   Color? profilePageBackground;
   Color? userNameAlert;
   Color? profileAlertBackground;
   Color? alertButtonsBackground;
   Color? profilePageButtonsBackground;
   Color? profilePageName;
   Color? addTaskAlertText;
   Color? editTaskAlertBackground;
   Color? addTaskAlertBackground;
   Color? appBarBackground;
   Color? editPicButtonBackground;
   Color? profilePageText;




  ColorProvider(this.theme){
    if(theme==1){
      taskTitle = Colors.black;
      appTitle = Colors.white;
      subtitle = Colors.grey;
      dateAndTime = Colors.white;
      homePageBackground = Colors.black12;
      profilePageBackground = Colors.black12;
      userNameAlert = Colors.white;
      profileAlertBackground =Colors.grey.withOpacity(.7);
      cardBackground = Colors.white.withOpacity(.9);
      alertButtonsBackground = Colors.black;
      profilePageButtonsBackground = Colors.grey[400];
      profilePageName = Colors.blue[100];
      addTaskAlertText= Colors.black;
      editTaskAlertBackground=Colors.grey;
      addTaskAlertBackground=Colors.grey;
      appBarBackground=Colors.black12;
      editPicButtonBackground=Colors.grey;
      profilePageName = Colors.blue[100];
      profilePageText = Colors.white;

    }
    else{
      taskTitle = Colors.black;
      appTitle = Colors.black;
      subtitle = Colors.black;
      dateAndTime = Colors.black;
      homePageBackground = Colors.white;
      profilePageBackground = Colors.white;
      userNameAlert = Colors.white;
      profileAlertBackground =Colors.grey.withOpacity(.7);
      cardBackground = Colors.blue[50];
      alertButtonsBackground = Colors.white;
      profilePageButtonsBackground = Colors.white;
      profilePageName = Colors.blue;
      addTaskAlertText= Colors.black;
      editTaskAlertBackground=Colors.white;
      addTaskAlertBackground=Colors.white;
      appBarBackground=Colors.white;
      editPicButtonBackground=Colors.white;
      profilePageName = Colors.blue;
      profilePageText = Colors.black;

    }

  }




}