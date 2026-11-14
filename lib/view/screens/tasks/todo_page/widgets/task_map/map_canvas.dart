import 'dart:ui' show PointMode, lerpDouble;

import 'package:material_ui/material_ui.dart';

import 'map_layout.dart';

/// A faint grid of dots under the map, which moves and grows with it, so
/// that dragging the map shows even where there are no tasks. It's set out
/// from the map's centre, which stays put as the map around it changes.
class MapGridPainter extends CustomPainter {
  MapGridPainter({required this.view, required this.hub, required this.color})
      : super(repaint: view);

  final TransformationController view;
  final Offset hub;
  final Color color;

  /// How far apart the dots are, on the map.
  static const _step = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = view.value;
    final scale = matrix.getMaxScaleOnAxis();
    if (scale <= 0 || size.isEmpty) return;
    // Every other one is left out, and again, as zooming out brings them
    // too close together.
    var step = _step * scale;
    while (step < 20) {
      step *= 2;
    }
    final origin = MatrixUtils.transformPoint(matrix, hub);
    final dots = <Offset>[
      for (var x = origin.dx % step; x < size.width; x += step)
        for (var y = origin.dy % step; y < size.height; y += step) Offset(x, y),
    ];
    canvas.drawPoints(
      PointMode.points,
      dots,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(MapGridPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.hub != hub ||
      oldDelegate.color != color;
}

/// Where one of the map's parts goes, and how it gets there.
class MapSpot {
  const MapSpot({
    required this.size,
    required this.to,
    this.from,
    this.entering = false,
    this.leaving = false,
    this.carried = false,
    this.dim = 1,
  });

  final Size size;

  /// Where its middle belongs, and where it was as the change began, if it
  /// was anywhere else. For the task being [carried], [to] is from the
  /// finger to its middle instead.
  final Offset to;
  final Offset? from;

  /// Whether it's just come, and grows into place, or just gone, and
  /// shrinks away.
  final bool entering;
  final bool leaving;

  /// Whether it goes where the finger is.
  final bool carried;

  /// How strongly it's drawn: faintly for the tasks left behind by the one
  /// being carried, which is drawn again under the finger.
  final double dim;
}

/// Puts each part of the map where it is on the way to where it belongs.
/// Only this is done again for each frame of a change: the parts themselves
/// are drawn once.
class MapFlowDelegate extends FlowDelegate {
  MapFlowDelegate({
    required this.size,
    required this.spots,
    required this.progress,
    required this.carriedAt,
  }) : super(repaint: Listenable.merge([progress, carriedAt]));

  final Size size;
  final List<MapSpot> spots;
  final Animation<double> progress;
  final ValueNotifier<Offset> carriedAt;

  @override
  Size getSize(BoxConstraints constraints) => size;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(spots[i].size);

  @override
  void paintChildren(FlowPaintingContext context) {
    final t = progress.value;
    for (var i = 0; i < context.childCount; i++) {
      final spot = spots[i];
      final from = spot.from;
      var middle = from == null ? spot.to : Offset.lerp(from, spot.to, t)!;
      var scale = 1.0;
      var opacity = spot.dim;
      if (spot.carried) {
        // A little see-through, for what it's over to show.
        middle = carriedAt.value + spot.to;
        scale = 1.05;
        opacity = 0.9;
      } else if (spot.entering) {
        scale = lerpDouble(0.4, 1, t)!;
        opacity *= t;
      } else if (spot.leaving) {
        scale = lerpDouble(1, 0.4, t)!;
        opacity *= 1 - t;
      }
      if (opacity <= 0) continue;
      context.paintChild(
        i,
        transform: Matrix4.identity()
          ..translateByDouble(middle.dx, middle.dy, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1)
          ..translateByDouble(
              -spot.size.width / 2, -spot.size.height / 2, 0, 1),
        opacity: opacity.clamp(0.0, 1.0),
      );
    }
  }

  @override
  bool shouldRelayout(MapFlowDelegate oldDelegate) =>
      oldDelegate.size != size || !identical(oldDelegate.spots, spots);

  @override
  bool shouldRepaint(MapFlowDelegate oldDelegate) =>
      !identical(oldDelegate.spots, spots) ||
      oldDelegate.progress != progress ||
      oldDelegate.carriedAt != carriedAt;
}

/// The branch from a task to the one it's in, or to the centre.
class MapLink {
  const MapLink({
    required this.size,
    required this.to,
    required this.from,
    required this.parentSize,
    required this.parentTo,
    required this.parentFrom,
    required this.onLeft,
    required this.color,
    required this.width,
    required this.strength,
    required this.entering,
    required this.stem,
  });

  /// The task's box: its size, where its middle belongs, and where that was
  /// as the change began.
  final Size size;
  final Offset to;
  final Offset? from;

  /// The same of the task it branches off, whose size is null for the
  /// centre.
  final Size? parentSize;
  final Offset parentTo;
  final Offset? parentFrom;
  final bool onLeft;
  final Color color;
  final double width;

  /// How strongly it's drawn: less to a task that's done.
  final double strength;
  final bool entering;

  /// Whether the task has a knob, which a short line joins it to.
  final bool stem;
}

/// The map's branches: a curve from each task to the one it's in, which
/// leaves that one level and arrives level, in its branch's colour.
class MapBranchesPainter extends CustomPainter {
  MapBranchesPainter({
    required this.links,
    required this.hub,
    required this.progress,
  }) : super(repaint: progress);

  final List<MapLink> links;
  final Offset hub;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final link in links) {
      final from = link.from;
      final middle = from == null ? link.to : Offset.lerp(from, link.to, t)!;
      final rect = Rect.fromCenter(
          center: middle, width: link.size.width, height: link.size.height);
      final parentFrom = link.parentFrom;
      final parentMiddle = parentFrom == null
          ? link.parentTo
          : Offset.lerp(parentFrom, link.parentTo, t)!;
      final parentSize = link.parentSize;
      final start = parentSize == null
          // Off the centre's edge, on the task's side of it.
          ? parentMiddle.translate(
              link.onLeft ? -MapLayout.hubRadius : MapLayout.hubRadius, 0)
          : MapLayout.knobOf(
              Rect.fromCenter(
                  center: parentMiddle,
                  width: parentSize.width,
                  height: parentSize.height),
              onLeft: link.onLeft);
      final end = MapLayout.innerOf(rect, onLeft: link.onLeft);
      final alpha = link.strength * (link.entering ? t : 1);
      paint
        ..color = link.color.withValues(alpha: 0.85 * alpha)
        ..strokeWidth = link.width;
      final bend = (end.dx - start.dx) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(
              start.dx + bend, start.dy, end.dx - bend, end.dy, end.dx, end.dy),
        paint,
      );
      if (link.stem) {
        final knob = MapLayout.knobOf(rect, onLeft: link.onLeft);
        canvas.drawLine(
            link.onLeft ? rect.centerLeft : rect.centerRight, knob, paint);
      }
    }
  }

  @override
  bool shouldRepaint(MapBranchesPainter oldDelegate) =>
      !identical(oldDelegate.links, links) || oldDelegate.hub != hub;
}

/// A line just above or below a task, where the one being dragged would go
/// if it were dropped: next to it.
class MapDropPainter extends CustomPainter {
  const MapDropPainter({
    required this.rect,
    required this.after,
    required this.color,
  });

  final Rect rect;
  final bool after;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = after
        ? rect.bottom + MapLayout.siblingGap / 2
        : rect.top - MapLayout.siblingGap / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(rect.left + 4, y), Offset(rect.right - 4, y), paint);
    canvas.drawCircle(Offset(rect.left + 4, y), 4, paint);
  }

  @override
  bool shouldRepaint(MapDropPainter oldDelegate) =>
      oldDelegate.rect != rect ||
      oldDelegate.after != after ||
      oldDelegate.color != color;
}
