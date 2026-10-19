import 'package:flutter/material.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../profile/profile_page/widgets/settings_group.dart';

const _accent = Color(0xff3D5AFE);

/// Opens [dialog], fading and growing it into view like the profile page's
/// dialogs.
Future<T?> showFormDialog<T>(BuildContext context, Widget dialog) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => dialog,
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

/// A dialog in the style of the profile page's: a centred [title] over an
/// optional line of [subtitle], then its [content], and its [actions] side by
/// side at the bottom.
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.content,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget> content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.cardBackground,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 440),
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.wB,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.wB.withValues(alpha: 0.55),
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 20),
            ...content,
            const SizedBox(height: 20),
            Row(
              children: [
                for (final (index, action) in actions.indexed) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(child: action),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The look of a [FormDialog]'s text fields: filled, with the accent around
/// the one being typed in, as on the profile page's name dialog.
InputDecoration formFieldDecoration(BuildContext context,
    {required String hint}) {
  final shape = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: context.colors.wB.withValues(alpha: 0.35)),
    filled: true,
    fillColor: context.colors.wB.withValues(alpha: 0.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: shape,
    enabledBorder: shape,
    focusedBorder: shape.copyWith(
      borderSide: const BorderSide(color: _accent, width: 1.5),
    ),
  );
}

/// Rows of options, such as [SettingsTile]s, on one surface filled like the
/// text fields, with hairlines between them that start where their text
/// does. It eases to its new height when a row comes or goes.
class FormDialogGroup extends StatelessWidget {
  const FormDialogGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hairline = Divider(
      height: 0.5,
      thickness: 0.5,
      indent: SettingsTile.textInset,
      color: context.colors.wB.withValues(alpha: 0.1),
    );
    return Material(
      color: context.colors.wB.withValues(alpha: 0.06),
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) hairline,
              child,
            ],
          ],
        ),
      ),
    );
  }
}
