import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../models/trashed.dart';
import '../../../../widgets/ringed_avatar.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

/// Shown in place of the trash's list, as on the to-do and notes pages: an
/// icon in the avatar's glowing ring, and a line on what the trash is for.
class EmptyTrash extends StatelessWidget {
  const EmptyTrash({super.key, required this.kind});

  /// Whether it's the deleted tasks there are none of, or the notes.
  final TrashKind kind;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (kind) {
      TrashKind.task => (
          "No Deleted Tasks",
          "Tasks you delete wait here until you restore them or delete "
              "them forever.",
        ),
      TrashKind.note => (
          "No Deleted Notes",
          "Notes you delete wait here until you restore them or delete "
              "them forever.",
        ),
    };
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
                    Icons.delete_outline_rounded,
                    size: 38,
                    color: context.colors.moreLess,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.wB,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.wB.withValues(alpha: 0.55),
                fontSize: 15,
                height: 1.35,
                letterSpacing: -0.15,
              ),
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
