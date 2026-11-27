import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../view_model/notes_view_model.dart';
import '../../../../widgets/color_swatches.dart';
import '../../../../widgets/form_dialog.dart';
import '../../../../widgets/password_dialogs.dart';
import '../../../../widgets/profile_button.dart';
import '../../../../widgets/settings_group.dart';

const _accent = Color(0xff3D5AFE);

// iOS's system colours, as on the profile page's settings.
const _pink = Color(0xffFF2D55);
const _indigo = Color(0xff5856D6);
const _green = Color(0xff34C759);

/// One of the note's two colours.
enum _ColorTarget { cover, title }

/// Adds a note, or edits the one [draft] is for, as the task dialog does:
/// its title, then its colours and lock in rows like the profile page's
/// settings. A colour's row opens the palette under it. The dialog lets
/// [draft] go once it closes.
class NoteDialog extends StatefulWidget {
  const NoteDialog({super.key, required this.draft});

  final NoteDraft draft;

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late final _titleController = TextEditingController(text: _draft.title);

  NoteDraft get _draft => widget.draft;

  /// The colour whose palette is open under its row, if either's is.
  _ColorTarget? _picking;

  @override
  void dispose() {
    _titleController.dispose();
    _draft.dispose();
    super.dispose();
  }

  void _togglePalette(_ColorTarget target) {
    // The keyboard would cover the palette.
    FocusScope.of(context).unfocus();
    setState(() => _picking = _picking == target ? null : target);
  }

  Color _colorOf(_ColorTarget target) => Color(switch (target) {
    _ColorTarget.cover => _draft.coverColor,
    _ColorTarget.title => _draft.titleColor,
  });

  void _setColor(_ColorTarget target, Color color) {
    switch (target) {
      case _ColorTarget.cover:
        _draft.setCoverColor(color.toARGB32());
      case _ColorTarget.title:
        _draft.setTitleColor(color.toARGB32());
    }
  }

  Future<void> _pickCustomColor(_ColorTarget target) async {
    final current = _colorOf(target);
    final picked = await pickCustomColor(
      context,
      current,
      target == _ColorTarget.cover ? "Cover Color" : "Title Color",
    );
    // A cancelled picker hands back the colour it started with.
    if (mounted && picked != current) _setColor(target, picked);
  }

  Future<void> _setLocked(bool locked) async {
    final result = await _draft.setLocked(
      locked,
      askForPassword: noteLockPasswordPrompt(context),
    );
    if (!mounted) return;
    FeedbackToast.show(result);
  }

  /// Whether the note's being saved, which the form waits for: it stays
  /// open, with what was put in it, should the note not be saved.
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await _draft.save();
    if (mounted) {
      if (result is Unsaved) {
        setState(() => _saving = false);
      } else {
        Navigator.of(context).pop();
      }
    }
    FeedbackToast.show(result);
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final adding = _draft.adding;
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, child) => FormDialog(
        icon: adding ? Icons.note_add_rounded : Icons.edit_rounded,
        title: adding ? "New Note" : "Edit Note",
        subtitle: adding
            ? "What's this note about?"
            : "Change its details, then save.",
        content: [
          TextField(
            controller: _titleController,
            onChanged: _draft.setTitle,
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
              ColorTile(
                icon: Icons.palette_rounded,
                color: _pink,
                title: "Cover",
                value: _colorOf(_ColorTarget.cover),
                open: _picking == _ColorTarget.cover,
                onTap: () => _togglePalette(_ColorTarget.cover),
                onSelected: (color) => _setColor(_ColorTarget.cover, color!),
                onCustom: () => _pickCustomColor(_ColorTarget.cover),
              ),
              ColorTile(
                icon: Icons.format_color_text_rounded,
                color: _indigo,
                title: "Title Color",
                value: _colorOf(_ColorTarget.title),
                open: _picking == _ColorTarget.title,
                onTap: () => _togglePalette(_ColorTarget.title),
                onSelected: (color) => _setColor(_ColorTarget.title, color!),
                onCustom: () => _pickCustomColor(_ColorTarget.title),
              ),
              SettingsSwitchTile(
                icon: Icons.fingerprint_rounded,
                color: _green,
                title: "Lock Note",
                subtitle: const Text("Open it with your fingerprint"),
                value: _draft.locked,
                onChanged: _setLocked,
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
          ProfileButton(
            label: adding ? "Add" : "Save",
            onPressed: _draft.canSave && !_saving ? _save : null,
          ),
        ],
      ),
    );
  }
}
