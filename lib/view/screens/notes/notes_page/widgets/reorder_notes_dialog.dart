import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/notes_view_model.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../models/note.dart';
import '../../../profile/profile_page/widgets/profile_button.dart';
import '../../../profile/profile_page/widgets/settings_group.dart';
import '../../../tasks/todo_page/widgets/form_dialog.dart';

/// Puts the notes in a new order, by dragging their titles up and down a
/// list on the same surface as the dialogs' settings.
class ReorderNotesDialog extends StatelessWidget {
  const ReorderNotesDialog({
    super.key,
  });

  static const _shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<NotesViewModel>();
    final count = notes.notes.length;
    // The rows, filled like the settings around them, and opaque, so a row
    // picked up still reads over the others.
    final surface = Color.alphaBlend(context.colors.wB.withValues(alpha: 0.06),
        context.colors.cardBackground);
    return FormDialog(
      icon: Icons.swap_vert_rounded,
      title: "Reorder Notes",
      subtitle: count < 2
          ? "Once there are a few notes, put them in order here."
          : "Drag a note to where it belongs.",
      content: [
        if (count == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "No Notes",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.wB.withValues(alpha: 0.45),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          ConstrainedBox(
            // Scrolls once there are more notes than fit comfortably.
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45),
            child: Material(
              color: surface,
              shape: _shape,
              clipBehavior: Clip.antiAlias,
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: count,
                onReorderStart: (_) => HapticFeedback.mediumImpact(),
                onReorderItem: notes.syncAfterReorder,
                // The row being dragged is drawn again, without the hairline
                // that parts it from the row above.
                proxyDecorator: (child, index, animation) => _LiftedRow(
                  animation: animation,
                  color: surface,
                  child: _NoteRow(
                      note: notes.notes[index], index: index, divided: false),
                ),
                itemBuilder: (context, index) {
                  final note = notes.notes[index];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(note.id),
                    index: index,
                    child:
                        _NoteRow(note: note, index: index, divided: index > 0),
                  );
                },
              ),
            ),
          ),
      ],
      actions: [
        ProfileButton(label: "Done", onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

/// A note in the list: a swatch of its cover, its title, and a handle that
/// picks it up straight away, where a long press anywhere else on the row
/// does too.
class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.index,
    required this.divided,
  });

  final Note note;
  final int index;

  /// Whether a hairline parts it from the row above.
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (divided)
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: SettingsTile.textInset,
            color: ink.withValues(alpha: 0.1),
          ),
        SizedBox(
          height: 54,
          child: Row(
            children: [
              const SizedBox(width: 16),
              _CoverSwatch(note: note),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    size: 22,
                    color: ink.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A note's cover in miniature, the size of the settings' icons: its
/// colour, with an icon in its title's colour, or a lock when it's locked.
class _CoverSwatch extends StatelessWidget {
  const _CoverSwatch({required this.note});

  static const _size = 30.0;

  final Note note;

  @override
  Widget build(BuildContext context) {
    final cover = note.coverColor.toColor;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          side: BorderSide(
            width: 0.5,
            color: context.colors.wB.withValues(alpha: 0.12),
          ),
        ),
        // A faint sheen from the top, as on the settings' icons.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(cover, Colors.white, 0.14)!, cover],
        ),
      ),
      child: SizedBox.square(
        dimension: _size,
        child: Icon(
          note.protected == 1 ? Icons.lock_rounded : Icons.notes_rounded,
          size: _size * 0.56,
          color: note.titleColor.toColor,
        ),
      ),
    );
  }
}

/// A row picked up to be reordered: it grows a little and casts a shadow,
/// then settles back as it's dropped.
class _LiftedRow extends StatelessWidget {
  const _LiftedRow({
    required this.animation,
    required this.color,
    required this.child,
  });

  final Animation<double> animation;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final lift = Curves.easeOutCubic.transform(animation.value);
        return Transform.scale(
          scale: 1 + 0.03 * lift,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: ReorderNotesDialog._shape,
              shadows: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: (isDarkTheme ? 0.5 : 0.18) * lift),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      // A Material of its own, as it's drawn above the dialog's.
      child: Material(
        color: color,
        shape: ReorderNotesDialog._shape,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
