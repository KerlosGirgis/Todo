import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../../core/extensions/theme_extensions.dart';
import '../../../../../../core/result.dart';
import '../../../../../../models/task_tree.dart';
import '../../../../../../models/todo_item.dart';
import '../../../../../../view_model/tasks_view_model.dart';
import '../../../../../widgets/glass_icon_button.dart';
import 'map_canvas.dart';
import 'map_layout.dart';
import 'map_node.dart';
import 'map_toolbar.dart';

/// The tasks as a map, in place of the list: the centre in the middle, the
/// tasks of their own branching off it to either side, and each task's
/// subtasks branching off it in turn.
///
/// The map is dragged around and pinched to zoom. A tap on a task's check
/// marks it done, and a tap on the rest of it picks it out, for the buttons
/// that come up to act on: they add a subtask to it, edit it, set its
/// reminder and delete it. The knob at a task's far side folds its subtasks
/// away. A task that's pressed and held is picked up, with its subtasks, to
/// be dropped on the task it's to go into, or just above or below the one
/// it's to go next to.
class TaskMap extends StatefulWidget {
  const TaskMap({
    super.key,
    required this.tasks,
    required this.insets,
    required this.onEdit,
    required this.onAddSubtask,
    required this.onDelete,
    required this.onResult,
    this.hubKey,
    this.nodeKey,
    this.fitKey,
  });

  final TasksViewModel tasks;

  /// How much of the map the page's bar covers at the top, and what the map
  /// keeps clear of at its other sides, as it's fitted to the screen.
  final EdgeInsets insets;

  /// Opens the editor for the task.
  final ValueChanged<TodoItem> onEdit;

  /// Opens the form for a new subtask of the task.
  final ValueChanged<TodoItem> onAddSubtask;

  /// Moves the task to the trash, with the tasks in it.
  final ValueChanged<TodoItem> onDelete;

  /// Shows how something the map asked for went, if there's anything to
  /// say.
  final ValueChanged<Result?> onResult;

  /// Keys for the centre, the first task and the button that fits the map
  /// to the screen, so that a tour can point at them.
  final Key? hubKey;
  final Key? nodeKey;
  final Key? fitKey;

  @override
  State<TaskMap> createState() => _TaskMapState();
}

/// Where a task being dragged goes when it's dropped on another: into it,
/// or next to it.
enum _Where { into, before, after }

/// Where a task being dragged would go if it were dropped now.
class _Drop {
  const _Drop(this.key, this.where);

  /// The task it's over, by its key, or null for the centre.
  final String? key;
  final _Where where;

  @override
  bool operator ==(Object other) =>
      other is _Drop && other.key == key && other.where == where;

  @override
  int get hashCode => Object.hash(key, where);
}

/// A task that's been picked up to be moved.
class _Carried {
  _Carried({
    required this.key,
    required this.from,
    required this.grip,
    required this.branch,
  });

  final String key;

  /// Where on the screen the finger picked it up.
  final Offset from;

  /// From the finger to the middle of the task's box, on the map.
  final Offset grip;

  /// The task and every task in it, by their keys: they go with it, so it
  /// can't be dropped on any of them.
  final Set<String> branch;

  _Drop? target;
}

/// A task that's just gone from the map, which fades away into the task it
/// was in.
class _Ghost {
  const _Ghost(this.place, this.bits, {required this.from, required this.to});

  final MapPlace place;
  final List<MapNodeBit> bits;
  final Offset from;
  final Offset to;
}

class _TaskMapState extends State<TaskMap> with TickerProviderStateMixin {
  /// The smallest the map opens at, to fit as much of it on the screen as
  /// can still be read, and the smallest it's shown to fit all of it.
  static const _smallestOpen = 0.72;
  static const _smallestWhole = 0.3;

  /// How the map is seen: where it's been dragged to, and how far it's
  /// zoomed.
  final _view = TransformationController();
  final _viewerKey = GlobalKey();

