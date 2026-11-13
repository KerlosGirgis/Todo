import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';

const _accent = Color(0xff3D5AFE);

/// A wide button for the profile page's sheets and dialogs: filled with the
/// accent for the main action, or [tinted] with it for the others; in red
/// for one that's [destructive].
class ProfileButton extends StatelessWidget {
  const ProfileButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tinted = false,
    this.destructive = false,
  });

  final String label;

  /// Disables the button when null.
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool tinted;

  /// Whether it deletes something for good, which colours it red.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final ink = context.colors.wB;
    // iOS's system red, a touch brighter on dark pages, as there.
    final color = destructive
        ? (isDarkTheme ? const Color(0xffFF453A) : const Color(0xffFF3B30))
        : _accent;
    final style = FilledButton.styleFrom(
      backgroundColor:
          tinted ? color.withValues(alpha: isDarkTheme ? 0.2 : 0.1) : color,
      foregroundColor: tinted
          ? (destructive ? color : context.colors.moreLess)
          : Colors.white,
      disabledBackgroundColor: ink.withValues(alpha: 0.08),
      disabledForegroundColor: ink.withValues(alpha: 0.3),
      minimumSize: const Size.fromHeight(50),
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      textStyle: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    );
    final child = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    return icon == null
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 20),
            label: child,
          );
  }
}
