import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../tasks/todo_page/widgets/form_dialog.dart';

const _accent = Color(0xff3D5AFE);

/// A field for a password, hidden as it's typed unless the eye at its end
/// shows it, with [error] in red under it when there is one.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.hint,
    this.error,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;

  /// Why the password typed won't do, such as its being the wrong one.
  final String? error;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final error = widget.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          obscureText: !_shown,
          autocorrect: false,
          enableSuggestions: false,
          // Kept from what the keyboard learns, even while it's shown.
          enableIMEPersonalizedLearning: false,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          // Keeps the keyboard up as the password goes in, for another try
          // if it's wrong.
          onEditingComplete: widget.onSubmitted == null ? null : () {},
          onSubmitted: (_) => widget.onSubmitted?.call(),
          cursorColor: _accent,
          style: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
          decoration: formFieldDecoration(context, hint: widget.hint).copyWith(
            // Out of the focus order, so that the keyboard's next button goes
            // on to the next field, rather than to the eye.
            suffixIcon: ExcludeFocus(
              child: IconButton(
                tooltip: _shown ? "Hide Password" : "Show Password",
                onPressed: () => setState(() => _shown = !_shown),
                icon: Icon(
                  _shown
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: ink.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: isDarkTheme
                          ? const Color(0xffFF453A)
                          : const Color(0xffFF3B30),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
