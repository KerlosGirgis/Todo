import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../widgets/ringed_avatar.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

/// Shown in place of the grid, as on the to-do page: an icon in the avatar's
/// glowing ring, and a line on what to do next. When there are no notes, or
/// when a search finds none.
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 88,
              child: AvatarHalo(
                child: CustomPaint(
                  painter: const _RingPainter(),
                  child: Icon(
                    searching ? Icons.search_rounded : Icons.edit_note_rounded,
                    size: 38,
                    color: context.colors.moreLess,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
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
                            Icons.add_rounded,
                            size: 19,
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
    );
  }
}

/// The avatar's gradient ring, with the light blue highlight at the top left.
class _RingPainter extends CustomPainter {
  const _RingPainter();

  static const _width = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawCircle(
      rect.center,
      (size.shortestSide - _width) / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _width
        ..shader = const SweepGradient(
          colors: [_accent, _highlight, _accent],
          transform: GradientRotation(math.pi / 4),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => false;
}
