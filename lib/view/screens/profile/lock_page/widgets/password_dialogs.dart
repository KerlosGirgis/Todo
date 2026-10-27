import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/prompts.dart';
import '../../../../../core/result.dart';
import '../../../../../view_model/auth_view_model.dart';
import '../../../tasks/todo_page/widgets/form_dialog.dart';
import '../../profile_page/widgets/profile_button.dart';
import 'password_field.dart';

/// How the App Lock's password is asked for, saying what for in [subtitle]:
/// from [context]'s page, if it's still open by then.
PasswordPrompt passwordPrompt(BuildContext context,
        {required String subtitle}) =>
    () async {
      if (!context.mounted) return null;
      return showPasswordDialog(context, subtitle: subtitle);
    };

/// How a locked note asks for the App Lock's password in place of the
/// fingerprint, on a phone that can't take one.
PasswordPrompt noteLockPasswordPrompt(BuildContext context) => passwordPrompt(
      context,
      subtitle:
          "Your fingerprint isn't available, so enter your password instead.",
    );

/// How a new password for the App Lock is asked for: from [context]'s page,
/// if it's still open by then.
NewPasswordPrompt newPasswordPrompt(BuildContext context) =>
    ({required int minLength}) async {
      if (!context.mounted) return null;
      return showFormDialog<String>(
        context,
        _NewPasswordDialog(
          title: "New Password",
          subtitle: "You'll need it each time the app opens.",
          warning: "Pick one you'll remember: there's no way to reset it if "
              "you forget it.",
          minLength: minLength,
        ),
      );
    };

/// How a backup asks for the password to lock it with: from [context]'s
/// page, if it's still open by then.
NewBackupPasswordPrompt newBackupPasswordPrompt(BuildContext context) => ({
      required int minLength,
      required Future<Result> Function(String password) lock,
    }) async {
      if (!context.mounted) return false;
      final password = await showFormDialog<String>(
        context,
        _NewPasswordDialog(
          title: "Backup Password",
          subtitle: "You'll need it to restore this backup.",
          warning: "Pick one you'll remember: without it, there's no way to "
              "open the backup.",
          minLength: minLength,
          save: lock,
          saving: "Encrypting…",
        ),
      );
      return password != null;
    };

/// How a backup being restored asks for the password it was locked with:
/// from [context]'s page, if it's still open by then.
BackupPasswordPrompt backupPasswordPrompt(BuildContext context) =>
    (open) async {
      if (!context.mounted) return false;
      final password = await showFormDialog<String>(
        context,
        _PasswordDialog(
          subtitle: "Enter the password this backup was made with.",
          check: open,
        ),
      );
      return password != null;
    };

/// Asks for the App Lock's password, saying what for in [subtitle], and
/// hands it back once it's right, or null if the user cancels.
Future<String?> showPasswordDialog(BuildContext context,
    {required String subtitle}) {
  return showFormDialog<String>(
    context,
    _PasswordDialog(
      subtitle: subtitle,
      check: context.read<AuthViewModel>().checkPassword,
    ),
  );
}

/// Asks for a password, saying what for in [subtitle], until [check] finds
/// one right, and hands that one back, or null if the user cancels.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.subtitle, required this.check});

  final String subtitle;
  final Future<Result> Function(String password) check;

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
    final result = await widget.check(password);
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
            // A backup's password takes a few seconds to check.
            label: _checking ? "Checking…" : "Continue",
            onPressed:
                _controller.text.isEmpty || _checking ? null : _submit,
          ),
        ),
      ],
    );
  }
}

/// Asks for a new password of at least [minLength] characters, twice, under
/// [title] and [subtitle], with a [warning] about forgetting it, and hands it
/// back once [save], if there's one, has done what it's for.
class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog({
    required this.title,
    required this.subtitle,
    required this.warning,
    required this.minLength,
    this.save,
    this.saving = "Saving…",
  });

  final String title;
  final String subtitle;
  final String warning;
  final int minLength;

  /// What's done with the password before the dialog closes, such as locking
  /// a backup with it, which says [saving] on the button while it's busy. The
  /// dialog stays open to say why, if it fails.
  final Future<Result> Function(String password)? save;
  final String saving;

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final password = _password.text;
    final minLength = widget.minLength;
    final error = password.length < minLength
        ? "Use at least $minLength characters"
        : password != _confirmation.text
            ? "The passwords don't match"
            : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final save = widget.save;
    if (save != null) {
      setState(() => _saving = true);
      final result = await save(password);
      if (!mounted) return;
      if (result is Failure) {
        setState(() {
          _saving = false;
          _error = result.message;
        });
        return;
      }
    }
    if (mounted) Navigator.of(context).pop(password);
  }

  /// Clears the error once the passwords it was about are changed.
  void _edited(String _) {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      icon: Icons.password_rounded,
      title: widget.title,
      subtitle: widget.subtitle,
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
            widget.warning,
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
            label: _saving ? widget.saving : "Save",
            onPressed: _password.text.isEmpty ||
                    _confirmation.text.isEmpty ||
                    _saving
                ? null
                : _submit,
          ),
        ),
      ],
    );
  }
}
