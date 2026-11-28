import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/theme/palette.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/form_dialog.dart';
import '../../../../widgets/profile_button.dart';

/// Opens the dialog that renames the user, growing into view like the app's
/// other dialogs.
Future<void> showEditNameDialog(BuildContext context) =>
    showFormDialog<void>(context, const EditNameDialog());

class EditNameDialog extends StatefulWidget {
  const EditNameDialog({super.key});

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final name = context.read<UserViewModel>().user.name;
    // Selected, so typing replaces it.
    _nameController = TextEditingController(text: name)
      ..selection = TextSelection(baseOffset: 0, extentOffset: name.length);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Whether there's a name to save: more than spaces.
  bool get _hasName => _nameController.text.trim().isNotEmpty;

  Future<void> _save() async {
    // Not without one, as from the keyboard's Done.
    if (!_hasName) return;
    final result = await context.read<UserViewModel>().rename(
      _nameController.text,
    );
    if (!mounted) return;
    // Open still, to fix the name, unless it's been changed.
    if (result is Success) Navigator.of(context).pop();
    FeedbackToast.show(result);
  }

  @override
  Widget build(BuildContext context) {
    return DialogFrame(
      maxWidth: 400,
      inset: 32,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Edit Name",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.wB,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "The name the app greets you by.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.wB.withValues(alpha: 0.55),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLines: 1,
            maxLength: UserViewModel.maxNameLength,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            cursorColor: AppPalette.accent,
            style: TextStyle(fontSize: 18, color: context.colors.wB),
            decoration: formFieldDecoration(context, hint: "Your name")
                .copyWith(
                  counterStyle: TextStyle(
                    color: context.colors.wB.withValues(alpha: 0.4),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ProfileButton(
                  label: "Cancel",
                  tinted: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              // Only once there's a name to save, as on the app's other
              // forms.
              Expanded(
                child: ListenableBuilder(
                  listenable: _nameController,
                  builder: (context, child) => ProfileButton(
                    label: "Save",
                    onPressed: _hasName ? _save : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
