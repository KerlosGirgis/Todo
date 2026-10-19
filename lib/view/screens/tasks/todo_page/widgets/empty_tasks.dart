import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../widgets/ringed_avatar.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

/// Why the list is empty.
enum EmptyTasksReason {
  /// There are no tasks at all.
  noTasks,

  /// The Done filter is on, and no task is done yet.
  noneDone,

  /// The Undone filter is on, and every task is done.
  allDone,
}

/// Shown in place of the list: an icon in the avatar's glowing ring, and a
/// line on what to do next.
class EmptyTasks extends StatelessWidget {
  const EmptyTasks({super.key, required this.reason});

  final EmptyTasksReason reason;

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(
      color: context.colors.wB.withValues(alpha: 0.55),
      fontSize: 15,
      height: 1.35,
      letterSpacing: -0.15,
    );
    final (icon, title) = switch (reason) {
      EmptyTasksReason.noTasks => (Icons.checklist_rounded, "No Tasks"),
      EmptyTasksReason.noneDone => (Icons.task_alt_rounded, "Nothing Done Yet"),
      EmptyTasksReason.allDone => (Icons.celebration_rounded, "All Caught Up"),
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
                  child: Icon(icon, size: 38, color: context.colors.moreLess),
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
            switch (reason) {
              EmptyTasksReason.noTasks => Text.rich(
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
                      const TextSpan(text: " to add your first task."),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: secondary,
                ),
              EmptyTasksReason.noneDone => Text(
                  "Tasks you check off will show up here.",
                  textAlign: TextAlign.center,
                  style: secondary,
                ),
              EmptyTasksReason.allDone => Text(
                  "Every task is checked off. Enjoy the free time!",
                  textAlign: TextAlign.center,
                  style: secondary,
                ),
            },
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
