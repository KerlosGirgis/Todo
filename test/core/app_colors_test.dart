import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/core/theme/app_colors.dart';

void main() {
  test('AMOLED black fills dialogs like its cards, and outlines them', () {
    final amoled = AppColors.amoled;
    expect(amoled.dialogBackground, amoled.cardBackground);
    expect(amoled.dialogSide.style, BorderStyle.solid);
    expect(amoled.dialogSide.color, amoled.dialogOutline);
    expect(amoled.sheetSide.color, amoled.dialogOutline);
  });

  test('the other themes draw no outline', () {
    for (final colors in [AppColors.light, AppColors.dark]) {
      expect(colors.dialogSide, BorderSide.none);
      expect(colors.sheetSide.style, BorderStyle.none);
    }
  });

  test("a dialog's outline is inside it, where its clip keeps it, and a "
      "sheet's outside, so its lower edge falls off the screen", () {
    expect(AppColors.amoled.dialogSide.strokeAlign,
        BorderSide.strokeAlignInside);
    expect(AppColors.amoled.sheetSide.strokeAlign,
        BorderSide.strokeAlignOutside);
  });

  test('switching to AMOLED black brings the outline in', () {
    expect(AppColors.dark.lerp(AppColors.amoled, 1).dialogSide,
        AppColors.amoled.dialogSide);
    expect(AppColors.amoled.lerp(AppColors.dark, 1).dialogSide,
        BorderSide.none);
  });
}
