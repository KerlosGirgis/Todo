import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../models/app_lock.dart';
import '../../../../../view_model/auth_view_model.dart';
import '../../../../../view_model/notes_view_model.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../tasks/todo_page/widgets/form_dialog.dart';
import '../../profile_page/widgets/profile_button.dart';
import 'password_field.dart';

/// Runs [action], which needs the App Lock to let the user through: for an
/// app locked with a password, once the user gives it, which [action] gets
/// to check again; otherwise straight away, without one, for [action] to
/// check the lock itself. [subtitle] says what the password is for. Nothing
/// happens if the user cancels.
Future<void> withAppLockPassword(
  BuildContext context, {
  required String subtitle,
  required Future<void> Function(String? password) action,
}) async {
  if (context.read<UserViewModel>().appLock != AppLock.password) {
    return action(null);
  }
  final password = await showPasswordDialog(context, subtitle: subtitle);
  if (password != null) await action(password);
}

/// How a locked note asks for the App Lock's password in place of the
/// fingerprint, on a phone that can't take one: from [context]'s page, if it's
/// still open by then.
PasswordPrompt noteLockPasswordPrompt(BuildContext context) => () async {
      if (!context.mounted) return null;
      return showPasswordDialog(
        context,
        subtitle:
            "Your fingerprint isn't available, so enter your password instead.",
      );
    };

/// Asks for the App Lock's password, saying what for in [subtitle], and
/// hands it back once it's right, or null if the user cancels.
Future<String?> showPasswordDialog(BuildContext context,
    {required String subtitle}) {
  return showFormDialog<String>(context, _PasswordDialog(subtitle: subtitle));
}

/// Asks for a new password for the App Lock, twice, so that a typo can't
/// lock the user out, and hands it back, or null if the user cancels.
Future<String?> showNewPasswordDialog(BuildContext context) {
  return showFormDialog<String>(context, const _NewPasswordDialog());
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.subtitle});

  final String subtitle;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text;
    if (password.isEmpty || _checking) return;
    setState(() => _checking = true);
    final result = await context.read<AuthViewModel>().checkPassword(password);
    if (!mounted) return;
    if (result is Failure) {
      HapticFeedback.heavyImpact();
      _controller.clear();
      setState(() {
        _checking = false;
        _error = result.message;
      });
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      icon: Icons.lock_rounded,
      title: "Enter Password",
      subtitle: widget.subtitle,
      content: [
        PasswordField(
          controller: _controller,
          hint: "Password",
          autofocus: true,
          error: _error,
          onSubmitted: _submit,
        ),
      ],
      actions: [
        ProfileButton(
          label: "Cancel",
          tinted: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, child) => ProfileButton(
            label: "Continue",
            onPressed:
                _controller.text.isEmpty || _checking ? null : _submit,
          ),
        ),
      ],
    );
  }
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog();

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _password.text;
    const minLength = UserViewModel.minPasswordLength;
    final error = password.length < minLength
        ? "Use at least $minLength characters"
        : password != _confirmation.text
            ? "The passwords don't match"
            : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(password);
  }

  /// Clears the error once the passwords it was about are changed.
  void _edited(String _) {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      icon: Icons.password_rounded,
      title: "New Password",
      subtitle: "You'll need it each time the app opens.",
      content: [
        PasswordField(
          controller: _password,
          hint: "Password",
          autofocus: true,
          textInputAction: TextInputAction.next,
          onChanged: _edited,
        ),
        const SizedBox(height: 12),
        PasswordField(
          controller: _confirmation,
          hint: "Confirm Password",
          error: _error,
          onChanged: _edited,
          onSubmitted: _submit,
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "Pick one you'll remember: there's no way to reset it if you "
            "forget it.",
            style: TextStyle(
              color: context.colors.wB.withValues(alpha: 0.55),
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
      actions: [
        ProfileButton(
          label: "Cancel",
          tinted: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Only once both fields are filled in.
        ListenableBuilder(
          listenable: Listenable.merge([_password, _confirmation]),
          builder: (context, child) => ProfileButton(
            label: "Save",
            onPressed:
                _password.text.isEmpty || _confirmation.text.isEmpty
                    ? null
                    : _submit,
          ),
        ),
      ],
    );
  }
}
