import 'package:material_ui/material_ui.dart';

import '../../core/extensions/theme_extensions.dart';
import 'glass.dart';

/// A round glass button for a bar, which floats over whatever scrolls under
/// it.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 22,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 38,
        child: Glass(
          shape: const CircleBorder(),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              splashFactory: NoSplash.splashFactory,
              highlightColor: context.colors.wB.withValues(alpha: 0.1),
              child: Icon(icon, size: iconSize, color: context.colors.wB),
            ),
          ),
        ),
      ),
    );
  }
}
