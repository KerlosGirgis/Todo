import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/extensions/theme_extensions.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

/// How far through their tasks the user is, as a ring that fills with the
/// app's blues, with the percentage in its middle. Its stroke and text keep
/// their proportions at any [size].
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, this.size = 104});

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    // Proportions of the profile page's 104-point ring.
    final scale = size / 104;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          width: 11 * scale,
          track: context.colors.wB.withValues(alpha: isDarkTheme ? 0.1 : 0.07),
          glow: isDarkTheme,
        ),
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          // Shrinks rather than overflowing the ring at large text sizes.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "${(progress * 100).round()}%",
              style: TextStyle(
                color: context.colors.wB,
                fontSize: 24 * scale,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.6 * scale,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.width,
    required this.track,
    required this.glow,
  });

  final double progress;
  final double width;
  final Color track;

  /// Whether the arc glows, which only shows up on dark pages.
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - width) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = track,
    );
    if (progress <= 0) return;

    const start = -math.pi / 2;
    final sweep = 2 * math.pi * math.min(progress, 1.0);
    final rect = Rect.fromCircle(center: center, radius: radius);
    Offset pointAt(double angle) =>
        center + Offset(math.cos(angle), math.sin(angle)) * radius;

    if (glow) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = _accent.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 7 / 11),
      );
    }
    // From the accent at the start to the highlight at the end, like the
    // avatar's ring.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = SweepGradient(
          endAngle: sweep,
          colors: const [_accent, _highlight],
          transform: const GradientRotation(start),
        ).createShader(rect),
    );
    // Round ends drawn as dots, each in its own end's colour: a round cap
    // at the start would wrap around to the far end of the gradient.
    canvas.drawCircle(pointAt(start), width / 2, Paint()..color = _accent);
    final end = pointAt(start + sweep);
    // As the ring closes, a shadow lifts its end over its start, as on
    // Apple's activity rings.
    final closing = ((progress - 0.9) / 0.1).clamp(0.0, 1.0);
    if (closing > 0) {
      canvas.drawCircle(
        end,
        width / 2,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35 * closing)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 3 / 11),
      );
    }
    canvas.drawCircle(end, width / 2, Paint()..color = _highlight);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.width != width ||
      oldDelegate.track != track ||
      oldDelegate.glow != glow;
}
