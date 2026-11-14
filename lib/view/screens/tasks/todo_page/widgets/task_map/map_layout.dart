import 'dart:math' as math;
import 'dart:ui';

import '../../../../../../models/task_tree.dart';

/// Where a task is on the map.
class MapPlace {
  const MapPlace({
    required this.node,
    required this.rect,
    required this.onLeft,
    required this.branch,
    required this.parent,
  });

  final TaskNode node;

  /// Its box, on the map.
  final Rect rect;

  /// Whether it's to the left of the centre, where the branches grow to the
  /// left: each task's subtasks are on its far side from the centre.
  final bool onLeft;

  /// Which of the centre's branches it's on, counted in the tasks' order,
  /// which its colour goes by.
  final int branch;

  /// The key of the task it branches off, or null for one that branches off
  /// the centre.
  final String? parent;

  MapPlace _shifted(Offset by) => MapPlace(
        node: node,
        rect: rect.shift(by),
        onLeft: onLeft,
        branch: branch,
        parent: parent,
      );
}

/// The tasks laid out as a map: the centre, the tasks of their own stacked
/// beside it, and each task's subtasks stacked on its far side, their middle
/// level with its own. On a screen that's wider than it's tall, the tasks of
/// their own are on both sides of the centre, which makes the map half as
/// tall; on a tall one they're all to its right, which keeps it narrow.
class MapLayout {
  const MapLayout._(this.size, this.hub, this.content, this.places);

  /// The centre's radius, and how far from its edge the tasks of their own
  /// start.
  static const hubRadius = 44.0;
  static const hubGap = 48.0;

  /// How far a task's subtasks start from its edge, and how far out along
  /// that the knob that folds them away sits.
  static const gap = 54.0;
  static const knobOffset = 17.0;

  /// The room between a task's subtasks, and between the centre's branches.
  static const siblingGap = 12.0;
  static const branchGap = 24.0;

  /// The room around the whole map, for a task being dragged to go to.
  static const margin = 120.0;

  /// Lays out the tasks of [tree], each as big as [sizeOf] says, on both
  /// sides of the centre if [twoSided]. A folded task's subtasks are left
  /// off.
  factory MapLayout(TaskTree tree,
      {required Size Function(TaskNode node) sizeOf, bool twoSided = false}) {
    final heights = <TaskNode, double>{};
    List<TaskNode> shownIn(TaskNode node) =>
        node.task.folded ? const [] : node.children;

    // How tall a task is with its subtasks stacked beside it.
    late final double Function(TaskNode node) heightOf;
    double stacked(List<TaskNode> nodes, double gap) =>
        nodes.fold(-gap, (height, node) => height + heightOf(node) + gap);
    heightOf = (node) => heights[node] ??= () {
          final children = shownIn(node);
          final own = sizeOf(node).height;
          return children.isEmpty
              ? own
              : math.max(own, stacked(children, siblingGap));
        }();

    final places = <String, MapPlace>{};
    void place(TaskNode node, double edge, double top,
        {required bool onLeft, required int branch, required String? parent}) {
      final size = sizeOf(node);
      final height = heightOf(node);
      final left = onLeft ? edge - size.width : edge;
      places[node.key] = MapPlace(
        node: node,
        rect: Rect.fromLTWH(
            left, top + (height - size.height) / 2, size.width, size.height),
        onLeft: onLeft,
        branch: branch,
        parent: parent,
      );
      final children = shownIn(node);
      if (children.isEmpty) return;
      final childEdge = onLeft ? left - gap : left + size.width + gap;
      var y = top + (height - stacked(children, siblingGap)) / 2;
      for (final child in children) {
        place(child, childEdge, y,
            onLeft: onLeft, branch: branch, parent: node.key);
        y += heightOf(child) + siblingGap;
      }
    }

    // On both sides, the first half of the tasks go to the right, top to
    // bottom, then the rest to the left: folding a task away never moves
    // another across.
    final roots = tree.roots;
    final onRight = twoSided ? (roots.length + 1) ~/ 2 : roots.length;
    void side(List<TaskNode> nodes, int first, {required bool onLeft}) {
      if (nodes.isEmpty) return;
      var y = -stacked(nodes, branchGap) / 2;
      for (final (index, node) in nodes.indexed) {
        place(node, onLeft ? -(hubRadius + hubGap) : hubRadius + hubGap, y,
            onLeft: onLeft, branch: first + index, parent: null);
        y += heightOf(node) + branchGap;
      }
    }

    side(roots.sublist(0, onRight), 0, onLeft: false);
    side(roots.sublist(onRight), onRight, onLeft: true);

    // The centre is at the origin so far. Everything moves over so the map
    // starts at its own top left corner.
    var content = Rect.fromCircle(center: Offset.zero, radius: hubRadius);
    for (final place in places.values) {
      content = content.expandToInclude(place.rect);
    }
    final shift = -content.inflate(margin).topLeft;
    return MapLayout._(
      content.inflate(margin).size,
      shift,
      content.shift(shift),
      {
        for (final entry in places.entries)
          entry.key: entry.value._shifted(shift),
      },
    );
  }

  /// How big the map is, with the room around it.
  final Size size;

  /// Where the centre's middle is.
  final Offset hub;

  /// The box around the centre and every task.
  final Rect content;

  /// Where each task is, by its [TaskNode.key], each ahead of its subtasks.
  final Map<String, MapPlace> places;

  /// Where a task's branch joins it: the middle of the side of [rect] that
  /// faces the centre.
  static Offset innerOf(Rect rect, {required bool onLeft}) =>
      onLeft ? rect.centerRight : rect.centerLeft;

  /// Where the knob that folds a task's subtasks away sits, off the middle
  /// of the far side of [rect], which is where their branches start.
  static Offset knobOf(Rect rect, {required bool onLeft}) => onLeft
      ? rect.centerLeft.translate(-knobOffset, 0)
      : rect.centerRight.translate(knobOffset, 0);
}
