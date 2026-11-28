import 'package:material_ui/material_ui.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/result.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/feedback_toast.dart';
import 'form_dialog.dart';
import 'profile_button.dart';
import 'settings_group.dart';

/// Imports [things] from a backup file, either in place of the ones there
/// are now or alongside them, as the user chooses: the to-do page's tasks,
/// or the notes page's notes.
class RestoreBackupDialog extends StatefulWidget {
  const RestoreBackupDialog({
    super.key,
    required this.things,
    required this.restore,
  });

  /// What's restored, as a sentence says it: "tasks".
  final String things;

  /// Restores the backup, given the dialog's context for the prompts it
  /// asks with, and whether it replaces what's there, and says how that
  /// went. Null if the user cancels.
  final Future<Result?> Function(BuildContext context, bool overwrite) restore;

  @override
  State<RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends State<RestoreBackupDialog> {
  bool _overwrite = true;

  /// Whether a restore is under way, which Import doesn't start again.
  bool _restoring = false;

  Future<void> _import() async {
    setState(() => _restoring = true);
    final result = await widget.restore(context, _overwrite);
    if (mounted) closeFormDialog(context);
    FeedbackToast.show(result);
  }

  @override
  Widget build(BuildContext context) {
    final things = widget.things;
    final titled = things[0].toUpperCase() + things.substring(1);
    return FormDialog(
      icon: Icons.settings_backup_restore_rounded,
      title: "Restore Backup",
      subtitle: "Import $things from a backup file.",
      content: [
        FormDialogGroup(
          children: [
            _Choice(
              icon: Icons.swap_horiz_rounded,
              color: SystemColors.red,
              title: "Replace My $titled",
              subtitle: "Delete them, then import the backup",
              selected: _overwrite,
              onTap: () => setState(() => _overwrite = true),
            ),
            _Choice(
              icon: Icons.library_add_rounded,
              color: SystemColors.green,
              title: "Add to My $titled",
              subtitle: "Keep them, and import the ones they're missing",
              selected: !_overwrite,
              onTap: () => setState(() => _overwrite = false),
            ),
          ],
        ),
      ],
      actions: [
        ProfileButton(
          label: "Cancel",
          tinted: true,
          onPressed: () => Navigator.pop(context),
        ),
        ProfileButton(label: "Import", onPressed: _restoring ? null : _import),
      ],
    );
  }
}

/// One of the dialog's choices, ticked when it's the one [selected], as in
/// iOS's lists.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: SettingsTile(
        icon: icon,
        color: color,
        title: title,
        subtitle: Text(subtitle),
        trailing: AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Icon(
            Icons.check_rounded,
            size: 22,
            color: context.colors.moreLess,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
