import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Has the status bar's icons read on [child], a page with no app bar to
/// set them: light icons on a dark page and dark ones on a light page, over
/// a clear bar.
class ThemedStatusBar extends StatelessWidget {
  const ThemedStatusBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: child,
    );
  }
}
