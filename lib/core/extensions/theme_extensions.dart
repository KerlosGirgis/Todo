import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

extension ThemeContextExtension on BuildContext {
  AppColors get colors => AppColors.of(this);
}