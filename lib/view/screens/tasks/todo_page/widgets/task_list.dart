import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../models/task_tree.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/rise_in.dart';
import 'task_card.dart';

/// The gap between cards.
const _cardGap = 12.0;

/// How far a subtask's card starts in from the card of the task it's in:
/// by this much a task deep at first, then by less, so tasks many deep
/// still have room for their titles.
double _indentOf(int depth) => math.min(
    136, depth <= 4 ? depth * _indent : 4 * _indent + (depth - 4) * 8.0);
const _indent = 22.0;

/// The tasks as cards, each task's subtasks under it, a step in from it. A
/// task's subtasks fold away under it, and go with it when it's dragged to
/// another place or swiped away.
class TaskList extends StatefulWidget {
  const TaskList({
    super.key,
    required this.tasks,
    required this.listDelay,
    required this.onEdit,
    required this.onAddSubtask,
    required this.onDelete,
    required this.onResult,
    required this.firstCardKey,
  });

  final TasksViewModel tasks;

  /// How many sections rise in ahead of the first card, as the list opens.
  final int listDelay;

  /// Opens the editor for the task.
  final ValueChanged<TodoItem> onEdit;

  /// Opens the form for a new subtask of the task.
  final ValueChanged<TodoItem> onAddSubtask;

  /// Moves the task to the trash, with the tasks in it.
  final ValueChanged<TodoItem> onDelete;

  /// Shows how something the list asked for went, if there's anything to
  /// say.
  final ValueChanged<Result?> onResult;

  /// The key for the first card, if it's to have one.
  final GlobalKey? firstCardKey;

  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  /// Whether the list is being laid out for the first time, when the cards in
  /// view rise in one after another.
  bool _opening = true;

  /// The tasks listed at the last build, so a task added since can rise in
  /// by itself.
  Set<String> _listed = {};

  /// The task being dragged or swiped away, by its key, whose subtasks fold
  /// away under it until it's dropped or gone: they go with it.
  String? _carried;

  /// Where the carried task was picked up from, if it's being dragged.
  int? _draggedFrom;

