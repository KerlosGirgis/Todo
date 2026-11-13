import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../profile/profile_page/widgets/profile_button.dart';
import '../../../tasks/todo_page/widgets/form_dialog.dart';

/// Asks the user whether to delete something from the trash for good, with
/// [title], and [message] saying what goes. Whether they said to.
Future<bool> confirmDeleteForever(BuildContext context,
    {required String title, required String message}) async {
  final confirmed = await showFormDialog<bool>(
      context, _ConfirmDeleteDialog(title: title, message: message));
  return confirmed ?? false;
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return FormDialog(
      icon: Icons.delete_forever_rounded,
      // iOS's system red, as on the delete buttons.
      color: isDarkTheme ? const Color(0xffFF453A) : const Color(0xffFF3B30),
      title: title,
      subtitle: message,
      content: const [],
      actions: [
        ProfileButton(
          label: "Cancel",
          tinted: true,
          onPressed: () => Navigator.pop(context, false),
        ),
        ProfileButton(
          label: "Delete",
          destructive: true,
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context, true);
          },
        ),
      ],
    );
  }
}
