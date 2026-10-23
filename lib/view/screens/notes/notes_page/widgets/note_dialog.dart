import 'dart:math' as math;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/note.dart';
import '../../../../../view_model/notes_view_model.dart';
import '../../../profile/profile_page/widgets/profile_button.dart';
import '../../../profile/profile_page/widgets/settings_group.dart';
import '../../../tasks/todo_page/widgets/form_dialog.dart';
import 'note_card.dart';

const _accent = Color(0xff3D5AFE);

// iOS's system colours, as on the profile page's settings.
const _pink = Color(0xffFF2D55);
const _indigo = Color(0xff5856D6);
const _green = Color(0xff34C759);

/// A new note's colours: a white title on graphite.
const _graphite = Color(0xff1E1E1E);
const _white = Color(0xffFFFFFF);

/// The colours on offer for a note's cover and title: iOS's system colours,
/// with the app's own blue among them, after graphite and white.
const _palette = <(String, Color)>[
  ("Graphite", _graphite),
  ("White", _white),
  ("Red", Color(0xffFF3B30)),
  ("Orange", Color(0xffFF9500)),
  ("Yellow", Color(0xffFFCC00)),
  ("Green", _green),
  ("Teal", Color(0xff30B0C7)),
  ("Blue", _accent),
  ("Indigo", _indigo),
  ("Purple", Color(0xffAF52DE)),
  ("Pink", _pink),
];

/// One of the note's two colours.
enum _ColorTarget { cover, title }

/// Adds a note, or edits [note] when there is one, as the task dialog does:
/// its title, then its colours and lock in rows like the profile page's
/// settings. A colour's row opens the palette under it.
class NoteDialog extends StatefulWidget {
  const NoteDialog({super.key, this.note});

  /// The note to edit, or null for a new one.
  final Note? note;

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late final _titleController = TextEditingController(text: widget.note?.title);
  late Color _cover = widget.note?.coverColor.toColor ?? _graphite;
  late Color _titleColor = widget.note?.titleColor.toColor ?? _white;
  late bool _locked = widget.note?.protected == 1;

  /// The colour whose palette is open under its row, if either's is.
  _ColorTarget? _picking;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _togglePalette(_ColorTarget target) {
    // The keyboard would cover the palette.
    FocusScope.of(context).unfocus();
    setState(() => _picking = _picking == target ? null : target);
  }

  void _setColor(_ColorTarget target, Color color) {
    setState(() {
      switch (target) {
        case _ColorTarget.cover:
          _cover = color;
          // A plain title follows the cover, so it stays readable; a
          // colourful one was picked on purpose, and stays.
          if (_isPlain(_titleColor)) {
            _titleColor =
                onCoverColor(color) == Colors.white ? _white : _graphite;
          }
        case _ColorTarget.title:
          _titleColor = color;
      }
    });
  }

