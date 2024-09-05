import 'package:flutter/material.dart';
import 'package:todo/services/color_provider.dart';


class ThemeProvider with ChangeNotifier {
  ColorProvider colorProvider =ColorProvider(1);

  changeTheme(){
    if(colorProvider.theme==1){
      colorProvider=ColorProvider(0);
      notifyListeners();
    }
    else{
      colorProvider=ColorProvider(1);
      notifyListeners();
    }
  }


}