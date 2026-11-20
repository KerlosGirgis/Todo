import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../models/task_filters.dart';
import '../../../../../models/task_sort.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../widgets/glass.dart';
import '../../../../widgets/glass_popover.dart';

/// What each filter is called, and its icon, in the order they're offered:
/// by how far along the tasks are, then by how often they come round.
const _filters = <TaskFilter, (String, IconData)>{
  TaskFilter.all: ("All", Icons.checklist_rounded),
  TaskFilter.done: ("Done", Icons.task_alt_rounded),
  TaskFilter.undone: ("Undone", Icons.radio_button_unchecked_rounded),
  TaskFilter.daily: ("Daily", Icons.today_rounded),
  TaskFilter.weekly: ("Weekly", Icons.date_range_rounded),
  TaskFilter.monthly: ("Monthly", Icons.calendar_month_rounded),
  TaskFilter.once: ("Once", Icons.looks_one_outlined),
};

/// How [sort] reads, [direction] first.
String _sortLabel(TaskSort sort, SortDirection direction) => switch (sort) {
      TaskSort.custom => "Custom",
      TaskSort.dueDate => switch (direction) {
          SortDirection.ascending => "Due Date, Earliest First",
          SortDirection.descending => "Due Date, Latest First",
        },
    };

enum _Panel { sort, filter }

/// The tasks' sort and filter buttons, side by side in one glass capsule.
/// Each opens a glass panel of choices, over it at the bottom of the
/// screen, and lights up while it's set to anything but the usual: the
/// user's own order, and all the tasks.
class SortFilterButtons extends StatefulWidget {
  const SortFilterButtons({
    super.key,
    required this.onSort,
    required this.onFilter,
  });

  /// Sorts the tasks as chosen.
  final void Function(TaskSort sort, SortDirection direction) onSort;

  /// Shows only the tasks the filter chosen lets through.
  final ValueChanged<TaskFilter> onFilter;

  /// How tall they are, as the map's round buttons are.
  static const height = 38.0;

  @override
  State<SortFilterButtons> createState() => _SortFilterButtonsState();
}

class _SortFilterButtonsState extends State<SortFilterButtons> {
  /// The panel that's open, if one is, and the one on show, which stays
  /// while it closes.
  _Panel? _open;
  _Panel _shown = _Panel.sort;

  /// What was chosen as the panel opened, which it shows until it's gone:
  /// a choice closes it, rather than moving its check as it fades.
  (TaskFilter, TaskSort, SortDirection) _chosen =
      (TaskFilter.all, TaskSort.custom, SortDirection.ascending);

  void _openPanel(_Panel panel) {
    final tasks = context.read<TasksViewModel>();
    setState(() {
      _open = panel;
      _shown = panel;
      _chosen = (tasks.filter, tasks.sort, tasks.sortDirection);
    });
  }

  void _close() {
    if (_open != null) setState(() => _open = null);
  }

