import 'package:flutter/material.dart';

import '../../../../../core/extensions/theme_extensions.dart';

/// The "⋯" button that opens an iOS-style pull-down menu of the notes'
/// actions.
class NotesMenuButton extends StatelessWidget {
  const NotesMenuButton({
    super.key,
    required this.onReorder,
    required this.onBackup,
    required this.onRestore,
    required this.onSettings,
  });

  final VoidCallback onReorder;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onSettings;

  static const _menuWidth = 236.0;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.moreLess;
    final hairline = Divider(
      height: 0.5,
      thickness: 0.5,
      color: context.colors.wB.withValues(alpha: 0.12),
    );
    MenuItemButton item(String label, IconData icon, VoidCallback onPressed) {
      return MenuItemButton(
        onPressed: onPressed,
        trailingIcon: Icon(icon, size: 20),
        style: MenuItemButton.styleFrom(
          foregroundColor: context.colors.wB,
          iconColor: context.colors.wB,
          overlayColor: context.colors.wB,
          splashFactory: NoSplash.splashFactory,
          // From the theme, since a button's text style replaces the
          // inherited one rather than merging with it.
          textStyle: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontSize: 16, letterSpacing: -0.2),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(_menuWidth, 46),
        ),
        child: Text(label),
      );
    }

    return MenuAnchor(
      // Hangs from the button's bottom corner with their trailing edges
      // aligned, as iOS menus do, instead of being pushed against the edge.
      alignmentOffset: const Offset(-_menuWidth, 6),
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        backgroundColor: WidgetStatePropertyAll(context.colors.cardBackground),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(12),
        shadowColor:
            WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.5)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: const WidgetStatePropertyAll(
          RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
      ),
      menuChildren: [
        item("Reorder Notes", Icons.reorder_rounded, onReorder),
        hairline,
        item("Back Up Notes", Icons.backup_outlined, onBackup),
        hairline,
        item(
            "Restore Backup", Icons.settings_backup_restore_rounded, onRestore),
        // A thicker gap separates the settings from the notes' own actions.
        ColoredBox(
          color: context.colors.wB.withValues(alpha: 0.06),
          child: const SizedBox(height: 8),
        ),
        item("Settings", Icons.settings_outlined, onSettings),
      ],
      builder: (context, controller, child) {
        return Material(
          color: accent.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            splashFactory: NoSplash.splashFactory,
            highlightColor: accent.withValues(alpha: 0.2),
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: Tooltip(
              message: "More",
              child: SizedBox.square(
                dimension: 34,
                child: Icon(Icons.more_horiz_rounded, size: 22, color: accent),
              ),
            ),
          ),
        );
      },
    );
  }
}
