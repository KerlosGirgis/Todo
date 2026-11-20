import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../widgets/ringed_avatar.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

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
    // No message for no tasks at all: it's a line with the add button's
    // icon in it.
    final (icon, title, message) = switch (reason) {
      EmptyTasksReason.noTasks => (Icons.checklist_rounded, "No Tasks", null),
      EmptyTasksReason.noneDone => (
          Icons.task_alt_rounded,
          "Nothing Done Yet",
          "Tasks you check off will show up here.",
        ),
      EmptyTasksReason.allDone => (
          Icons.celebration_rounded,
          "All Caught Up",
          "Every task is checked off. Enjoy the free time!",
        ),
      EmptyTasksReason.noneDaily => (
          Icons.today_rounded,
          "No Daily Tasks",
          "Tasks that repeat every day will show up here.",
        ),
      EmptyTasksReason.noneWeekly => (
          Icons.date_range_rounded,
          "No Weekly Tasks",
          "Tasks that repeat every week will show up here.",
        ),
      EmptyTasksReason.noneMonthly => (
          Icons.calendar_month_rounded,
          "No Monthly Tasks",
          "Tasks that repeat every month will show up here.",
        ),
      EmptyTasksReason.noneOnce => (
          Icons.looks_one_outlined,
          "No One-Time Tasks",
          "Tasks that don't repeat will show up here.",
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
            if (message != null)
              Text(message, textAlign: TextAlign.center, style: secondary)
            else
              Text.rich(
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