  Future<void> _pickCustomColor(_ColorTarget target) async {
    final current = target == _ColorTarget.cover ? _cover : _titleColor;
    final picked = await showColorPickerDialog(
      context,
      current,
      pickersEnabled: const {
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: false,
        ColorPickerType.bw: false,
        ColorPickerType.custom: false,
        ColorPickerType.customSecondary: false,
        ColorPickerType.wheel: true,
      },
      // Round, like the palette's swatches, and ringed, so a shade as dark
      // as the dialog still shows.
      width: 38,
      height: 38,
      borderRadius: 19,
      hasBorder: true,
      borderColor: context.colors.wB.withValues(alpha: 0.14),
      spacing: 6,
      runSpacing: 6,
      wheelDiameter: 220,
      heading: Text(
        target == _ColorTarget.cover ? "Cover Color" : "Title Color",
        style: TextStyle(
          color: context.colors.wB,
          fontSize: 21,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.4,
        ),
      ),
      subheading: const _PickerSubheading("Shades"),
      wheelSubheading: const _PickerSubheading("Shades"),
      selectedPickerTypeColor: _accent,
      backgroundColor: context.colors.cardBackground,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      barrierColor: Colors.black54,
      actionButtons: ColorPickerActionButtons(
        dialogOkButtonLabel: "Choose",
        dialogOkButtonStyle:
            TextButton.styleFrom(foregroundColor: context.colors.moreLess),
        dialogCancelButtonStyle:
            TextButton.styleFrom(foregroundColor: context.colors.moreLess),
      ),
      // Fades and grows in, like the dialog it opens from.
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
    // A cancelled picker hands back the colour it started with.
    if (mounted && picked != current) _setColor(target, picked);
  }

  Future<void> _toggleLock() async {
    if (_locked) {
      setState(() => _locked = false);
      return;
    }
    final result = await context.read<NotesViewModel>().confirmLock();
    if (!mounted) return;
    result.when(
      onSuccess: (_) => setState(() => _locked = true),
      onFailure: FeedbackToast.error,
      onInfo: FeedbackToast.info,
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final notes = context.read<NotesViewModel>();
    Navigator.of(context).pop();
    final note = widget.note;
    final saved = Note(
      id: note?.id,
      title: title,
      body: note?.body ?? "",
      titleColor: _titleColor.hex,
      coverColor: _cover.hex,
      protected: _locked ? 1 : 0,
    );
    if (note == null) {
      await notes.addNote(saved);
      FeedbackToast.info("Note Added");
    } else {
      await notes.updateNote(saved);
      FeedbackToast.info("Note Updated");
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final adding = widget.note == null;
    return FormDialog(
      icon: adding ? Icons.note_add_rounded : Icons.edit_rounded,
      title: adding ? "New Note" : "Edit Note",
      subtitle:
          adding ? "What's this note about?" : "Change its details, then save.",
      content: [
        TextField(
          controller: _titleController,
          // Ready to type straight away when adding.
          autofocus: adding,
          maxLines: 1,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          cursorColor: _accent,
          style: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
          decoration: formFieldDecoration(context, hint: "Title"),
        ),
        const SizedBox(height: 16),
        FormDialogGroup(
          children: [
            _ColorTile(
              icon: Icons.palette_rounded,
              color: _pink,
              title: "Cover",
              value: _cover,
              open: _picking == _ColorTarget.cover,
              onTap: () => _togglePalette(_ColorTarget.cover),
              onSelected: (color) => _setColor(_ColorTarget.cover, color),
              onCustom: () => _pickCustomColor(_ColorTarget.cover),
            ),
            _ColorTile(
              icon: Icons.format_color_text_rounded,
              color: _indigo,
              title: "Title Color",
              value: _titleColor,
              open: _picking == _ColorTarget.title,
              onTap: () => _togglePalette(_ColorTarget.title),
              onSelected: (color) => _setColor(_ColorTarget.title, color),
              onCustom: () => _pickCustomColor(_ColorTarget.title),
            ),
            SettingsSwitchTile(
              icon: Icons.fingerprint_rounded,
              color: _green,
              title: "Lock Note",
              subtitle: const Text("Open it with your fingerprint"),
              value: _locked,
              onToggle: _toggleLock,
            ),
          ],
        ),
      ],
      actions: [
        ProfileButton(
          label: "Cancel",
          tinted: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Only once there's a title to save.
        ListenableBuilder(
          listenable: _titleController,
          builder: (context, child) => ProfileButton(
            label: adding ? "Add" : "Save",
            onPressed:
                _titleController.text.trim().isEmpty ? null : () => _save(),
          ),
        ),
      ],
    );
  }
}

/// Whether [color] is white, black or graphite rather than a colour.
bool _isPlain(Color color) =>
    color == _white || color == _graphite || color == Colors.black;

/// [color]'s name in the palette, or "Custom" for any other colour.
String _nameOf(Color color) => _palette
    .firstWhere((entry) => entry.$2 == color, orElse: () => ("Custom", color))
    .$1;

/// A row for one of the note's colours, showing which it is, as the task
/// dialog's rows show their date and time. A tap opens the palette under it,
/// or closes it again.
class _ColorTile extends StatelessWidget {
  const _ColorTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.open,
    required this.onTap,
    required this.onSelected,
    required this.onCustom,
  });

  final IconData icon;
  final Color color;
  final String title;

  /// The colour chosen.
  final Color value;

  /// Whether the palette is open under the row.
  final bool open;
  final VoidCallback onTap;
  final ValueChanged<Color> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      color: color,
      title: title,
      trailing: _ColorValue(color: value, open: open),
      onTap: onTap,
      bottom: open
          // Fades in as the group grows to make room for it.
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: _Swatches(
                selected: value,
                onSelected: onSelected,
                onCustom: onCustom,
              ),
            )
          : null,
    );
  }
}

