import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/utils/task_labels.dart';
import '../../../../../view_model/notes_view_model.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../widgets/profile_card.dart';
import '../../../../widgets/progress_ring.dart';

/// How far through their tasks the user is, as a ring that fills up, with
/// their counts of finished and remaining tasks, and of notes, below it.
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final (done, remaining) = context.select<TasksViewModel, (int, int)>(
      (tasks) => (tasks.finishedTasksCount, tasks.unfinishedTasksCount),
    );
    final notes = context.select<NotesViewModel, int>(
      (notes) => notes.notes.length,
    );
    final total = done + remaining;
    final progress = total == 0 ? 0.0 : done / total;
    final (headline, detail) = describeTaskProgress(done, total);
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
                      ProgressRing(progress: value),
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
                Expanded(
                  child: _Stat(count: done, label: "Completed"),
                ),
                _divider(hairline),
                Expanded(
                  child: _Stat(count: remaining, label: "Remaining"),
                ),
                _divider(hairline),
                Expanded(
                  child: _Stat(count: notes, label: "Notes"),
                ),
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