  /// Brings the carried task's subtasks back out should its drag end without
  /// the list hearing of it, as one that's cancelled does: once the finger
  /// that's being watched for lifts.
  Timer? _letGo;
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _opening = false);
  }

  @override
  void dispose() {
    _letGo?.cancel();
    _watch(false);
    super.dispose();
  }

  /// Starts watching for the finger to lift, wherever it is on the screen,
  /// or stops.
  void _watch(bool watching) {
    if (watching == _watching) return;
    _watching = watching;
    final router = GestureBinding.instance.pointerRouter;
    if (watching) {
      router.addGlobalRoute(_watchForRelease);
    } else {
      router.removeGlobalRoute(_watchForRelease);
    }
  }

  /// Folds the subtasks of the task with [key] away under it, as it's
  /// picked up from [index], or swiped away.
  void _carry(String key, {int? index}) {
    _letGo?.cancel();
    _watch(index != null);
    setState(() {
      _carried = key;
      _draggedFrom = index;
    });
  }

  /// Brings the carried task's subtasks back out, wherever it is now.
  void _putDown() {
    _letGo?.cancel();
    _watch(false);
    if (!mounted || _carried == null) return;
    setState(() {
      _carried = null;
      _draggedFrom = null;
    });
  }

  /// Once the finger lifts, the card is dropped, or its drag is cancelled,
  /// which the list doesn't say: its subtasks are back out by the time a
  /// drop has settled either way.
  void _watchForRelease(PointerEvent event) {
    if (event is! PointerUpEvent && event is! PointerCancelEvent) return;
    _letGo?.cancel();
    _letGo = Timer(const Duration(milliseconds: 600), _putDown);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    // The tasks are in their new order before it's saved, so the subtasks
    // come back out where the task now is.
    final moving = widget.tasks.syncAfterReorder(oldIndex, newIndex);
    _putDown();
    await moving;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final nodes = tasks.tree.nodes;
    final listed = {for (final node in nodes) node.key};
    final added = _opening ? const <String>{} : listed.difference(_listed);
    _listed = listed;
    // A task is out of sight while any task it's inside of is folded, or
    // being carried.
    final hidden = List.filled(nodes.length, false);
    final position = List.filled(nodes.length, 0);
    int? foldedAt;
    var shown = 0;
    for (final (index, node) in nodes.indexed) {
      if (foldedAt != null && node.depth <= foldedAt) foldedAt = null;
      hidden[index] = foldedAt != null;
      position[index] = shown;
      if (foldedAt != null) continue;
      shown++;
      if (node.children.isNotEmpty &&
          (node.task.folded || node.key == _carried)) {
        foldedAt = node.depth;
      }
    }
    final (titleScale, descriptionScale, descriptionLines) =
        context.select<UserViewModel, (double, double, int)>((user) => (
              user.user.tasksTitleSize,
              user.user.tasksDescSize,
              user.user.descLines,
            ));

    TaskCard card(TaskNode node, {bool interactive = true}) {
      final task = node.task;
      return TaskCard(
        task: task,
        titleScale: titleScale,
        descriptionScale: descriptionScale,
        descriptionLines: descriptionLines,
        subtasks: node.subtaskCount == 0
            ? null
            : (done: node.doneSubtaskCount, total: node.subtaskCount),
        onToggle: !interactive
            ? null
            : () => tasks.toggleDone(task).then(widget.onResult),
        onEdit: !interactive ? null : () => widget.onEdit(task),
        onReminder: !interactive
            ? null
            : () => tasks.toggleReminder(task).then(widget.onResult),
        // Only while it has no reminder: the bell's tap turns one off.
        onDailyReminder: !interactive || task.reminder != Reminder.none
            ? null
            : () => tasks.remindDaily(task).then(widget.onResult),
        // Only with subtasks the filter lets through, to fold away.
        onFold: !interactive || node.children.isEmpty
            ? null
            : () => tasks.setFolded(task, !task.folded),
      );
    }

    return SliverReorderableList(
      itemCount: nodes.length,
      onReorderStart: (index) {
        HapticFeedback.mediumImpact();
        _carry(nodes[index].key, index: index);
      },
      // Where it was picked up, or the place under that, is no move at all,
      // which the list doesn't report.
      onReorderEnd: (index) {
        final from = _draggedFrom;
        if (from != null && (index == from || index == from + 1)) _putDown();
      },
      onReorderItem: _reorder,
      // The card being dragged is drawn again, without its entrance or its
      // swipe, which would start over in the drag's overlay.
      proxyDecorator: (child, index, animation) => _LiftedCard(
        animation: animation,
        indent: _indentOf(nodes[index].depth),
        child: card(nodes[index], interactive: false),
      ),
      itemBuilder: (context, index) {
        final node = nodes[index];
        final task = node.task;
        final key = node.key;
        return ReorderableDelayedDragStartListener(
          key: ValueKey(key),
          index: index,
          child: _Foldable(
            shown: !hidden[index],
            // A task added since the list opened makes room for itself.
            unfolds: added.contains(key),
            child: _Indented(
              depth: node.depth,
              child: RiseIn(
                animate: _opening || added.contains(key),
                delay: _opening
                    ? RiseIn.stagger *
                        (widget.listDelay + math.min(position[index], 8))
                    : Duration.zero,
                child: Dismissible(
                  key: ValueKey(key),
                  // A shorter swipe for a subtask, as nothing goes away.
                  dismissThresholds: const {
                    DismissDirection.startToEnd: 0.25,
                  },
                  background: const TaskSubtaskBackground(
                      alignment: AlignmentDirectional.centerStart),
                  secondaryBackground: const TaskDeleteBackground(
                      alignment: AlignmentDirectional.centerEnd),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      // The card stays, and gets a subtask.
                      widget.onAddSubtask(task);
                      return false;
                    }
                    _carry(key);
                    return true;
                  },
                  onDismissed: (direction) {
                    _putDown();
                    widget.onDelete(task);
                  },
                  child: KeyedSubtree(
                    key: index == 0 ? widget.firstCardKey : null,
                    child: card(node),
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

/// A row of the list, which folds away to nothing while it's not [shown],
/// as a subtask does when the task it's in is folded, and comes back out
/// when it is.
class _Foldable extends StatefulWidget {
  const _Foldable({
    required this.shown,
    required this.unfolds,
    required this.child,
  });

  final bool shown;

  /// Whether it comes out as it's first built, rather than being there
  /// already.
  final bool unfolds;
  final Widget child;

  @override
  State<_Foldable> createState() => _FoldableState();
}

class _FoldableState extends State<_Foldable>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: widget.shown && !widget.unfolds ? 1 : 0,
  );
  late final _size =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  late final _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    if (widget.shown && widget.unfolds) _controller.forward();
  }

  @override
  void didUpdateWidget(_Foldable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shown == oldWidget.shown) return;
    if (widget.shown) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Not there at all once it's folded away.
        if (_controller.isDismissed) return const SizedBox.shrink();
        final settled = _controller.isCompleted;
        return IgnorePointer(
          ignoring: !widget.shown,
          child: ClipRect(
            // Out of the way once it's all there, as it would cut the
            // card's shadow off.
            clipper: const _RowClipper(),
            clipBehavior: settled ? Clip.none : Clip.hardEdge,
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: settled ? 1 : _size.value,
              child: FadeTransition(opacity: _fade, child: child),
            ),
          ),
        );
      },
      child: ExcludeSemantics(excluding: !widget.shown, child: widget.child),
    );
  }
}

