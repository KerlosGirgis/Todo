import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/utils/avatar_utils.dart';

const _accent = Color(0xff3D5AFE);

/// The user's avatar inside the app's gradient ring. It takes its size from
/// its parent and keeps its proportions at any size, so it also flies
/// smoothly between sizes in a [Hero].
class RingedAvatar extends StatelessWidget {
  const RingedAvatar({super.key, required this.pic});

  /// A bundled avatar number such as "000", or the path of a picked photo.
  final String pic;

  @override
  Widget build(BuildContext context) {
    final ImageProvider image = pic.startsWith("0")
        ? AssetImage(AvatarUtils.getAvatar(pic))
        : FileImage(File(pic));
    return LayoutBuilder(
      builder: (context, constraints) {
        final ringWidth =
            math.max(2.0, constraints.biggest.shortestSide * 0.035);
        return CustomPaint(
          painter: _RingPainter(width: ringWidth),
          child: Padding(
            // Leaves a see-through gap between the ring and the photo.
            padding: EdgeInsets.all(ringWidth * 2),
            child: ClipOval(
              child: DecoratedBox(
                // Shows behind avatars drawn on a transparent background.
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xffE8EAF6), Color(0xffC5CAE9)],
                  ),
                ),
                // Some bundled avatars are circles with a thin transparent
                // rim; a slight zoom fills the frame with them.
                child: Transform.scale(
                  scale: 1.05,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      image: DecorationImage(image: image, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A soft glow of the accent colour that spills past [child] on every side.
class AvatarHalo extends StatelessWidget {
  const AvatarHalo({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final spread = constraints.biggest.shortestSide * 0.29;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              left: -spread,
              top: -spread,
              right: -spread,
              bottom: -spread,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accent.withValues(alpha: isDarkTheme ? 0.32 : 0.18),
                      _accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: child),
          ],
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.width});

  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawCircle(
      rect.center,
      (size.shortestSide - width) / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = const SweepGradient(
          colors: [_accent, Color(0xff40C4FF), _accent],
          // Puts the light blue highlight at the top left.
          transform: GradientRotation(math.pi / 4),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.width != width;
}
