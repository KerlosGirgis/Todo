import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../models/note.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../models/trashed.dart';
import '../../../../widgets/check_circle.dart';
import '../../../notes/notes_page/widgets/note_card.dart';
import '../../../tasks/todo_page/widgets/task_card.dart';

/// iOS's system red, a touch brighter on dark pages, as there.
Color _systemRed(bool isDarkTheme) =>
    isDarkTheme ? const Color(0xffFF453A) : const Color(0xffFF3B30);

/// A task in the trash: its check and title as its card had them, the start
/// of its description, when it was deleted, and buttons that put it back or
/// delete it for good.
class TrashTaskCard extends StatelessWidget {
  const TrashTaskCard({
    super.key,
    required this.entry,
    required this.onRestore,
    required this.onDelete,
  });

  final Trashed<TodoItem> entry;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final task = entry.item;
    return _TrashCard(
      leading: CheckCircle(doneness: task.done ? 1 : 0),
      title: task.title,
      done: task.done,
      detail: task.desc.isEmpty ? null : Text(_firstLine(task.desc)),
      deletedAt: entry.deletedAt,
      onRestore: onRestore,
      onDelete: onDelete,
    );
  }
}

/// A note in the trash: a swatch of its cover, its title, the start of its
/// text, or that it's locked, when it was deleted, and buttons that put it
/// back or delete it for good.
class TrashNoteCard extends StatelessWidget {
  const TrashNoteCard({
    super.key,
    required this.entry,
    required this.onRestore,
    required this.onDelete,
  });

  /// The note's entry, without its text while it's locked.
  final Trashed<Note> entry;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final note = entry.item;
    final text = _firstLine(note.body);
    return _TrashCard(
      leading: NoteCoverSwatch(note: note),
      title: note.title,
      detail: note.locked
          ? const Row(
              children: [
                Icon(Icons.lock_rounded, size: 14),
                SizedBox(width: 4),
                Text("Locked"),
              ],
            )
          : text.isEmpty
              ? null
              : Text(text),
      deletedAt: entry.deletedAt,
      onRestore: onRestore,
      onDelete: onDelete,
    );
  }
}

/// The first line of [text] with anything in it, trimmed.
String _firstLine(String text) =>
    text.split("\n").map((line) => line.trim()).firstWhere(
          (line) => line.isNotEmpty,
          orElse: () => "",
        );

/// When something was deleted, as of [now]: "Deleted today at 9:30 PM",
/// "Deleted yesterday", "Deleted 3 days ago", then "Deleted Oct 24", or
/// "Deleted Oct 24, 2025" in another year.
String deletedLabel(DateTime deletedAt, DateTime now) {
  // Counted in UTC, where every day is 24 hours long.
  final days = DateTime.utc(now.year, now.month, now.day)
      .difference(DateTime.utc(deletedAt.year, deletedAt.month, deletedAt.day))
      .inDays;
  return switch (days) {
    <= 0 => "Deleted today at ${DateFormat("h:mm a").format(deletedAt)}",
    1 => "Deleted yesterday",
    < 7 => "Deleted $days days ago",
    _ when deletedAt.year == now.year =>
      "Deleted ${DateFormat("MMM d").format(deletedAt)}",
    _ => "Deleted ${DateFormat("MMM d, y").format(deletedAt)}",
  };
}

/// What the trash's cards share: the to-do page's card surface, with
/// [leading] beside the [title], struck through when [done], the [detail]
/// and when it was deleted under it, and the buttons at the end.
class _TrashCard extends StatelessWidget {
  const _TrashCard({
    required this.leading,
    required this.title,
    this.done = false,
    this.detail,
    required this.deletedAt,
    required this.onRestore,
    required this.onDelete,
  });

  final Widget leading;
  final String title;
  final bool done;
  final Widget? detail;
  final DateTime deletedAt;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final ink = context.colors.wB;
    final detail = this.detail;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: TaskCard.shape,
        // As on the to-do page: a soft shadow on light pages, and the
        // hairline edge alone on dark ones.
        shadows: isDarkTheme
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  spreadRadius: -6,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: isDarkTheme ? context.colors.cardBackground : Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: TaskCard.shape.copyWith(
          side: BorderSide(
            width: 0.5,
            color: ink.withValues(alpha: isDarkTheme ? 0.08 : 0.05),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink.withValues(alpha: done ? 0.38 : 1),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        letterSpacing: -0.3,
                        decoration: done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: ink.withValues(alpha: 0.38),
                        decorationThickness: 1.5,
                      ),
                    ),
                    if (detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: IconTheme.merge(
                          data:
                              IconThemeData(color: ink.withValues(alpha: 0.55)),
                          child: DefaultTextStyle.merge(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink.withValues(alpha: 0.55),
                              fontSize: 14.5,
                              height: 1.3,
                              letterSpacing: -0.1,
                            ),
                            child: detail,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        deletedLabel(deletedAt, DateTime.now()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _RoundButton(
                icon: Icons.restore_from_trash_rounded,
                tooltip: "Restore",
                color: context.colors.moreLess,
                onPressed: onRestore,
              ),
              _RoundButton(
                icon: Icons.delete_forever_rounded,
                tooltip: "Delete Forever",
                color: _systemRed(isDarkTheme),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round button at the end of a card, tinted with its [color], as the
/// to-do page's bell is while its reminder is on.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      child: Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: 44,
          child: InkResponse(
            onTap: () {
              HapticFeedback.selectionClick();
              onPressed();
            },
            radius: 20,
            splashFactory: NoSplash.splashFactory,
            highlightColor: color.withValues(alpha: 0.16),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: isDarkTheme ? 0.18 : 0.12),
                ),
                child: SizedBox.square(
                  dimension: 34,
                  child: Icon(icon, size: 19, color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
