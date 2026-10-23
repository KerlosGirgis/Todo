import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../models/task_filters.dart';
import '../../../../../view_model/tasks_view_model.dart';

const _filters = <TaskFilter>[
  AllTasksFilter(),
  DoneTasksFilter(),
  UndoneTasksFilter(),
];

/// A segmented control of the filters for the list, each with how many tasks
/// it lets through, like the profile page's own segmented controls.
class TaskFilterBar extends StatelessWidget {
  const TaskFilterBar({super.key, required this.onChanged});

  final ValueChanged<TaskFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final (filter, done, remaining) =
        context.select<TasksViewModel, (Type, int, int)>((tasks) => (
              tasks.currentFilter.runtimeType,
              tasks.finishedTasksCount,
              tasks.unfinishedTasksCount,
            ));
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: _filters.indexWhere((each) => each.runtimeType == filter),
        onValueChanged: (index) {
          if (index != null) onChanged(_filters[index]);
        },
        children: {
          0: _Segment(label: "All", count: done + remaining),
          1: _Segment(label: "Done", count: done),
          2: _Segment(label: "Undone", count: remaining),
        },
      ),
    );
  }
}

/// A segment's label, followed by its count in a lighter shade.
class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: label),
            TextSpan(
              text: "  $count",
              style: TextStyle(
                color: context.colors.wB.withValues(alpha: 0.45),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14.5),
      ),
    );
  }
}