/// Cuts a row off at its top and bottom as it folds, but not at its sides,
/// where its card's shadow is.
class _RowClipper extends CustomClipper<Rect> {
  const _RowClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-48, 0, size.width + 48, size.height);

  @override
  bool shouldReclip(_RowClipper oldClipper) => false;
}

/// A card a step in from the start of the list for each task it's inside
/// of, with a faint line down each step, which runs on through the cards
/// under it: the subtasks of one task line up along one line.
class _Indented extends StatelessWidget {
  const _Indented({required this.depth, required this.child});

  final int depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding:
          EdgeInsetsDirectional.only(start: _indentOf(depth), bottom: _cardGap),
      child: child,
    );
    if (depth == 0) return padded;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _GuidesPainter(
        depth: depth,
        color: context.colors.wB.withValues(alpha: isDarkTheme ? 0.16 : 0.11),
        rightToLeft: Directionality.of(context) == TextDirection.rtl,
      ),
      child: padded,
    );
  }
}

class _GuidesPainter extends CustomPainter {
  const _GuidesPainter({
    required this.depth,
    required this.color,
    required this.rightToLeft,
  });

  final int depth;
  final Color color;
  final bool rightToLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var level = 0; level < depth; level++) {
      // Down the middle of the step.
      final start = (_indentOf(level) + _indentOf(level + 1)) / 2;
      final x = rightToLeft ? size.width - start : start;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GuidesPainter oldDelegate) =>
      oldDelegate.depth != depth ||
      oldDelegate.color != color ||
      oldDelegate.rightToLeft != rightToLeft;
}

/// A card picked up to be reordered: it grows a little and casts a deeper
/// shadow, then settles back as it's dropped.
class _LiftedCard extends StatelessWidget {
  const _LiftedCard({
    required this.animation,
    required this.indent,
    required this.child,
  });

  final Animation<double> animation;

  /// How far in from the start of the list the card is.
  final double indent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final lift = Curves.easeOutCubic.transform(animation.value);
        return Transform.scale(
          scale: 1 + 0.03 * lift,
          child: Stack(
            children: [
              PositionedDirectional(
                start: indent,
                top: 0,
                end: 0,
                bottom: _cardGap,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: TaskCard.shape,
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: (isDarkTheme ? 0.5 : 0.18) * lift),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: indent, bottom: _cardGap),
        child: child,
      ),
    );
  }
}
