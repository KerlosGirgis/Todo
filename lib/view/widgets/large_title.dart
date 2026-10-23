import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/extensions/theme_extensions.dart';

/// A pinned bar in the style of an iOS navigation bar with a large title.
/// It's clear while the [LargeTitle] below it is in view, and turns frosted,
/// with a hairline and its own compact [title], once content scrolls under.
class LargeTitleBarDelegate extends SliverPersistentHeaderDelegate {
  LargeTitleBarDelegate({
    required this.title,
    required this.topInset,
    required this.controller,
    this.leading,
    this.trailing,
    this.titleRevealOffset = 28,
  });

  final String title;

  /// The status bar height, which the bar extends behind.
  final double topInset;

  /// The page's scroll controller, which drives the bar's appearance.
  final ScrollController controller;
  final Widget? leading;
  final Widget? trailing;

  /// How far the page scrolls before the compact [title] fades in: about when
  /// the page's own, larger title has slid under the bar.
  final double titleRevealOffset;

  static const _barHeight = 48.0;

  @override
  double get minExtent => topInset + _barHeight;

  @override
  double get maxExtent => topInset + _barHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final offset = controller.hasClients ? controller.offset : 0.0;
        final frost = (offset / 16).clamp(0.0, 1.0);
        // The compact title takes over as the large one slides under the bar.
        final titleOpacity =
            ((offset - titleRevealOffset) / 16).clamp(0.0, 1.0);
        return Stack(
          // Only the frosted background is clipped to the bar, so buttons on
          // it can cast their shadows past its edge.
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  enabled: frost > 0,
                  filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.colors.pageBackground
                          .withValues(alpha: 0.8 * frost),
                      border: Border(
                        bottom: BorderSide(
                          width: 0.5,
                          color:
                              context.colors.wB.withValues(alpha: 0.16 * frost),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  top: topInset, left: leading == null ? 0 : 16, right: 16),
              child: NavigationToolbar(
                leading: leading,
                middle: Opacity(
                  opacity: titleOpacity,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.wB,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                trailing: trailing,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  bool shouldRebuild(LargeTitleBarDelegate oldDelegate) =>
      title != oldDelegate.title ||
      topInset != oldDelegate.topInset ||
      controller != oldDelegate.controller ||
      leading != oldDelegate.leading ||
      trailing != oldDelegate.trailing ||
      titleRevealOffset != oldDelegate.titleRevealOffset;
}

/// The large title at the top of a page's scrolling content, which scrolls
/// away under a [LargeTitleBarDelegate] bar.
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.wB,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                height: 1.2,
                letterSpacing: -0.7,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
