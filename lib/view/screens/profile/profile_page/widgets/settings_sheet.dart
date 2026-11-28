import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';

/// Opens [sheet] from the bottom of the screen, as the settings' sheets
/// open: under a drag handle, on the dialogs' colour with its top corners
/// rounded, and as tall as it needs, short of the status bar.
Future<T?> showSettingsSheet<T>(BuildContext context, Widget sheet) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colors.dialogBackground,
    shape: RoundedSuperellipseBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      side: context.colors.sheetSide,
    ),
    builder: (context) => sheet,
  );
}
