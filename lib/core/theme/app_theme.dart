import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData getTheme({required bool isDarkMode}) {
    return ThemeData(
      fontFamily: 'arial',
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue.shade300,
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
      extensions: [
        isDarkMode ? AppColors.dark : AppColors.light,
      ],
      useMaterial3: true,
    );
  }
}