import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A frosted, translucent surface in the style of Apple's glass materials:
/// it blurs whatever is behind it, tints it, and draws a thin bright rim.
class Glass extends StatelessWidget {
  const Glass(
      {super.key, required this.child, this.shape = const StadiumBorder()});

  final Widget child;
  final ShapeBorder shape;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _ShadowPainter(
        shape: shape,
        color: Colors.black.withValues(alpha: isDarkTheme ? 0.45 : 0.12),
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: CustomPaint(
            foregroundPainter: _RimPainter(shape: shape, isDark: isDarkTheme),
            child: ColoredBox(
              color: isDarkTheme
                  ? const Color(0xff2C2C2E).withValues(alpha: 0.62)
                  : Colors.white.withValues(alpha: 0.72),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft shadow under the glass, only outside its shape so it doesn't grey
/// the glass itself. A [BoxShadow] with [BlurStyle.outer] keeps clear of the
/// offset shadow's own outline instead of the glass's, which leaves a light
/// sliver right under the glass, where the shadow should be darkest.
class _ShadowPainter extends CustomPainter {
  const _ShadowPainter({required this.shape, required this.color});

  static const _blurRadius = 20.0;

  final ShapeBorder shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final outline = shape.getOuterPath(bounds);
    canvas.save();
    canvas.clipPath(Path.combine(
      PathOperation.difference,
      Path()..addRect(bounds.inflate(_blurRadius * 3)),
      outline,
    ));
    canvas.drawPath(
      outline.shift(const Offset(0, 4)),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(
            BlurStyle.normal, Shadow.convertRadiusToSigma(_blurRadius)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}

class _RimPainter extends CustomPainter {
  const _RimPainter({required this.shape, required this.isDark});

  final ShapeBorder shape;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawPath(
      shape.getOuterPath(rect.deflate(0.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        // Lit from above: bright at the top edge, fading towards the bottom.
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.24),
                  Colors.white.withValues(alpha: 0.06),
                ]
              : [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.black.withValues(alpha: 0.07),
                ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.isDark != isDark;
}
