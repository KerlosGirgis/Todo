import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/extensions/theme_extensions.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

/// The round check at the start of a task's card, or of a line of a note's
/// checklist: an empty ring for something to do, filled with the app's
/// blues and ticked once it's done, part way between the two as [doneness]
/// goes from 0 to 1.
class CheckCircle extends StatelessWidget {
  const CheckCircle({
    super.key,
    required this.doneness,
    this.size = defaultSize,
  });

  /// The size on a task's card.
  static const defaultSize = 26.0;

  final double doneness;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      size: Size.square(size),
      painter: _CheckPainter(
        doneness: doneness,
        ring: context.colors.wB.withValues(alpha: isDarkTheme ? 0.3 : 0.22),
        glow: isDarkTheme,
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.doneness,
    required this.ring,
    required this.glow,
  });

  final double doneness;
  final Color ring;

  /// Whether the fill glows, which only shows up on dark pages.
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    // Its lines keep their weight against its size.
    final scale = size.shortestSide / CheckCircle.defaultSize;
    if (doneness < 1) {
      canvas.drawCircle(
        center,
        radius - scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * scale
          ..color = ring.withValues(alpha: ring.a * (1 - doneness)),
      );
    }
    if (doneness <= 0) return;

    // Grows in from the middle, swelling a little past full size on the
    // way, so it pops.
    final fillRadius = radius * (0.6 + 0.4 * doneness) +
        radius * 0.12 * math.sin(math.pi * doneness);
    final opacity = math.min(1.0, doneness * 1.6);
    final rect = Rect.fromCircle(center: center, radius: fillRadius);
    if (glow) {
      canvas.drawCircle(
        center,
        fillRadius,
        Paint()
          ..color = _accent.withValues(alpha: 0.5 * opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * scale),
      );
    }
    canvas.drawCircle(
      center,
      fillRadius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withValues(alpha: opacity),
            _highlight.withValues(alpha: opacity),
          ],
        ).createShader(rect),
    );

    // The tick draws itself once the circle has mostly filled.
    final tick = ((doneness - 0.4) / 0.6).clamp(0.0, 1.0);
    if (tick <= 0) return;
    final width = size.width;
    final height = size.height;
    final path = Path()
      ..moveTo(width * 0.29, height * 0.52)
      ..lineTo(width * 0.44, height * 0.67)
      ..lineTo(width * 0.72, height * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * tick),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.doneness != doneness ||
      oldDelegate.ring != ring ||
      oldDelegate.glow != glow;
}
