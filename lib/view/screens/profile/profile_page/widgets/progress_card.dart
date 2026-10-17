import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../view_model/notes_view_model.dart';
import '../../../../../view_model/tasks_view_model.dart';
import 'profile_card.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

/// How far through their tasks the user is, as a ring that fills up, with
/// their counts of finished and remaining tasks, and of notes, below it.
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final (done, remaining) = context.select<TasksViewModel, (int, int)>(
        (tasks) => (tasks.finishedTasksCount, tasks.unfinishedTasksCount));
    final notes =
        context.select<NotesViewModel, int>((notes) => notes.notes.length);
    final total = done + remaining;
    final progress = total == 0 ? 0.0 : done / total;
    final (headline, detail) = switch (progress) {
      _ when total == 0 => ("No tasks yet", "Add a task to get started."),
      1.0 => ("All done", "You've finished every task. Nice work!"),
      >= 0.75 => ("Almost there", "$done of ${_tasks(total)} done"),
      >= 0.5 => ("Halfway there", "$done of ${_tasks(total)} done"),
      > 0 => ("Off to a good start", "$done of ${_tasks(total)} done"),
      _ => ("Ready to begin", "${_tasks(total)} waiting for you"),
    };
    final hairline = context.colors.wB.withValues(alpha: 0.1);

    return ProfileCard(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Row(
              children: [
                // Fills up from empty as the page opens, then follows the
                // counts as they change.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) =>
                      _ProgressRing(progress: value),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TASK PROGRESS",
                        style: TextStyle(
                          color: context.colors.moreLess,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        headline,
                        style: TextStyle(
                          color: context.colors.wB,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: TextStyle(
                          color: context.colors.wB.withValues(alpha: 0.55),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0.5, thickness: 0.5, color: hairline),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _Stat(count: done, label: "Completed")),
                _divider(hairline),
                Expanded(child: _Stat(count: remaining, label: "Remaining")),
                _divider(hairline),
                Expanded(child: _Stat(count: notes, label: "Notes")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(Color color) => VerticalDivider(
        width: 0.5,
        thickness: 0.5,
        indent: 14,
        endIndent: 14,
        color: color,
      );
}

String _tasks(int count) => count == 1 ? "1 task" : "$count tasks";

/// A count that ticks up to its value, over its label.
class _Stat extends StatelessWidget {
  const _Stat({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "$count $label",
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: count.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Text(
                "${value.round()}",
                style: TextStyle(
                  color: context.colors.wB,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.wB.withValues(alpha: 0.5),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: 104,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          track: context.colors.wB.withValues(alpha: isDarkTheme ? 0.1 : 0.07),
          glow: isDarkTheme,
        ),
        child: Center(
          child: Text(
            "${(progress * 100).round()}%",
            style: TextStyle(
              color: context.colors.wB,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(
      {required this.progress, required this.track, required this.glow});

  static const _width = 11.0;

  final double progress;
  final Color track;

  /// Whether the arc glows, which only shows up on dark pages.
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _width) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _width
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
          ..strokeWidth = _width
          ..strokeCap = StrokeCap.round
          ..color = _accent.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
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
        ..strokeWidth = _width
        ..shader = SweepGradient(
          endAngle: sweep,
          colors: const [_accent, _highlight],
          transform: const GradientRotation(start),
        ).createShader(rect),
    );
    // Round ends drawn as dots, each in its own end's colour: a round cap
    // at the start would wrap around to the far end of the gradient.
    canvas.drawCircle(pointAt(start), _width / 2, Paint()..color = _accent);
    final end = pointAt(start + sweep);
    // As the ring closes, a shadow lifts its end over its start, as on
    // Apple's activity rings.
    final closing = ((progress - 0.9) / 0.1).clamp(0.0, 1.0);
    if (closing > 0) {
      canvas.drawCircle(
        end,
        _width / 2,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35 * closing)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawCircle(end, _width / 2, Paint()..color = _highlight);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.glow != glow;
}
