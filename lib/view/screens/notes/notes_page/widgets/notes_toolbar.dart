import 'package:flutter/material.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../widgets/glass.dart';

/// The floating glass toolbar at the bottom of the notes page, as in Apple
/// Notes: the to-do list on the left, the note count, and compose.
class NotesToolbar extends StatelessWidget {
  const NotesToolbar({
    super.key,
    required this.count,
    required this.onTodo,
    required this.onCompose,
  });

  static const height = 56.0;

  final int count;
  final VoidCallback onTodo;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final accent = context.colors.moreLess;
    final buttonStyle = IconButton.styleFrom(
      foregroundColor: accent,
      highlightColor: accent.withValues(alpha: 0.14),
      splashFactory: NoSplash.splashFactory,
      minimumSize: const Size.square(44),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16 + padding.left, 0, 16 + padding.right, 12 + padding.bottom),
      // Stays a comfortable width on landscape and tablet screens.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: 560, minHeight: height, maxHeight: height),
          child: Glass(
            child: Row(
              children: [
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onTodo,
                  tooltip: "To-Do",
                  style: buttonStyle,
                  icon: const Icon(Icons.checklist_rounded),
                ),
                Expanded(
                  child: Text(
                    // Blank with no notes, since the empty state says so.
                    switch (count) {
                      0 => "",
                      1 => "1 Note",
                      _ => "$count Notes",
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.wB.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onCompose,
                  tooltip: "New Note",
                  style: buttonStyle,
                  icon: const Icon(Icons.edit_square),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
