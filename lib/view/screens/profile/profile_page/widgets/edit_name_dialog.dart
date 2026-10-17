import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/core/ui/feedback_toast.dart';
import 'package:todo/view_model/user_view_model.dart';
import '../../../../../core/extensions/theme_extensions.dart';
import 'profile_button.dart';

const _accent = Color(0xff3D5AFE);

/// Opens the dialog that renames the user, growing into view like the app's
/// other dialogs.
Future<void> showEditNameDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const EditNameDialog(),
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
}

class EditNameDialog extends StatefulWidget {
  const EditNameDialog({
    super.key,
  });

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

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      FeedbackToast.error("Name can't be empty");
      return;
    }
    context.read<UserViewModel>().editName(name).then((value) {
      FeedbackToast.info("Name Updated");
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fieldShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    return Dialog(
      backgroundColor: context.colors.cardBackground,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: SingleChildScrollView(
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
              maxLength: 20,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              cursorColor: _accent,
              style: TextStyle(fontSize: 18, color: context.colors.wB),
              decoration: InputDecoration(
                hintText: "Your name",
                hintStyle:
                    TextStyle(color: context.colors.wB.withValues(alpha: 0.35)),
                filled: true,
                fillColor: context.colors.wB.withValues(alpha: 0.06),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: fieldShape,
                enabledBorder: fieldShape,
                focusedBorder: fieldShape.copyWith(
                  borderSide: const BorderSide(color: _accent, width: 1.5),
                ),
                counterStyle:
                    TextStyle(color: context.colors.wB.withValues(alpha: 0.4)),
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
                Expanded(
                  child: ProfileButton(label: "Save", onPressed: _save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