  /// Takes the tasks from where they are to where a change puts them.
  late final _change = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  )..addStatusListener(_changeStatus);
  late final _eased =
      CurvedAnimation(parent: _change, curve: Curves.easeInOutCubic);

  /// Takes the view from where it is to where it's been asked to go.
  late final _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  )..addListener(_glideOn);
  Matrix4Tween? _glidePath;

  MapNodeStyle? _style;
  bool _still = false;

  /// Whether the screen is wider than it's tall, when the map has tasks on
  /// both sides of its centre.
  bool _wide = false;

  /// The tasks' sizes, by what's drawn in them, so that only the ones that
  /// change are measured again.
  final _sizes = <String, Size>{};

  /// The tasks the map is of, and where they are.
  TaskTree? _tree;
  MapLayout _layout = MapLayout(TaskTree.empty, sizeOf: (node) => Size.zero);
  Map<String, List<MapNodeBit>> _bits = const {};
  Set<String> _known = const {};

  /// Where the tasks' middles were as the last change began, the ones that
  /// have just come, and the ones that have just gone.
  Map<String, Offset> _from = const {};
  Set<String> _entering = const {};
  List<_Ghost> _ghosts = const [];

  /// The task the buttons act on, by its key.
  String? _selected;

  /// The task being dragged, and where the finger has it, on the map.
  _Carried? _carried;
  final _carriedAt = ValueNotifier(Offset.zero);
  Offset _finger = Offset.zero;
  Ticker? _edgePan;
  Duration _edgePanned = Duration.zero;

  Size _viewport = Size.zero;

  /// Whether the map has been fitted to the screen, as it is once, when it
  /// opens.
  bool _placed = false;

  /// Whether the map is being dragged or pinched.
  bool _handled = false;
  Timer? _lostCheck;

  @override
  void initState() {
    super.initState();
    _view.addListener(_viewChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    final screen = MediaQuery.sizeOf(context);
    final wide = screen.width > screen.height;
    final style = MapNodeStyle.of(context);
    final first = _style == null;
    final turned = !first && wide != _wide;
    final restyled = style.signature != _style?.signature;
    if (!turned && !restyled) return;
    _wide = wide;
    if (restyled) {
      // The tasks are other sizes now, at another text size, say.
      _style = style;
      _sizes.clear();
    }
    _lay(animate: first || turned);
    // The map is another shape once the phone has turned, so it's fitted
    // to the screen again, once that's its new size.
    if (turned) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _glideTo(_viewOf(smallest: _smallestOpen));
      });
    }
  }

  @override
  void didUpdateWidget(TaskMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.tasks.tree, _tree)) _lay(animate: true);
  }

  @override
  void dispose() {
    _lostCheck?.cancel();
    _edgePan?.dispose();
    _carriedAt.dispose();
    _eased.dispose();
    _change.dispose();
    _glide.dispose();
    _view.dispose();
    super.dispose();
  }

  /// Where the middle of the task with [key] is right now, part way through
  /// a change or not.
  Offset _centerOf(String key) {
    final to = _layout.places[key]!.rect.center;
    final from = _from[key];
    return from == null ? to : Offset.lerp(from, to, _eased.value)!;
  }

  /// Lays the tasks out afresh, as they've changed, and takes them there
  /// from where they are: the ones that have moved glide over, new ones come
  /// out of the task they're in, and ones that have gone fade back into
  /// theirs. The centre stays where it is on the screen.
  void _lay({required bool animate}) {
    final style = _style!;
    final tree = widget.tasks.tree;
    final now = DateTime.now();
    final bits = {
      for (final node in tree.nodes) node.key: MapNodeStyle.bitsOf(node, now),
    };
    final layout = MapLayout(
      tree,
      twoSided: _wide,
      sizeOf: (node) {
        final nodeBits = bits[node.key]!;
        final drawn = "${node.depth == 0}\n${node.task.title}\n"
            "${nodeBits.map((bit) => "${bit.icon.codePoint}:${bit.label}").join(",")}";
        return _sizes[drawn] ??= style.sizeOf(node, nodeBits);
      },
    );

    final first = _tree == null;
    final before = _layout;
    // The map's corner moves as the map grows, and its centre with it.
    final shift = first ? Offset.zero : layout.hub - before.hub;
    // Often only what the tasks say has changed, as one's checked off, and
    // they're all where they were going already: then they carry on there.
    final settled = !first &&
        layout.places.length == before.places.length &&
        layout.places.entries.every((entry) {
          final was = before.places[entry.key]?.rect.shift(shift);
          final rect = entry.value.rect;
          return was != null &&
              was.size == rect.size &&
              (was.center - rect.center).distanceSquared < 0.25;
        });
    if (settled && shift == Offset.zero) {
      _tree = tree;
      _layout = layout;
      _bits = bits;
      _known = {for (final node in tree.nodes) node.key};
      return;
    }
    final current = {
      if (!first)
        for (final key in before.places.keys) key: _centerOf(key) + shift,
    };
    var changed = first;
    final from = <String, Offset>{};
    final entering = <String>{};
    for (final MapEntry(:key, value: place) in layout.places.entries) {
      var at = current[key];
      if (at == null) {
        // Out of the task it's in, if that was there, or the nearest task
        // around that one that was, or else the centre.
        for (var around = place.parent;
            around != null && at == null;
            around = layout.places[around]?.parent) {
          at = current[around];
        }
        at ??= layout.hub;
        entering.add(key);
        changed = true;
      } else {
        if ((at - place.rect.center).distanceSquared > 0.25) changed = true;
        // One still on its way in goes on coming in.
        if (_change.isAnimating && _entering.contains(key)) entering.add(key);
      }
      from[key] = at;
    }
    final ghosts = <_Ghost>[];
    for (final MapEntry(:key, value: place) in before.places.entries) {
      if (first || layout.places.containsKey(key)) continue;
      Offset? into;
      for (var around = place.parent;
          around != null && into == null;
          around = before.places[around]?.parent) {
        into = layout.places[around]?.rect.center;
      }
      ghosts.add(_Ghost(place, _bits[key] ?? const [],
          from: current[key]!, to: into ?? layout.hub));
      changed = true;
    }
    if (shift != Offset.zero) {
      _view.value = _view.value.clone()
        ..translateByDouble(-shift.dx, -shift.dy, 0, 1);
    }

    final keys = {for (final node in tree.nodes) node.key};
    final added = first ? const <String>{} : keys.difference(_known);
    _known = keys;
    _tree = tree;
    _layout = layout;
    _bits = bits;
    if (!layout.places.containsKey(_selected)) _selected = null;
    if (!layout.places.containsKey(_carried?.key)) _letGo();
    // Where a task being carried was aimed may not be there anymore: it's
    // aimed afresh as it's carried on.
    _carried?.target = null;
    if (animate && changed && !_still) {
      _from = from;
      _entering = entering;
      _ghosts = ghosts;
      _change.forward(from: 0);
    } else {
      _from = const {};
      _entering = const {};
      _ghosts = const [];
      _change.value = 1;
    }
    // A task that's just been added is brought into view.
    if (added.length == 1) _reveal(added.single);
  }

  void _changeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _ghosts.isEmpty) return;
    setState(() => _ghosts = const []);
  }

  /// The part of the screen the map is seen through, clear of the page's
  /// bar.
  Rect get _seen {
    final insets = widget.insets;
    return Rect.fromLTRB(
      insets.left + 12,
      insets.top + 12,
      math.max(insets.left + 13, _viewport.width - insets.right - 12),
      math.max(insets.top + 13, _viewport.height - insets.bottom - 12),
    );
  }

  /// The view that fits the map in, as big as it goes: no bigger than life,
  /// and no smaller than [smallest]. What doesn't fit across then starts at
  /// the side the centre is on, and what doesn't fit down has the centre in
  /// the middle.
  Matrix4 _viewOf({required double smallest}) {
    final seen = _seen;
    final content = _layout.content.inflate(20);
    final hub = _layout.hub;
    final scale = math
        .min(seen.width / content.width, seen.height / content.height)
        .clamp(smallest, 1.0);
    final double dx;
    if (content.width * scale <= seen.width + 1) {
      dx = seen.center.dx - content.center.dx * scale;
    } else if (_wide) {
      dx = seen.center.dx - hub.dx * scale;
    } else {
      dx = seen.left - content.left * scale;
    }
    final dy = content.height * scale <= seen.height + 1
        ? seen.center.dy - content.center.dy * scale
        : seen.center.dy - hub.dy * scale;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _glideTo(Matrix4 view) {
    if (_still) {
      _glide.stop();
      _view.value = view;
      return;
    }
    _glidePath = Matrix4Tween(begin: _view.value.clone(), end: view);
    _glide.forward(from: 0);
  }

  void _glideOn() {
    final path = _glidePath;
    if (path == null) return;
    _view.value = path.transform(Curves.easeInOutCubic.transform(_glide.value));
  }

  /// Moves the view just far enough to show the task with [key], if it's
  /// out of sight.
  void _reveal(String key) {
    final place = _layout.places[key];
    if (place == null || _viewport.isEmpty) return;
    final view = _view.value;
    final shown = MatrixUtils.transformRect(view, place.rect.inflate(20));
    final seen = _seen;
    double toShow(double start, double end, double from, double to) {
      if (end - start > to - from) return (from + to) / 2 - (start + end) / 2;
      if (start < from) return from - start;
      if (end > to) return to - end;
      return 0;
    }

    final dx = toShow(shown.left, shown.right, seen.left, seen.right);
    final dy = toShow(shown.top, shown.bottom, seen.top, seen.bottom);
    if (dx == 0 && dy == 0) return;
    final translation = view.getTranslation();
    _glideTo(view.clone()
      ..setTranslationRaw(translation.x + dx, translation.y + dy, 0));
  }

  /// Brings the map back if it's been dragged right out of sight, once
  /// it's come to rest.
  void _viewChanged() {
    _lostCheck?.cancel();
    _lostCheck = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _handled || _carried != null || _viewport.isEmpty) {
        return;
      }
      final shown = MatrixUtils.transformRect(_view.value, _layout.content);
      if (!shown.overlaps(_seen.deflate(24))) {
        _glideTo(_viewOf(smallest: _smallestOpen));
      }
    });
  }

  /// Where the buttons for the task picked out go, for a task at [task] on
  /// the screen: over it, in line with its middle, or under it when there's
  /// no room over it, and never off the part of the screen the map is seen
  /// through.
  Offset _toolbarAt(Rect task) {
    final seen = _seen;
    const gap = 10.0;
    final over = task.top - gap - MapToolbar.height;
    final top = over >= seen.top ? over : task.bottom + gap;
    return Offset(
      (task.center.dx - MapToolbar.width / 2)
          .clamp(seen.left, math.max(seen.left, seen.right - MapToolbar.width)),
      top.clamp(seen.top, math.max(seen.top, seen.bottom - MapToolbar.height)),
    );
  }

  /// Where [global], a point on the screen, is on the map.
  Offset _onMap(Offset global) {
    final box = _viewerKey.currentContext!.findRenderObject()! as RenderBox;
    return _view.toScene(box.globalToLocal(global));
  }

  void _select(String? key) {
    if (key != null) HapticFeedback.selectionClick();
    setState(() => _selected = key == _selected ? null : key);
  }

  void _toggle(TodoItem task) {
    HapticFeedback.lightImpact();
    widget.tasks.toggleDone(task).then(widget.onResult);
  }

  void _pickUp(String key, Offset global) {
    final place = _layout.places[key];
    if (place == null) return;
    HapticFeedback.mediumImpact();
    _glide.stop();
    _finger = global;
    final at = _onMap(global);
    _carriedAt.value = at;
    setState(() {
      // It's being moved, not picked out for its buttons.
      _selected = null;
      _carried = _Carried(
        key: key,
        from: global,
        grip: place.rect.center - at,
        branch: {key, for (final node in place.node.descendants) node.key},
      );
    });
    _edgePanned = Duration.zero;
    _edgePan ??= createTicker(_panAtEdge);
    if (!_edgePan!.isActive) _edgePan!.start();
  }

  void _carry(Offset global) {
    if (_carried == null) return;
    _finger = global;
    _carriedAt.value = _onMap(global);
    _aim();
  }

  /// Works out where the task being dragged would go if it were dropped
  /// now, and shows it.
  void _aim() {
    final carried = _carried;
    if (carried == null) return;
    final target = _dropAt(_carriedAt.value, carried);
    if (target == carried.target) return;
    if (target != null) HapticFeedback.selectionClick();
    setState(() => carried.target = target);
  }

  /// Where a task dropped at [point] would go: into the centre, as a task
  /// of its own; into the task it's over the middle of; or next to the one
  /// it's over the top or bottom of.
  _Drop? _dropAt(Offset point, _Carried carried) {
    if ((point - _layout.hub).distance <= MapLayout.hubRadius + 12) {
      return const _Drop(null, _Where.into);
    }
    _Drop? nearest;
    var distance = double.infinity;
    for (final MapEntry(:key, value: place) in _layout.places.entries) {
      if (carried.branch.contains(key)) continue;
      final rect = place.rect;
      if (!rect.inflate(MapLayout.siblingGap / 2).contains(point)) continue;
      final away = (point - rect.center).distanceSquared;
      if (away >= distance) continue;
      distance = away;
      final part = (point.dy - rect.top) / rect.height;
      nearest = _Drop(
        key,
        part < 0.28
            ? _Where.before
            : part > 0.72
                ? _Where.after
                : _Where.into,
      );
    }
    return nearest;
  }

  /// Drops the task being dragged where it's aimed, if anywhere.
  void _drop() {
    final carried = _carried;
    if (carried == null) return;
    final target = carried.target;
    final task = _layout.places[carried.key]?.node.task;
    _letGo();
    if (target == null || task == null) return;
    final onto = _layout.places[target.key]?.node.task;
    HapticFeedback.lightImpact();
    final tasks = widget.tasks;
    final Future<Result?> moving;
    if (onto == null) {
      // On the centre: a task of its own.
      moving = tasks.moveInto(task, null);
    } else {
      moving = switch (target.where) {
        _Where.into => tasks.moveInto(task, onto),
        _Where.before => tasks.moveBeside(task, onto, after: false),
        _Where.after => tasks.moveBeside(task, onto, after: true),
      };
    }
    moving.then(widget.onResult);
  }

  void _letGo() {
    _edgePan?.stop();
    if (_carried == null) return;
    if (mounted) {
      setState(() => _carried = null);
    } else {
      _carried = null;
    }
  }

  /// Moves the map along while a task is held near an edge of the screen,
  /// to get to the tasks past it.
  void _panAtEdge(Duration elapsed) {
    final seconds = (elapsed - _edgePanned).inMicroseconds / 1e6;
    _edgePanned = elapsed;
    final box = _viewerKey.currentContext?.findRenderObject();
    final carried = _carried;
    // Not while it's over somewhere to drop it, which would move away.
    if (carried == null || carried.target != null || box is! RenderBox) {
      return;
    }
    final at = box.globalToLocal(_finger);
    final from = box.globalToLocal(carried.from);
    final seen = _seen;
    const reach = 48.0;
    // Only towards an edge the task has been carried towards: one picked
    // up by an edge stays put until it's taken further that way.
    double push(double at, double from, double start, double end) {
      if (at < start + reach && at < from - 16) {
        return ((start + reach - at) / reach).clamp(0.0, 1.0);
      }
      if (at > end - reach && at > from + 16) {
        return -((at - (end - reach)) / reach).clamp(0.0, 1.0);
      }
      return 0;
    }

    final by = Offset(push(at.dx, from.dx, seen.left, seen.right),
            push(at.dy, from.dy, seen.top, seen.bottom)) *
        (560 * seconds.clamp(0.0, 0.05));
    if (by == Offset.zero) return;
    final view = _view.value.clone();
    final translation = view.getTranslation();
    view.setTranslationRaw(translation.x + by.dx, translation.y + by.dy, 0);
    _view.value = view;
    _carriedAt.value = _onMap(_finger);
    _aim();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        if (!_placed && !_viewport.isEmpty) {
          _placed = true;
          _view.value = _viewOf(smallest: _smallestOpen);
        }
        final padding = MediaQuery.paddingOf(context);
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        final selected = _layout.places[_selected]?.node;
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: MapGridPainter(
                    view: _view,
                    hub: _layout.hub,
                    color: context.colors.wB
                        .withValues(alpha: isDarkTheme ? 0.11 : 0.09),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                key: _viewerKey,
                behavior: HitTestBehavior.translucent,
                // A tap on the map itself lets go of the task picked out.
                onTap: _selected == null ? null : () => _select(null),
                child: InteractiveViewer(
                  transformationController: _view,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.25,
                  maxScale: 2.5,
                  onInteractionStart: (details) {
                    _handled = true;
                    _glide.stop();
                  },
                  onInteractionEnd: (details) {
                    _handled = false;
                    _viewChanged();
                  },
                  // Drawn once, then only moved as the map is dragged.
                  child: RepaintBoundary(child: _buildMap(context)),
                ),
              ),
            ),
            PositionedDirectional(
              start: 16 + padding.left,
              bottom: 16 + padding.bottom,
              child: KeyedSubtree(
                key: widget.fitKey,
                child: GlassIconButton(
                  icon: Icons.fit_screen_rounded,
                  tooltip: "Show Whole Map",
                  onPressed: () => _glideTo(_viewOf(smallest: _smallestWhole)),
                ),
              ),
            ),
            // Where the task being carried would go, in words, over it.
            if (_carried case _Carried(:final target?, :final key, :final grip))
              AnimatedBuilder(
                animation: Listenable.merge([_carriedAt, _view]),
                builder: (context, child) {
                  final view = _view.value;
                  final middle =
                      MatrixUtils.transformPoint(view, _carriedAt.value + grip);
                  final height = (_layout.places[key]?.rect.height ?? 0) *
                      view.getMaxScaleOnAxis();
                  final seen = _seen;
                  return Positioned(
                    left: (middle.dx - _DropHint.width / 2).clamp(seen.left,
                        math.max(seen.left, seen.right - _DropHint.width)),
                    top: math.max(seen.top,
                        middle.dy - height / 2 - 14 - _DropHint.height),
                    width: _DropHint.width,
                    height: _DropHint.height,
                    child: child!,
                  );
                },
                child: _DropHint(
                  target.where,
                  onto: _layout.places[target.key]?.node.task,
                ),
              ),
            // The buttons for the task picked out, beside it, wherever the
            // map takes it. Not while a task is being carried.
            if (selected != null && _carried == null)
              AnimatedBuilder(
                animation: Listenable.merge([_view, _eased]),
                builder: (context, child) {
                  final place = _layout.places[selected.key];
                  if (place == null) return const SizedBox.shrink();
                  final at = _toolbarAt(MatrixUtils.transformRect(
                    _view.value,
                    Rect.fromCenter(
                      center: _centerOf(selected.key),
                      width: place.rect.width,
                      height: place.rect.height,
                    ),
                  ));
                  return Positioned(left: at.dx, top: at.dy, child: child!);
                },
                child: MapToolbar(
                  // Comes up afresh for each task picked out.
                  key: ValueKey(selected.key),
                  task: selected.task,
                  onToggle: () => _toggle(selected.task),
                  onAddSubtask: () => widget.onAddSubtask(selected.task),
                  onEdit: () => widget.onEdit(selected.task),
                  onReminder: () => widget.tasks
                      .toggleReminder(selected.task)
                      .then(widget.onResult),
                  onDailyReminder: () => widget.tasks
                      .remindDaily(selected.task)
                      .then(widget.onResult),
                  onDelete: () => widget.onDelete(selected.task),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The map itself: its branches, then the centre, the tasks and their
  /// knobs over them, each where the layout has it, or on its way there.
  Widget _buildMap(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final style = _style!;
    final layout = _layout;
    final carried = _carried;
    final target = carried?.target;
    final total =
        widget.tasks.finishedTasksCount + widget.tasks.unfinishedTasksCount;

    final children = <Widget>[];
    final spots = <MapSpot>[];
    final links = <MapLink>[];

    children.add(GestureDetector(
      key: const ValueKey("hub"),
      behavior: HitTestBehavior.opaque,
      onTap: () => _glideTo(_viewOf(smallest: _smallestWhole)),
      child: KeyedSubtree(
        key: widget.hubKey,
        child: MapHub(
          done: widget.tasks.finishedTasksCount,
          total: total,
          targeted: target != null && target.key == null,
        ),
      ),
    ));
    spots.add(MapSpot(
      size: const Size.square(MapLayout.hubRadius * 2),
      to: layout.hub,
    ));

    var index = 0;
    for (final MapEntry(:key, value: place) in layout.places.entries) {
      final node = place.node;
      final task = node.task;
      final color = mapBranchColor(place.branch, isDarkTheme: isDarkTheme);
      final going = carried != null && carried.branch.contains(key);
      final from = _from[key];
      final entering = _entering.contains(key);
      final parent = place.parent == null ? null : layout.places[place.parent];
      children.add(Semantics(
        key: ValueKey(key),
        container: true,
        selected: key == _selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _select(key),
          onLongPressStart: (details) => _pickUp(key, details.globalPosition),
          onLongPressMoveUpdate: (details) => _carry(details.globalPosition),
          onLongPressEnd: (details) => _drop(),
          onLongPressCancel: _letGo,
          child: KeyedSubtree(
            key: index == 0 ? widget.nodeKey : null,
            child: MapNodeCard(
              node: node,
              bits: _bits[key] ?? const [],
              style: style,
              color: color,
              selected: key == _selected,
              targeted: target?.key == key && target?.where == _Where.into,
              onCheck: () => _toggle(task),
            ),
          ),
        ),
      ));
      spots.add(MapSpot(
        size: place.rect.size,
        to: place.rect.center,
        from: from,
        entering: entering,
        dim: going ? 0.35 : 1,
      ));
      links.add(MapLink(
        size: place.rect.size,
        to: place.rect.center,
        from: from,
        parentSize: parent?.rect.size,
        parentTo: parent?.rect.center ?? layout.hub,
        parentFrom: parent == null ? null : _from[place.parent],
        onLeft: place.onLeft,
        color: color,
        width: switch (node.depth) { 0 => 3.2, 1 => 2.5, _ => 2.0 },
        strength: (task.done ? 0.35 : 1) * (going ? 0.35 : 1),
        entering: entering,
        // Its subtasks' branches start at its knob, a little way out.
        stem: node.children.isNotEmpty,
      ));
      index++;
    }

    // The knobs go over the tasks, as a long title's box can reach one.
    for (final MapEntry(:key, value: place) in layout.places.entries) {
      final node = place.node;
      if (node.children.isEmpty) continue;
      final task = node.task;
      final knob = MapLayout.knobOf(place.rect, onLeft: place.onLeft) -
          place.rect.center;
      final from = _from[key];
      children.add(MapKnob(
        key: ValueKey("knob:$key"),
        folded: task.folded,
        count: node.descendants.length,
        color: mapBranchColor(place.branch, isDarkTheme: isDarkTheme),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.tasks.setFolded(task, !task.folded);
        },
      ));
      spots.add(MapSpot(
        size: const Size.square(MapKnob.touch),
        to: place.rect.center + knob,
        from: from == null ? null : from + knob,
        entering: _entering.contains(key),
        dim: carried != null && carried.branch.contains(key) ? 0.35 : 1,
      ));
    }

    for (final ghost in _ghosts) {
      final place = ghost.place;
      final color = mapBranchColor(place.branch, isDarkTheme: isDarkTheme);
      children.add(IgnorePointer(
        key: ValueKey("ghost:${place.node.key}"),
        child: ExcludeSemantics(
          child: MapNodeCard(
            node: place.node,
            bits: ghost.bits,
            style: style,
            color: color,
          ),
        ),
      ));
      spots.add(MapSpot(
        size: place.rect.size,
        to: ghost.to,
        from: ghost.from,
        leaving: true,
      ));
    }

    if (carried != null) {
      final place = layout.places[carried.key]!;
      children.add(IgnorePointer(
        key: const ValueKey("carried"),
        child: ExcludeSemantics(
          child: MapNodeCard(
            node: place.node,
            bits: _bits[carried.key] ?? const [],
            style: style,
            color: mapBranchColor(place.branch, isDarkTheme: isDarkTheme),
            lifted: true,
          ),
        ),
      ));
      spots.add(MapSpot(
        size: place.rect.size,
        to: carried.grip,
        carried: true,
      ));
    }

    final beside =
        target == null || target.where == _Where.into ? null : target;
    return SizedBox.fromSize(
      size: layout.size,
      child: CustomPaint(
        painter: MapBranchesPainter(
          links: links,
          hub: layout.hub,
          progress: _eased,
        ),
        foregroundPainter: beside == null
            ? null
            : MapDropPainter(
                rect: layout.places[beside.key]!.rect,
                after: beside.where == _Where.after,
                color: context.colors.moreLess,
              ),
        child: Flow(
          // A task being carried can be taken past the edge of the map.
          clipBehavior: Clip.none,
          delegate: MapFlowDelegate(
            size: layout.size,
            spots: spots,
            progress: _eased,
            carriedAt: _carriedAt,
          ),
          children: children,
        ),
      ),
    );
  }
}

/// Says where the task being carried would go if it were dropped now, in a
/// few words on a pill over it: the map's tasks may be too small to tell by
/// while it's zoomed out.
class _DropHint extends StatelessWidget {
  const _DropHint(this.where, {required this.onto});

  static const width = 240.0;
  static const height = 30.0;

  final _Where where;

  /// The task it's over, or null over the centre.
  final TodoItem? onto;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.moreLess;
    final onto = this.onto;
    final title = (onto?.title ?? "").characters;
    final named = title.length > 20 ? "“${title.take(19)}…”" : "“$title”";
    final text = onto == null
        ? "A task of its own"
        : switch (where) {
            _Where.into => "Into $named",
            _Where.before => "Above $named",
            _Where.after => "Below $named",
          };
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: accent,
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  // Whichever reads on the accent, which is light on dark
                  // pages.
                  color: ThemeData.estimateBrightnessForColor(accent) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