/// A row's colour, as a swatch and its name, beside a chevron that turns to
/// the palette while it's [open]. The name takes the accent then, as iOS's
/// rows do while their pickers are open.
class _ColorValue extends StatelessWidget {
  const _ColorValue({required this.color, required this.open});

  final Color color;
  final bool open;

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(dimension: 22, child: _ColorDot(color)),
        const SizedBox(width: 8),
        AnimatedDefaultTextStyle(
          duration: _duration,
          style: TextStyle(
            color: open ? context.colors.moreLess : ink.withValues(alpha: 0.45),
            fontSize: 16,
            fontWeight: open ? FontWeight.w500 : FontWeight.w400,
          ),
          child: Text(_nameOf(color)),
        ),
        const SizedBox(width: 2),
        AnimatedRotation(
          turns: open ? 0.25 : 0,
          duration: _duration,
          curve: Curves.easeOutCubic,
          child: Icon(
            Icons.chevron_right_rounded,
            size: 24,
            color: ink.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

/// The palette's colours, then one more for any other colour, six to a row.
class _Swatches extends StatelessWidget {
  const _Swatches({
    required this.selected,
    required this.onSelected,
    required this.onCustom,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;
  final VoidCallback onCustom;

  static const _perRow = 6;

  @override
  Widget build(BuildContext context) {
    final inPalette = _palette.any((entry) => entry.$2 == selected);
    final swatches = [
      for (final (name, color) in _palette)
        _Swatch(
          label: name,
          color: color,
          selected: color == selected,
          onTap: () => onSelected(color),
        ),
      _CustomSwatch(color: inPalette ? null : selected, onTap: onCustom),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(
            38.0, (constraints.maxWidth - (_perRow - 1) * 8) / _perRow);
        return Column(
          children: [
            for (var start = 0; start < swatches.length; start += _perRow) ...[
              if (start > 0) const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final swatch in swatches.skip(start).take(_perRow))
                    SizedBox.square(dimension: size, child: swatch),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A round swatch of [color], which shrinks inside a ring of its own colour
/// while it's the one [selected], as in iOS's colour pickers.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SwatchButton(
      label: label,
      selected: selected,
      // Leans towards the text colour, so white and graphite rings still
      // show on the dialog.
      ring: Color.lerp(color, context.colors.wB, 0.25)!,
      onTap: onTap,
      child: _ColorDot(color),
    );
  }
}

/// A rainbow swatch that opens a picker for any colour, with the colour
/// picked there in its middle while it's the note's.
class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({required this.color, required this.onTap});

  /// The colour picked, or null while the note's is one of the palette's.
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SwatchButton(
      label: "Custom Color",
      selected: color != null,
      ring: context.colors.wB.withValues(alpha: 0.3),
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              Color(0xffFF3B30),
              Color(0xffFFCC00),
              Color(0xff34C759),
              Color(0xff32ADE6),
              Color(0xff5856D6),
              Color(0xffAF52DE),
              Color(0xffFF3B30),
            ],
          ),
        ),
        child: color == null
            ? null
            : Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(width: 2, color: Colors.white),
                  ),
                ),
              ),
      ),
    );
  }
}

/// A swatch that can be tapped, in a ring while it's [selected].
class _SwatchButton extends StatelessWidget {
  const _SwatchButton({
    required this.label,
    required this.selected,
    required this.ring,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final Color ring;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.all(selected ? 4.5 : 0),
          decoration: ShapeDecoration(
            shape: CircleBorder(
              side: BorderSide(
                width: 2,
                color: selected ? ring : ring.withValues(alpha: 0),
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A circle of [color] with a faint sheen from the top, as on the settings'
/// icons, and a hairline edge, so white and graphite show on the dialog.
class _ColorDot extends StatelessWidget {
  const _ColorDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.14)!, color],
        ),
        border: Border.all(
          width: 0.5,
          color: context.colors.wB.withValues(alpha: 0.14),
        ),
      ),
    );
  }
}

/// A heading over the colour picker's shades.
class _PickerSubheading extends StatelessWidget {
  const _PickerSubheading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: context.colors.wB.withValues(alpha: 0.5),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}