  @override
  Widget build(BuildContext context) {
    final (filter, sort, direction) =
        context.select<TasksViewModel, (TaskFilter, TaskSort, SortDirection)>(
            (tasks) => (tasks.filter, tasks.sort, tasks.sortDirection));
    final ink = context.colors.wB;
    final (chosenFilter, chosenSort, chosenDirection) = _chosen;
    return GlassPopover(
      open: _open != null,
      onClose: _close,
      label: switch (_shown) {
        _Panel.sort => "Sort",
        _Panel.filter => "Filter",
      },
      panel: (context) => switch (_shown) {
        _Panel.sort => _SortPanel(
            sort: chosenSort,
            direction: chosenDirection,
            onSort: (sort, direction) {
              _close();
              widget.onSort(sort, direction);
            },
          ),
        _Panel.filter => _FilterPanel(
            filter: chosenFilter,
            onFilter: (filter) {
              _close();
              widget.onFilter(filter);
            },
          ),
      },
      child: Glass(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CapsuleButton(
              icon: Icons.swap_vert_rounded,
              tooltip: "Sort",
              value: _sortLabel(sort, direction),
              lit: sort != TaskSort.custom,
              pressed: _open == _Panel.sort,
              onPressed: () => _openPanel(_Panel.sort),
            ),
            SizedBox(
              width: 1,
              height: 18,
              child: ColoredBox(color: ink.withValues(alpha: 0.14)),
            ),
            _CapsuleButton(
              icon: filter == TaskFilter.all
                  ? Icons.filter_alt_outlined
                  : Icons.filter_alt_rounded,
              tooltip: "Filter",
              value: _filters[filter]!.$1,
              lit: filter != TaskFilter.all,
              pressed: _open == _Panel.filter,
              onPressed: () => _openPanel(_Panel.filter),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the capsule's buttons: in the accent, with a dot, while it's
/// [lit], and highlighted while its panel is open.
class _CapsuleButton extends StatelessWidget {
  const _CapsuleButton({
    required this.icon,
    required this.tooltip,
    required this.value,
    required this.lit,
    required this.pressed,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;

  /// What it's set to, for a screen reader.
  final String value;
  final bool lit;
  final bool pressed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final accent = context.colors.moreLess;
    // Its name and what it's set to, as "Sort, Custom", in one node, in
    // place of the tooltip's and the ink's, which say less.
    return Semantics(
      container: true,
      button: true,
      label: tooltip,
      value: value,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 42,
          height: SortFilterButtons.height,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              customBorder: const StadiumBorder(),
              splashFactory: NoSplash.splashFactory,
              highlightColor: ink.withValues(alpha: 0.1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(3),
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: ink.withValues(alpha: pressed ? 0.1 : 0),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: 21, color: lit ? accent : ink),
                    if (lit)
                      PositionedDirectional(
                        top: 4,
                        end: 5,
                        child: SizedBox.square(
                          dimension: 6,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              shape: const CircleBorder(),
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sort's choices: the user's own order, or by due date, and then,
/// once it's by due date, which way.
class _SortPanel extends StatelessWidget {
  const _SortPanel({
    required this.sort,
    required this.direction,
    required this.onSort,
  });

  final TaskSort sort;
  final SortDirection direction;
  final void Function(TaskSort sort, SortDirection direction) onSort;

  @override
  Widget build(BuildContext context) {
    final byDate = sort == TaskSort.dueDate;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GlassPopoverHeader("Sort By"),
        GlassPopoverOption(
          icon: Icons.drag_indicator_rounded,
          label: "Custom",
          selected: !byDate,
          onTap: () => onSort(TaskSort.custom, direction),
        ),
        GlassPopoverOption(
          icon: Icons.calendar_today_rounded,
          label: "Due Date",
          selected: byDate,
          onTap: () => onSort(TaskSort.dueDate, direction),
        ),
        if (byDate) ...[
          const GlassPopoverDivider(),
          GlassPopoverOption(
            icon: Icons.arrow_upward_rounded,
            label: "Earliest First",
            selected: direction == SortDirection.ascending,
            onTap: () => onSort(TaskSort.dueDate, SortDirection.ascending),
          ),
          GlassPopoverOption(
            icon: Icons.arrow_downward_rounded,
            label: "Latest First",
            selected: direction == SortDirection.descending,
            onTap: () => onSort(TaskSort.dueDate, SortDirection.descending),
          ),
        ],
      ],
    );
  }
}

/// The filters, each with how many tasks it lets through, subtasks
/// included.
class _FilterPanel extends StatelessWidget {
  const _FilterPanel({required this.filter, required this.onFilter});

  final TaskFilter filter;
  final ValueChanged<TaskFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    Widget option(TaskFilter each) {
      final (label, icon) = _filters[each]!;
      return GlassPopoverOption(
        icon: icon,
        label: label,
        count:
            context.select<TasksViewModel, int>((tasks) => tasks.countOf(each)),
        selected: each == filter,
        onTap: () => onFilter(each),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GlassPopoverHeader("Show"),
        for (final each in [TaskFilter.all, TaskFilter.done, TaskFilter.undone])
          option(each),
        const GlassPopoverDivider(),
        for (final each in [
          TaskFilter.daily,
          TaskFilter.weekly,
          TaskFilter.monthly,
          TaskFilter.once,
        ])
          option(each),
      ],
    );
  }
}
