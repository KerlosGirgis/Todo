import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/extensions/theme_extensions.dart';
import 'glass.dart';

/// A glass panel that opens under [child] while [open], lined up with its
/// start, or over it when there's far more room there, and scrolls when
/// it's taller than the room it has. Anything else touched, or Back, asks
/// [onClose] to close it, and does nothing else.
///
/// It's drawn just above its page, so a page that comes over that one, such
/// as the lock page, covers it too.
class GlassPopover extends StatefulWidget {
  const GlassPopover({
    super.key,
    required this.open,
    required this.onClose,
    required this.panel,
    required this.child,
    this.label,
    this.width = 248,
  });

  final bool open;
  final VoidCallback onClose;

  /// Builds what's in the panel, such as [GlassPopoverOption]s under a
  /// [GlassPopoverHeader].
  final WidgetBuilder panel;

  /// What the panel opens from.
  final Widget child;

  /// What a screen reader calls the panel.
  final String? label;

  /// How wide the panel is at the usual text size, if the screen has the
  /// room.
  final double width;

  @override
  State<GlassPopover> createState() => _GlassPopoverState();
}

class _GlassPopoverState extends State<GlassPopover>
    with SingleTickerProviderStateMixin {
  static const _shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)));

  /// The room between the panel and what it opens from, and between the
  /// panel and the edges of the screen.
  static const _gap = 8.0;
  static const _margin = 12.0;

  /// The room under what it opens from that's enough for it to open there.
  static const _enoughBelow = 240.0;

  final _portal = OverlayPortalController();
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 160),
  )..addStatusListener(_statusChanged);
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final _scale = Tween(begin: 0.9, end: 1.0).animate(_curve);

  @override
  void initState() {
    super.initState();
    if (widget.open) _syncSoon();
  }

  @override
  void didUpdateWidget(GlassPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) _syncSoon();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Opens or closes the panel, as [GlassPopover.open] has it by then, once
  /// the frame being built is done: what's on the overlay can't change
  /// while it's being built.
  void _syncSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final still = MediaQuery.disableAnimationsOf(context);
      if (widget.open) {
        _portal.show();
        if (still) {
          _controller.value = 1;
        } else {
          _controller.forward();
        }
      } else if (still) {
        _controller.value = 0;
      } else {
        _controller.reverse();
      }
    });
  }

  void _statusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    // A node of its own, which screen readers reach the panel through. Were
    // it to share its page's, which the tour's overlay has as well, the
    // panel would be left out.
    return Semantics(
      container: true,
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _portal,
        overlayChildBuilder: _buildOverlay,
        child: widget.child,
      ),
    );
  }

  /// The panel, where what it opens from is now, so it stays with it as
  /// the screen turns.
  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final anchor = MatrixUtils.transformRect(
        info.childPaintTransform, Offset.zero & info.childSize);
    final screen = info.overlaySize;
    final padding = MediaQuery.paddingOf(context);
    final rightToLeft = Directionality.of(context) == TextDirection.rtl;
    // Wider for larger text, by as much as its choices' names grow.
    final textScale = MediaQuery.textScalerOf(context).scale(15.5) / 15.5;
    final width =
        math.min(widget.width * textScale, screen.width - 2 * _margin);
    final left = (rightToLeft ? anchor.right - width : anchor.left)
        .clamp(_margin, math.max(_margin, screen.width - _margin - width))
        .toDouble();
    final below =
        screen.height - padding.bottom - _margin - anchor.bottom - _gap;
    final above = anchor.top - padding.top - _margin - _gap;
    final down = below >= _enoughBelow || below >= above;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onClose();
      },
      child: Stack(
        children: [
          Positioned.fill(
            // Not while it's closing, when a touch is for the page again.
            child: IgnorePointer(
              ignoring: !widget.open,
              child: Semantics(
                label:
                    MaterialLocalizations.of(context).modalBarrierDismissLabel,
                onTap: widget.onClose,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) => widget.onClose(),
                ),
              ),
            ),
          ),
          Positioned(
            left: left,
            width: width,
            top: down ? anchor.bottom + _gap : null,
            bottom: down ? null : screen.height - anchor.top + _gap,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: math.max(0.0, down ? below : above)),
              child: FadeTransition(
                opacity: _curve,
                // Out of the corner nearest what it opens from.
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment(rightToLeft ? 1 : -1, down ? -1 : 1),
                  child: Semantics(
                    scopesRoute: true,
                    namesRoute: true,
                    explicitChildNodes: true,
                    label: widget.label,
                    child: Glass(
                      shape: _shape,
                      child: Material(
                        type: MaterialType.transparency,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: widget.panel(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A heading over a group of [GlassPopoverOption]s, in small capitals in
/// the accent, as the page's own headings are.
class GlassPopoverHeader extends StatelessWidget {
  const GlassPopoverHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.colors.moreLess,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// One of the choices in a [GlassPopover]: its icon, its name, and how many
/// things it stands for, if [count] is given. The one that's [selected] is
/// in the accent, with a check at its end.
class GlassPopoverOption extends StatelessWidget {
  const GlassPopoverOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final accent = context.colors.moreLess;
    final count = this.count;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        // Glass highlights a pressed choice instead of rippling.
        splashFactory: NoSplash.splashFactory,
        highlightColor: ink.withValues(alpha: 0.08),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: selected ? accent : ink.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 15.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (count != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: Text(
                      "$count",
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.45),
                        fontSize: 14.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                SizedBox.square(
                  dimension: 20,
                  child: selected
                      ? Icon(Icons.check_rounded, size: 20, color: accent)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A hairline between groups of [GlassPopoverOption]s.
class GlassPopoverDivider extends StatelessWidget {
  const GlassPopoverDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 0.5,
        child: ColoredBox(color: context.colors.wB.withValues(alpha: 0.14)),
      ),
    );
  }
}
