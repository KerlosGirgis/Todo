import 'package:flutter/material.dart';
import '../../../../../core/extensions/theme_extensions.dart';

/// Shown in place of the grid, in the style of Apple's empty states: when
/// there are no notes, or when a search finds none.
class EmptyNotes extends StatelessWidget {
  const EmptyNotes({super.key, this.query});

  /// The search that found nothing; null when there are no notes at all.
  final String? query;

  @override
  Widget build(BuildContext context) {
    final searching = query != null;
    final secondary = TextStyle(
      color: context.colors.wB.withValues(alpha: 0.55),
      fontSize: 15,
      height: 1.35,
      letterSpacing: -0.15,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                searching ? Icons.search_rounded : Icons.sticky_note_2_outlined,
                size: 56,
                color: context.colors.wB.withValues(alpha: 0.28),
              ),
              const SizedBox(height: 16),
              Text(
                searching ? "No Results for “$query”" : "No Notes",
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.wB,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              searching
                  ? Text(
                      "Check the spelling or try a new search.",
                      textAlign: TextAlign.center,
                      style: secondary,
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: "Tap "),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(
                              Icons.edit_square,
                              size: 17,
                              color: context.colors.moreLess,
                            ),
                          ),
                          const TextSpan(text: " to write your first note."),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: secondary,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
