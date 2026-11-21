import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/view/widgets/themed_status_bar.dart';

void main() {
  for (final (dark, icons) in [
    (false, Brightness.dark),
    (true, Brightness.light),
  ]) {
    testWidgets(
      "the status bar's icons read on a ${dark ? "dark" : "light"} page",
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: dark),
            home: const ThemedStatusBar(child: SizedBox()),
          ),
        );
        final style = tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.descendant(
                of: find.byType(ThemedStatusBar),
                matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
              ),
            )
            .value;
        expect(style.statusBarIconBrightness, icons);
        expect(style.statusBarColor, Colors.transparent);
      },
    );
  }
}
