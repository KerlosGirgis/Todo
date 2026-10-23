import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../profile/profile_page/widgets/profile_button.dart';
import '../../../profile/profile_page/widgets/settings_group.dart';
import 'form_dialog.dart';

// iOS's system colours, as on the profile page's settings.
const _red = Color(0xffFF3B30);
const _green = Color(0xff34C759);

/// Imports tasks from a backup file, either in place of the tasks there are
/// now or alongside them.
class TasksOverwriteDialog extends StatefulWidget {
  const TasksOverwriteDialog({super.key});

  @override
  State<TasksOverwriteDialog> createState() => _TasksOverwriteDialogState();
}

class _TasksOverwriteDialogState extends State<TasksOverwriteDialog> {
  bool _overwrite = true;

  void _import() {
    Provider.of<TasksViewModel>(context, listen: false)
        .restore(_overwrite)
        .then((result) {
      if (mounted) Navigator.pop(context);
      result.when(
        onSuccess: FeedbackToast.success,
        onFailure: FeedbackToast.error,
        onInfo: FeedbackToast.info,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      icon: Icons.settings_backup_restore_rounded,
      title: "Restore Backup",
      subtitle: "Import tasks from a backup file.",
      content: [
        FormDialogGroup(
          children: [
            _Choice(
              icon: Icons.swap_horiz_rounded,
              color: _red,
              title: "Replace My Tasks",
              subtitle: "Delete them, then import the backup",
              selected: _overwrite,
              onTap: () => setState(() => _overwrite = true),
            ),
            _Choice(
              icon: Icons.library_add_rounded,
              color: _green,
              title: "Add to My Tasks",
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
        ProfileButton(label: "Import", onPressed: _import),
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
