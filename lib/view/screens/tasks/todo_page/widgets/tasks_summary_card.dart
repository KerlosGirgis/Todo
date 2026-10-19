import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../widgets/progress_ring.dart';
import '../../../profile/profile_page/widgets/profile_card.dart';
import '../../../profile/profile_page/widgets/progress_card.dart';

/// How far through their tasks the user is, beside a smaller copy of the
/// profile page's progress ring, and in the same words.
class TasksSummaryCard extends StatelessWidget {
  const TasksSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final (done, remaining) = context.select<TasksViewModel, (int, int)>(
        (tasks) => (tasks.finishedTasksCount, tasks.unfinishedTasksCount));
    final total = done + remaining;
    final (headline, detail) = describeTaskProgress(done, total);
    return ProfileCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 20, 16),
        child: Row(
          children: [
            // Fills up from empty as the page opens, then follows the counts
            // as tasks get done.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: total == 0 ? 0.0 : done / total),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) =>
                  ProgressRing(progress: value, size: 68),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "YOUR PROGRESS",
                    style: TextStyle(
                      color: context.colors.moreLess,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    headline,
                    style: TextStyle(
                      color: context.colors.wB,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
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
    );
  }
}
