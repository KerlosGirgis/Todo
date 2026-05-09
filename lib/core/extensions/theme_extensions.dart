import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

extension ThemeContextExtension on BuildContext {
  AppColors get colors => AppColors.of(this);
}