import 'package:material_ui/material_ui.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/palette.dart';
import 'settings_group.dart';

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
    transitionBuilder: formDialogTransition,
  );
}

/// How a dialog comes into view, and goes: fading in as it grows from a
/// little smaller. Also for one opened another way, such as the avatar's,
/// which needs a page route for its hero to fly into.
Widget formDialogTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curvedAnimation = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curvedAnimation,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1).animate(curvedAnimation),
      child: child,
    ),
  );
}

/// Closes the dialog [context] is in, even once another page has come over
/// it: the lock page does, when the app locks again while the dialog waits
/// on another app, such as the file picker. [Navigator.pop] would close the
/// lock page instead, as it closes whichever page is on top.
void closeFormDialog(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  if (route.isCurrent) {
    Navigator.of(context).pop();
  } else {
    Navigator.of(context).removeRoute(route);
  }
}

/// A dialog in the style of the profile page's, under a header of its own:
/// an [icon] on a tile in the app's blues, then the [title] over a line of
/// [subtitle], and a button at the end that closes it. Then its [content],
/// if it has any, and its [actions] side by side at the bottom.
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.icon,
    this.color,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.actions,
  });

  final IconData icon;

  /// The colour of the icon's tile, such as red for a dialog that deletes,
  /// in place of the app's blues.
  final Color? color;
  final String title;
  final String subtitle;
  final List<Widget> content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return DialogFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _HeaderIcon(icon, color: color),
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
          if (content.isNotEmpty) ...[const SizedBox(height: 20), ...content],
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
    );
  }
}

/// What the app's dialogs are drawn on: the dialogs' colour, with large
/// round corners and the theme's hairline round them, at most [maxWidth]
/// wide and [inset] in from the sides of the screen. Their [child] scrolls
/// on a screen too short for it, set in by [padding]. The sizes are a
/// [FormDialog]'s unless given.
class DialogFrame extends StatelessWidget {
  const DialogFrame({
    super.key,
    this.maxWidth = 440,
    this.inset = 24,
    this.padding = const EdgeInsets.all(20),
    this.clipBehavior,
    required this.child,
  });

  final double maxWidth;
  final double inset;
  final EdgeInsetsGeometry padding;

  /// How what's in it is cut to its corners, if it is.
  final Clip? clipBehavior;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.dialogBackground,
      surfaceTintColor: Colors.transparent,
      clipBehavior: clipBehavior,
      insetPadding: EdgeInsets.symmetric(horizontal: inset, vertical: 24),
      constraints: BoxConstraints(minWidth: 280, maxWidth: maxWidth),
      shape: RoundedSuperellipseBorder(
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        side: context.colors.dialogSide,
      ),
      child: SingleChildScrollView(padding: padding, child: child),
    );
  }
}

/// The dialog's icon, white on a tile with the add button's gradient, or
/// one that lightens [color] the same way.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(this.icon, {this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: color == null
              ? [
                  AppPalette.accent,
                  Color.lerp(AppPalette.accent, AppPalette.highlight, 0.7)!,
                ]
              : [color, Color.lerp(color, Colors.white, 0.25)!],
        ),
        shadows: [
          BoxShadow(
            color: (color ?? AppPalette.accent).withValues(alpha: 0.25),
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
InputDecoration formFieldDecoration(
  BuildContext context, {
  required String hint,
}) {
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
      borderSide: const BorderSide(color: AppPalette.accent, width: 1.5),
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

/// A segment of a segmented control on a [FormDialog], such as the task's
/// reminder's.
class FormSegment extends StatelessWidget {
  const FormSegment(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Text(label, style: const TextStyle(fontSize: 14.5)),
    );
  }
}
