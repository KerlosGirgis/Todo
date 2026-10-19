import 'package:flutter/material.dart';

import '../../core/extensions/theme_extensions.dart';
import 'glass.dart';

/// An action in a [GlassMenu].
class GlassMenuItem {
  const GlassMenuItem({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

/// A round glass button for a bar, which opens into a glass capsule of
/// [items], its menu icon turning into an arrow that closes it again. It
/// closes by itself once an item is chosen.
class GlassMenu extends StatefulWidget {
  const GlassMenu({super.key, required this.items});

  final List<GlassMenuItem> items;

  @override
  State<GlassMenu> createState() => _GlassMenuState();
}

class _GlassMenuState extends State<GlassMenu>
    with SingleTickerProviderStateMixin {
  static const _height = 38.0;
  static const _itemWidth = 40.0;

  /// Keeps the last item clear of the capsule's rounded end.
  static const _endPadding = 4.0;

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final _openness = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  bool get _open => _controller.isForwardOrCompleted;

  @override
  void dispose() {
    _openness.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_open) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  void _choose(GlassMenuItem item) {
    _controller.reverse();
    item.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final itemsWidth = widget.items.length * _itemWidth + _endPadding;
    return AnimatedBuilder(
      animation: _openness,
      builder: (context, child) {
        final openness = _openness.value;
        return SizedBox(
          width: _height + itemsWidth * openness,
          height: _height,
          child: Glass(
            child: Row(
              children: [
                _MenuButton(
                  width: _height,
                  tooltip: _open ? "Close menu" : "Menu",
                  onPressed: _toggle,
                  child: AnimatedIcon(
                    icon: AnimatedIcons.menu_arrow,
                    progress: _openness,
                    size: 22,
                    color: ink,
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: AlignmentDirectional.centerStart,
                      minWidth: itemsWidth,
                      maxWidth: itemsWidth,
                      child: ExcludeSemantics(
                        excluding: openness == 0,
                        child: Opacity(opacity: openness, child: child),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Row(
        children: [
          for (final item in widget.items)
            _MenuButton(
              width: _itemWidth,
              tooltip: item.tooltip,
              onPressed: () => _choose(item),
              child: Icon(item.icon, size: 21, color: ink),
            ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.width,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final double width;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: width,
        height: _GlassMenuState._height,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            // Glass highlights a pressed button instead of rippling.
            splashFactory: NoSplash.splashFactory,
            highlightColor: context.colors.wB.withValues(alpha: 0.1),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
