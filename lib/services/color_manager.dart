import 'package:flutter/material.dart';

class ColorManager{
  Color? floatingActionButtonBackground;
  Color? floatingActionButtonForeground;
  Color? wB;
  Color? cardBackground;
  Color? subtitle;
  Color? pageBackground;
  Color? profileAlertBackground;
  Color? profilePageName;
  Color? appBarIcons;
  Color? moreLess;
  Color? dialogIconContainer;
  Color? dialogIcon;
  Color? dialogExitIcon;
  Color? dialogExitContainer;
  bool isDark;

  ColorManager({required this.isDark}){
    isDark?_setDarkTheme():_setLightTheme();
  }
  void _setDarkTheme(){
    floatingActionButtonBackground = const Color.fromARGB(255, 64, 64, 64);
    floatingActionButtonForeground = Colors.grey.shade300;
    wB = Colors.white;
    subtitle = Colors.grey.shade200;
    pageBackground = const Color(0xff121212);
    profileAlertBackground = Colors.grey.shade800.withValues(alpha: .8);
    cardBackground = const Color(0xff1E1E1E);
    profilePageName = Colors.blue[100];
    appBarIcons=Colors.grey;
    moreLess = const Color(0xff90CAF9);
    dialogIcon = Colors.white;
    dialogIconContainer = Color.fromARGB(255, 64, 64, 64);
    dialogExitIcon = Colors.white;
    dialogExitContainer = Color.fromARGB(255, 64, 64, 64);
  }
  void _setLightTheme(){
      floatingActionButtonBackground = Color(0xff3D5AFE);
      floatingActionButtonForeground = Colors.white;
      wB = Colors.black;
      subtitle = Colors.grey.shade800;
      pageBackground = Color(0xffEDEDED);
      profileAlertBackground = Colors.grey;
      cardBackground = const Color(0xffF5F5F5);
      profilePageName = Colors.blue;
      appBarIcons=const Color(0xff616161);
      moreLess = const Color(0xff3D5AFE);
      dialogIcon = Color(0xff3D5AFE);
      dialogIconContainer = const Color(0xffd8defb);
      dialogExitIcon = Colors.grey.shade800;
      dialogExitContainer = Colors.grey.shade300;
  }
}