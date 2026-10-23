import 'package:material_ui/material_ui.dart';

import '../../core/extensions/theme_extensions.dart';
import 'glass.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

/// The floating buttons at the bottom of the to-do and notes pages: a glass
/// one that switches to the other page, over a glowing one in the app's
/// blues that adds to this one.
class PageActionButtons extends StatelessWidget {
  const PageActionButtons({
    super.key,
    required this.switchIcon,
    required this.switchTooltip,
    required this.onSwitch,
    required this.addTooltip,
    required this.onAdd,
  });

  /// How much of the page the buttons cover, from the bottom of the safe
  /// area, so the list can scroll its last card clear of them.
  static const height = 16 + _GlassButton.size + 16 + _AddButton.size;

  /// The other page's icon and name.
  final IconData switchIcon;
  final String switchTooltip;
  final VoidCallback onSwitch;

  /// What the add button adds, such as "Add Task".
  final String addTooltip;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GlassButton(
          icon: switchIcon,
          tooltip: switchTooltip,
          onPressed: onSwitch,
        ),
        const SizedBox(height: 16),
        _AddButton(tooltip: addTooltip, onPressed: onAdd),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  static const size = 52.0;
  static const _shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(18)),
  );

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: Glass(
          shape: _shape,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              customBorder: _shape,
              splashFactory: NoSplash.splashFactory,
              highlightColor: context.colors.wB.withValues(alpha: 0.1),
              child: Icon(icon, size: 27, color: context.colors.wB),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.tooltip, required this.onPressed});

  static const size = 60.0;

  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  static const _shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
  );

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: _shape,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_accent, Color.lerp(_accent, _highlight, 0.7)!],
            ),
            // A soft shadow of its own colour, which lifts it off the page.
            shadows: [
              BoxShadow(
                color: _accent.withValues(alpha: isDarkTheme ? 0.22 : 0.25),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (pressed) =>
                  setState(() => _pressed = pressed),
              customBorder: _shape,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.white.withValues(alpha: 0.12),
              child: const SizedBox.square(
                dimension: _AddButton.size,
                child: Icon(Icons.add_rounded, size: 32, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
