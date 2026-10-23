import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../profile/profile_page/widgets/settings_group.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

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

/// A dialog in the style of the profile page's, under a header of its own:
/// an [icon] on a tile in the app's blues, then the [title] over a line of
/// [subtitle], and a button at the end that closes it. Then its [content],
/// and its [actions] side by side at the bottom.
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _HeaderIcon(icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.colors.wB,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.colors.wB.withValues(alpha: 0.55),
                          fontSize: 13.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const _CloseButton(),
              ],
            ),
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

/// The dialog's icon, white on a tile with the add button's gradient.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accent, Color.lerp(_accent, _highlight, 0.7)!],
        ),
        shadows: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: 48,
        child: Icon(icon, size: 25, color: Colors.white),
      ),
    );
  }
}

/// A small round button that closes the dialog, as on iOS's sheets.
class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return Tooltip(
      message: MaterialLocalizations.of(context).closeButtonTooltip,
      child: Material(
        color: ink.withValues(alpha: 0.07),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          customBorder: const CircleBorder(),
          splashFactory: NoSplash.splashFactory,
          highlightColor: ink.withValues(alpha: 0.1),
          child: SizedBox.square(
            dimension: 30,
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: ink.withValues(alpha: 0.55),
            ),
          ),
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
