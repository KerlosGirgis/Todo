import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../widgets/form_dialog.dart';
import '../../../../widgets/profile_button.dart';

/// Asks the user whether to delete something from the trash for good, with
/// [title], and [message] saying what goes. Whether they said to.
Future<bool> confirmDeleteForever(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showFormDialog<bool>(
    context,
    _ConfirmDeleteDialog(title: title, message: message),
  );
  return confirmed ?? false;
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      icon: Icons.delete_forever_rounded,
      // iOS's system red, as on the delete buttons.
      color: context.colors.systemRed,
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
