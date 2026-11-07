import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData getTheme(
      {required bool isDarkMode, bool isAmoled = false}) {
    final amoled = isDarkMode && isAmoled;
    return ThemeData(
      scaffoldBackgroundColor: amoled ? Colors.black : null,
      fontFamily: 'arial',
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue.shade300,
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        surface: amoled ? Colors.black : null,
      ),
      extensions: [
        amoled
            ? AppColors.amoled
            : isDarkMode
                ? AppColors.dark
                : AppColors.light,
      ],
      useMaterial3: true,
    );
  }
}
