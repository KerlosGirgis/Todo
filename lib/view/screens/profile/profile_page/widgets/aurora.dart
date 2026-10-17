import 'package:flutter/material.dart';

import '../../../../../core/extensions/theme_extensions.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);
const _violet = Color(0xff7C4DFF);

/// Soft glows of the app's blues behind the top of the profile page, which
/// melt into the page's background further down.
class ProfileAurora extends StatelessWidget {
  const ProfileAurora({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _AuroraPainter(
          // Colour carries further on a light page, so it's toned down there.
          strength: isDarkTheme ? 1 : 0.6,
          background: context.colors.pageBackground,
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({required this.strength, required this.background});

  final double strength;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    void glow(Offset center, double radius, Color color, double alpha) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha * strength),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final width = size.width;
    final height = size.height;
    glow(Offset(width * 0.1, height * 0.2), width * 0.85, _accent, 0.42);
    glow(Offset(width * 0.95, height * 0.08), width * 0.7, _highlight, 0.3);
    glow(Offset(width * 0.55, height * 0.62), width * 0.6, _violet, 0.2);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [background.withValues(alpha: 0), background],
          stops: const [0.45, 1],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.strength != strength || oldDelegate.background != background;
}
