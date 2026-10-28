import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:material_ui/material_ui.dart';

import '../../core/extensions/theme_extensions.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

/// A gesture a [TourDemo] acts out on its copy.
enum TourGesture {
  /// A tap.
  tap,

  /// A long press, held until a ring around the finger fills.
  hold,

  /// A long press that picks the copy up, then carries it down and back, as
  /// a card is moved along a list.
  drag,

  /// A swipe to the left that sends the copy away, as a card is swiped off a
  /// list, uncovering what's behind it, after which it comes back.
  swipe,
}

/// How far a [TourDemo] has got through its gestures, for its copy to show
/// what they do.
class TourPose {
  const TourPose({this.acted = 0});

  /// How many of the gestures have been done, this time through them: a tap
  /// once the finger lifts, a long press once the ring around it fills.
  final int acted;
}

/// A copy of what a [TourStep] is about that acts out [gestures] under a
/// finger, over and over, so the step can show what they do without doing
/// it: a copy of the first task's card that a tap checks off, say.
class TourDemo {
  const TourDemo({
    required this.gestures,
    required this.builder,
    this.place,
    this.touch,
    this.touchAlignment = Alignment.center,
    this.touchOffset = Offset.zero,
    this.behind,
    this.pressedScale = 0.98,
  });

  final List<TourGesture> gestures;

  /// Builds the copy as it is at the pose.
  final Widget Function(BuildContext context, TourPose pose) builder;

  /// Where the copy goes, from where the step's target is: over the target,
  /// when null. Only the rect's left, top and width count, as the copy is as
  /// tall as it lays itself out.
  final Rect Function(BuildContext context, Rect target)? place;

  /// The part of the copy the finger touches: the one with this key, or the
  /// whole copy when null. It touches it at [touchAlignment], [touchOffset]
  /// away.
  final GlobalKey? touch;
  final Alignment touchAlignment;
  final Offset touchOffset;

  /// What a swipe uncovers behind the copy, as big as the copy.
  final Widget? behind;

  /// How small the copy gets while it's held down, as the real thing does.
  final double pressedScale;
}

/// A stop on a [Tour]: a spotlight on [target], with a tip beside it on what
/// it's for, and maybe a [demo] of how it works.
class TourStep {
  const TourStep({
    required this.target,
    required this.icon,
    required this.title,
    required this.message,
    this.radius = 24,
    this.padding = 6,
    this.demo,
  });

  /// The widget the step is about. A step whose target isn't there by the
  /// time the tour gets to it is skipped.
  final GlobalKey target;
  final IconData icon;
  final String title;
  final String message;

  /// The target's corner radius, which the spotlight's corners follow,
  /// [padding] out from it.
  final double radius;
  final double padding;

  /// A copy of the target that acts out how it works, which the spotlight is
  /// on instead of the target.
  final TourDemo? demo;
}

/// Starts a [Tour] and takes it from step to step.
class TourController extends ChangeNotifier {
  List<TourStep> _steps = const [];
  int _index = 0;
  VoidCallback? _onEnd;

  bool get isActive => _steps.isNotEmpty;
  List<TourStep> get steps => _steps;
  int get index => _index;

  /// The step on show, or null while there's no tour.
  TourStep? get step => isActive ? _steps[_index] : null;

  /// Starts the tour at the first of [steps], and calls [onEnd] once the
  /// user has been through them all, or has skipped the rest.
  void start(List<TourStep> steps, {VoidCallback? onEnd}) {
    if (steps.isEmpty) return;
    _steps = List.unmodifiable(steps);
    _index = 0;
    _onEnd = onEnd;
    notifyListeners();
  }

  /// Goes on to the next step, or ends the tour after the last one.
  void next() {
    if (!isActive) return;
    if (_index < _steps.length - 1) {
      _index++;
      notifyListeners();
    } else {
      end();
    }
  }

  /// Ends the tour where it is.
  void end() {
    if (!isActive) return;
    final onEnd = _onEnd;
    _steps = const [];
    _index = 0;
    _onEnd = null;
    notifyListeners();
    onEnd?.call();
  }
}

/// Shows the user around [child], a page, one [TourStep] at a time, while
/// [controller] has a tour going: the page dims, but for a spotlight on what
/// the step is about, with a tip beside it on what that's for. A tap
/// anywhere but the tip goes on to the next step, and Back ends the tour.
/// The tour is drawn just above the page's own route, so a page opened over
/// it, like the lock page, covers it.
class Tour extends StatefulWidget {
  const Tour({super.key, required this.controller, required this.child});

  final TourController controller;
  final Widget child;

  @override
  State<Tour> createState() => _TourState();
}

class _TourState extends State<Tour> with TickerProviderStateMixin {
  final _portal = OverlayPortalController();

  /// Brings the tour in as it starts, and takes it away as it ends.
  late final _shown = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..addStatusListener(_shownChanged);
  late final _fade = CurvedAnimation(parent: _shown, curve: Curves.easeOut);

  /// Takes the spotlight from one step's target on to the next one's.
  late final _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1,
  );

  /// Plays the step's demo, over and over.
  late final _demo = AnimationController(vsync: this);

  /// Looks for the step's target each frame, as it can still be settling
  /// into place as the step starts, and moves when the phone turns.
  late final _measuring = createTicker((_) => _measure());

  /// The step on show, which stays on while the tour fades away.
  TourStep? _step;
  int _index = 0;
  int _count = 0;

  /// The demo of the step before, which fades away where it was as the
  /// spotlight moves on to a step without one.
  TourDemo? _leaving;
  Rect? _leavingAt;

  /// Whether the step before had a demo, so this one's copy is already
  /// there, rather than fading in.
  bool _hadDemo = false;

  /// Where the step's target is; where its demo's copy is, at rest; and
  /// where the finger touches the copy, from its top left corner.
  Rect? _target;
  Rect? _copy;
  Offset? _touch;

  /// The spotlight as the step began, which it moves on from: where it was,
  /// how round, and how much of the page's background filled it.
  Rect? _fromHole;
  double _fromRadius = 0;
  double _fromFill = 0;

  /// What the finger does in the step's demo, and for how long in all.
  List<_Beat> _beats = const [];
  int _beatsLength = 0;

  bool _reduceMotion = false;

  final _copyKey = GlobalKey();
  final _copyContentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(Tour oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _changed();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _measuring.dispose();
    _demo.dispose();
    _move.dispose();
    _fade.dispose();
    _shown.dispose();
    super.dispose();
  }

  void _changed() {
    final controller = widget.controller;
    final step = controller.step;
    if (step == null) {
      // Back takes the page's usual way again, and the tour fades away.
      setState(() {});
      if (_step != null) _shown.reverse();
      return;
    }
    if (identical(step, _step) && controller.index == _index) return;
    final starting = _step == null || !_shown.isForwardOrCompleted;
    final previous = _step;
    setState(() {
      if (starting) {
        _leaving = null;
        _hadDemo = false;
        _fromHole = null;
        _target = null;
        _copy = null;
        _touch = null;
      } else {
        final t = _eased;
        _fromHole = _holeAt(t);
        _fromRadius = _radiusAt(t);
        _fromFill = _fillAt(t);
        _hadDemo = previous?.demo != null;
        final leavingAt = _target == null || previous?.demo == null
            ? null
            : _placeOf(previous!.demo!, _target!);
        _leaving = step.demo == null ? previous?.demo : null;
        _leavingAt = leavingAt;
        if (step.demo == null) _copy = null;
        _touch = null;
      }
      _step = step;
      _index = controller.index;
      _count = controller.steps.length;
    });
    if (starting) {
      _portal.show();
      _move.value = 1;
      _shown.forward();
      if (!_measuring.isActive) _measuring.start();
    } else if (_reduceMotion) {
      _move.value = 1;
    } else {
      _move.forward(from: 0);
    }
    _measure();
    _play(step.demo);
  }

  void _shownChanged(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || widget.controller.isActive) {
      return;
    }
    _portal.hide();
    _measuring.stop();
    _demo.stop();
    setState(() {
      _step = null;
      _leaving = null;
    });
  }

  /// Plays [demo] from the start, over and over.
  void _play(TourDemo? demo) {
    _demo.stop();
    if (demo == null || _reduceMotion) {
      _beats = const [];
      _beatsLength = 0;
      return;
    }
    _beats = _beatsOf(demo.gestures);
    _beatsLength = _beats.fold(0, (length, beat) => length + beat.ms);
    _demo
      ..duration = Duration(milliseconds: _beatsLength)
      ..value = 0
      ..repeat();
  }

  /// Where [demo]'s copy goes, for a target at [target].
  Rect _placeOf(TourDemo demo, Rect target) =>
      demo.place?.call(context, target) ?? target;

  /// Reads where the step's target and its copy are, and skips a step whose
  /// target isn't on the page.
  void _measure() {
    final step = _step;
    if (step == null || !mounted) return;
    final target = _rectOf(step.target.currentContext);
    if (target == null) {
      if (identical(widget.controller.step, step)) widget.controller.next();
      return;
    }
    final demo = step.demo;
    final copy = demo == null ? null : _rectOf(_copyKey.currentContext);
    final touch = demo == null ? null : _touchOf(demo);
    if (target != _target ||
        (copy != null && copy != _copy) ||
        touch != _touch) {
      setState(() {
        _target = target;
        _copy = copy ?? _copy;
        _touch = touch;
      });
    }
  }

  /// Where the widget of [context] is in the overlay the tour is drawn on.
  Rect? _rectOf(BuildContext? context) {
    final box = context?.findRenderObject();
    final overlay = Overlay.maybeOf(this.context)?.context.findRenderObject();
    if (box is! RenderBox ||
        overlay is! RenderBox ||
        !box.attached ||
        !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  }

  /// Where the finger touches [demo]'s copy, from the copy's top left corner
  /// as it is at rest.
  Offset? _touchOf(TourDemo demo) {
    final copy = _copyContentKey.currentContext?.findRenderObject();
    if (copy is! RenderBox || !copy.attached || !copy.hasSize) return null;
    var area = Offset.zero & copy.size;
    final part = demo.touch?.currentContext?.findRenderObject();
    if (part is RenderBox && part.attached && part.hasSize) {
      area = MatrixUtils.transformRect(
          part.getTransformTo(copy), Offset.zero & part.size);
    }
    return demo.touchAlignment.withinRect(area) + demo.touchOffset;
  }

  /// How far the spotlight has got from the step before to this one.
  double get _eased => Curves.easeInOutCubic.transform(_move.value);

  /// Where the spotlight goes for the step on show, once its target is found.
  Rect? get _spot {
    final step = _step;
    final rect = step?.demo == null ? _target : _copy;
    return rect?.inflate(step!.padding);
  }

  /// [spot], and as far up and down as the step's demo carries its copy, so
  /// the tip can keep out of its way.
  Rect _reach(Rect spot) {
    final height = _copy?.height ?? spot.height;
    var y = 0.0;
    var up = 0.0;
    var down = 0.0;
    for (final beat in _beats) {
      if (beat.move != _Move.carry) continue;
      y += beat.by.dy * math.min(height, _Beat._maxCarry);
      up = math.min(up, y);
      down = math.max(down, y);
    }
    return Rect.fromLTRB(
        spot.left, spot.top + up, spot.right, spot.bottom + down);
  }

  Rect? _holeAt(double t) {
    final from = _fromHole;
    final to = _spot;
    if (from == null || to == null) return to ?? from;
    return Rect.lerp(from, to, t);
  }

  double _radiusAt(double t) {
    final step = _step!;
    final to = step.radius + step.padding;
    return _fromHole == null ? to : _fromRadius + (to - _fromRadius) * t;
  }

  /// How much of the page's background fills the spotlight: all of it under
  /// a demo's copy, which covers what it's a copy of; none of it over what's
  /// really there.
  double _fillAt(double t) {
    final to = _step?.demo == null ? 0.0 : 1.0;
    return _fromHole == null ? to : _fromFill + (to - _fromFill) * t;
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.controller.isActive;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: PopScope(
        canPop: !active,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) widget.controller.end();
        },
        child: ExcludeSemantics(excluding: active, child: widget.child),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final step = _step;
    if (step == null) return const SizedBox.shrink();
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final dim = Colors.black.withValues(alpha: isDarkTheme ? 0.62 : 0.5);
    final background = context.colors.pageBackground;
    return FadeTransition(
      opacity: _fade,
      child: IgnorePointer(
        ignoring: !widget.controller.isActive,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.controller.next,
                child: AnimatedBuilder(
                  animation: _move,
                  builder: (context, child) {
                    final t = _eased;
                    return CustomPaint(
                      painter: _SpotlightPainter(
                        hole: _holeAt(t),
                        radius: _radiusAt(t),
                        dim: dim,
                        fill: background.withValues(
                            alpha: background.a * _fillAt(t)),
                      ),
                    );
                  },
                ),
              ),
              IgnorePointer(
                child: ExcludeSemantics(child: _buildDemo(context, step)),
              ),
              _buildTip(context, step),
            ],
          ),
        ),
      ),
    );
  }

  /// The step's copy acting out its gestures under the finger, or the step
  /// before's fading away.
  Widget _buildDemo(BuildContext context, TourStep step) {
    final demo = step.demo ?? _leaving;
    final target = _target;
    final at = step.demo == null
        ? _leavingAt
        : target == null
            ? null
            : _placeOf(demo!, target);
    if (demo == null || at == null) return const SizedBox.shrink();
    final leaving = step.demo == null;
    return AnimatedBuilder(
      animation: Listenable.merge([_move, _demo]),
      builder: (context, child) {
        final t = _eased;
        final opacity = leaving
            ? 1 - t
            : _hadDemo
                ? 1.0
                : t;
        if (opacity <= 0) return const SizedBox.shrink();
        final copy = _copy;
        final frame = leaving || _beats.isEmpty
            ? _Frame()
            : _frameAt(
                _beats, _demo.value * _beatsLength, copy?.size ?? at.size);
        final touch = _touch;
        final scale = (1 - (1 - demo.pressedScale) * frame.pressed) *
            (1 + 0.03 * frame.lift);
        return Stack(
          children: [
            if (demo.behind != null && copy != null && frame.behind > 0)
              Positioned.fromRect(
                rect: copy,
                child: Opacity(
                  opacity: opacity * frame.behind,
                  child: demo.behind,
                ),
              ),
            Positioned(
              left: at.left,
              top: at.top,
              width: at.width,
              child: Opacity(
                opacity: opacity * frame.shown,
                child: KeyedSubtree(
                  key: _copyKey,
                  child: Transform.translate(
                    offset: frame.moved,
                    child: Transform.scale(
                      scale: scale,
                      child: _Lifted(
                        lift: frame.lift,
                        radius: step.radius,
                        child: KeyedSubtree(
                          key: _copyContentKey,
                          child: demo.builder(
                              context, TourPose(acted: frame.acted)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!leaving && copy != null && touch != null)
              Positioned(
                left: copy.left + touch.dx + frame.at.dx - _Finger.size / 2,
                top: copy.top + touch.dy + frame.at.dy - _Finger.size / 2,
                child: Opacity(opacity: opacity, child: _Finger(frame: frame)),
              ),
          ],
        );
      },
    );
  }

  /// The step's tip, beside the spotlight. The tip before fades out as this
  /// one fades in, once the spotlight is nearly there.
  Widget _buildTip(BuildContext context, TourStep step) {
    final spot = _spot;
    final reach = spot == null ? null : _reach(spot);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 200),
      switchInCurve: const Interval(0.4, 1, curve: Curves.easeOut),
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, if (current != null) current],
      ),
      child: reach == null
          ? const SizedBox.shrink()
          : _TipPlacement(
              key: ValueKey(_index),
              spot: reach,
              builder: (context, arrowX, pointsUp) => _Tip(
                step: step,
                index: _index,
                count: _count,
                arrowX: arrowX,
                pointsUp: pointsUp,
                onNext: widget.controller.next,
                onSkip: widget.controller.end,
              ),
            ),
    );
  }
}

/// The page, dimmed, but for a spotlight on [hole], with [radius] corners,
/// lit by a faint rim, and filled with [fill].
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.hole,
    required this.radius,
    required this.dim,
    required this.fill,
  });

  final Rect? hole;
  final double radius;
  final Color dim;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final hole = this.hole;
    if (hole == null || hole.isEmpty) {
      canvas.drawRect(bounds, Paint()..color = dim);
      return;
    }
    final outline = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(
          Radius.circular(math.min(radius, hole.shortestSide / 2))),
    ).getOuterPath(hole);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(bounds)
        ..addPath(outline, Offset.zero),
      Paint()..color = dim,
    );
    if (fill.a > 0) canvas.drawPath(outline, Paint()..color = fill);
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole ||
      oldDelegate.radius != radius ||
      oldDelegate.dim != dim ||
      oldDelegate.fill != fill;
}

/// [child] with the shadow of a card picked up off a list, deepening with
/// [lift], under its [radius] corners.
class _Lifted extends StatelessWidget {
  const _Lifted(
      {required this.lift, required this.radius, required this.child});

  final double lift;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
        shadows: lift == 0
            ? null
            : [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: (isDarkTheme ? 0.5 : 0.18) * lift),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// What the finger does for [ms] milliseconds of a demo.
class _Beat {
  const _Beat(this.move, this.ms, {this.by = Offset.zero});

  final _Move move;
  final int ms;

  /// How far a [_Move.carry] takes the finger: across, as a share of the
  /// copy's width, and down, as a share of its height, up to [_maxCarry].
  final Offset by;

  static const _maxCarry = 88.0;
}

enum _Move {
  /// Nothing happens.
  rest,

  /// The finger comes down onto the copy.
  arrive,

  /// The finger presses down.
  press,

  /// The finger lifts off after a tap, which the copy acts on.
  tapUp,

  /// The finger holds on, as the ring around it fills.
  hold,

  /// The hold becomes a long press, which the copy acts on.
  fire,

  /// The long press picks the copy up, which the copy acts on.
  pickUp,

  /// The finger moves, by [_Beat.by], taking the copy with it.
  carry,

  /// The copy is put down where it was picked up.
  putDown,

  /// The finger lifts off, leaving the copy as it is.
  release,

  /// The finger lets go mid-swipe, which sends the copy away.
  fling,

  /// The copy comes back, as the demo starts over.
  restore,

  /// The finger leaves.
  leave,
}

/// The beats of acting out [gestures], one after another, with a pause
/// before and after them all.
List<_Beat> _beatsOf(List<TourGesture> gestures) => [
      const _Beat(_Move.rest, 450),
      const _Beat(_Move.arrive, 320),
      for (final (index, gesture) in gestures.indexed) ...[
        if (index > 0) const _Beat(_Move.rest, 250),
        ...switch (gesture) {
          TourGesture.tap => const [
              _Beat(_Move.press, 130),
              _Beat(_Move.tapUp, 400),
              _Beat(_Move.rest, 650),
            ],
          TourGesture.hold => const [
              _Beat(_Move.press, 130),
              _Beat(_Move.hold, 600),
              _Beat(_Move.fire, 380),
              _Beat(_Move.release, 220),
              _Beat(_Move.rest, 500),
            ],
          TourGesture.drag => const [
              _Beat(_Move.press, 130),
              _Beat(_Move.hold, 450),
              _Beat(_Move.pickUp, 280),
              _Beat(_Move.carry, 600, by: Offset(0, 1)),
              _Beat(_Move.rest, 250),
              _Beat(_Move.carry, 600, by: Offset(0, -1)),
              _Beat(_Move.putDown, 260),
              _Beat(_Move.release, 220),
              _Beat(_Move.rest, 400),
            ],
          TourGesture.swipe => const [
              _Beat(_Move.press, 120),
              _Beat(_Move.carry, 520, by: Offset(-0.45, 0)),
              _Beat(_Move.fling, 280),
              _Beat(_Move.rest, 650),
              _Beat(_Move.restore, 560),
              _Beat(_Move.rest, 300),
            ],
        },
      ],
      const _Beat(_Move.leave, 300),
      const _Beat(_Move.rest, 700),
    ];

/// Where the finger and the copy are, at a moment of a demo.
class _Frame {
  /// How much of the finger shows, and how far it is from where it touches.
  double finger = 0;
  Offset at = Offset.zero;

  /// How far the finger is pressed down.
  double down = 0;

  /// How far the ring around a holding finger has filled, and how much of
  /// it shows.
  double ring = 0;
  double ringShown = 1;

  /// How far the ripple of a finger lifting off has spread, or negative
  /// while there's none.
  double ripple = -1;

  /// How far the copy is pressed in, and picked up.
  double pressed = 0;
  double lift = 0;

  /// How far the copy has moved, how much of it shows, and how much of what
  /// it uncovers.
  Offset moved = Offset.zero;
  double shown = 1;
  double behind = 0;

  /// How many of the gestures are done.
  int acted = 0;
}

/// The demo at [ms] milliseconds into [beats], acted out on a copy of
/// [size].
_Frame _frameAt(List<_Beat> beats, double ms, Size size) {
  final frame = _Frame();
  var start = 0.0;
  for (final beat in beats) {
    if (ms < start) break;
    final t = beat.ms == 0 ? 1.0 : ((ms - start) / beat.ms).clamp(0.0, 1.0);
    _act(beat, t, frame, size);
    start += beat.ms;
  }
  return frame;
}

/// Plays [beat] on [frame], [t] of the way through it.
void _act(_Beat beat, double t, _Frame frame, Size size) {
  double part(double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);
  switch (beat.move) {
    case _Move.rest:
      break;
    case _Move.arrive:
      frame.finger = Curves.easeOut.transform(t);
      frame.at = Offset.lerp(
          const Offset(18, 26), Offset.zero, Curves.easeOutCubic.transform(t))!;
    case _Move.press:
      final down = Curves.easeOut.transform(t);
      frame
        ..down = down
        ..pressed = down
        ..ring = 0
        ..ringShown = 1
        ..ripple = -1;
    case _Move.tapUp:
      if (t > 0) frame.acted++;
      final up = Curves.easeOut.transform(part(0, 0.4));
      frame
        ..down = 1 - up
        ..pressed = 1 - up
        ..ripple = t < 1 ? t : -1;
    case _Move.hold:
      frame.ring = t;
    case _Move.fire:
      if (t > 0) frame.acted++;
      final fired = Curves.easeOut.transform(part(0, 0.5));
      frame
        ..ringShown = 1 - fired
        ..pressed = 1 - fired
        ..ripple = t < 1 ? t : -1;
    case _Move.pickUp:
      if (t > 0) frame.acted++;
      final lift = Curves.easeOutCubic.transform(t);
      frame
        ..lift = lift
        ..pressed = 1 - lift
        ..ringShown = 1 - lift;
    case _Move.carry:
      final by = Offset(beat.by.dx * size.width,
          beat.by.dy * math.min(size.height, _Beat._maxCarry));
      final moved = by * Curves.easeInOutCubic.transform(t);
      frame
        ..at += moved
        ..moved += moved;
      if (frame.lift == 0) {
        // A swipe, rather than a drag, which a card doesn't shrink for.
        frame
          ..behind = 1
          ..pressed *= 1 - part(0, 0.3);
      }
    case _Move.putDown:
      frame.lift = 1 - Curves.easeOutCubic.transform(t);
    case _Move.release:
      frame.down = 1 - Curves.easeOut.transform(t);
    case _Move.fling:
      final away = Curves.easeIn.transform(t);
      frame
        ..moved = Offset.lerp(frame.moved,
            Offset(size.width * 1.1 * frame.moved.dx.sign, 0), away)!
        ..at += Offset(-28 * t, 0)
        ..finger *= 1 - Curves.easeOut.transform(t)
        ..down = 1 - t
        ..pressed = 0;
    case _Move.restore:
      // What was uncovered goes first, so the copy doesn't fade in over it.
      frame
        ..moved = Offset.zero
        ..behind = 1 - Curves.easeOut.transform(part(0, 0.45))
        ..shown = Curves.easeOut.transform(part(0.45, 1));
    case _Move.leave:
      frame
        ..finger *= 1 - Curves.easeIn.transform(t)
        ..at += Offset(10, 16) * t;
  }
}

/// A fingertip on the screen, with the ring that fills as it holds on and
/// the ripple it leaves as it lifts off.
class _Finger extends StatelessWidget {
  const _Finger({required this.frame});

  /// How big a box the finger needs, ripple and all.
  static const size = 88.0;

  final _Frame frame;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _FingerPainter(
          shown: frame.finger,
          down: frame.down,
          ring: frame.ring,
          ringShown: frame.ringShown,
          ripple: frame.ripple,
        ),
      ),
    );
  }
}

class _FingerPainter extends CustomPainter {
  const _FingerPainter({
    required this.shown,
    required this.down,
    required this.ring,
    required this.ringShown,
    required this.ripple,
  });

  static const _radius = 18.0;

  final double shown;
  final double down;
  final double ring;
  final double ringShown;
  final double ripple;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (ripple >= 0) {
      canvas.drawCircle(
        center,
        _radius + 22 * Curves.easeOut.transform(ripple),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.75 * (1 - ripple)),
      );
    }
    if (shown <= 0) return;
    final ringAlpha = shown * ringShown;
    if (ring > 0 && ringAlpha > 0) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, _radius + 8,
          ringPaint..color = Colors.white.withValues(alpha: 0.3 * ringAlpha));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: _radius + 8),
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        ringPaint
          ..strokeCap = StrokeCap.round
          ..color = _highlight.withValues(alpha: ringAlpha),
      );
    }
    // Squashed a little as it presses down.
    final radius = _radius * (1 - 0.15 * down);
    canvas.drawCircle(
      center + const Offset(0, 3),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25 * shown)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // iOS's system grey shows on white cards and dark ones alike.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xff8E8E93)
            .withValues(alpha: (0.5 + 0.2 * down) * shown),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.92 * shown),
    );
  }

  @override
  bool shouldRepaint(_FingerPainter oldDelegate) =>
      oldDelegate.shown != shown ||
      oldDelegate.down != down ||
      oldDelegate.ring != ring ||
      oldDelegate.ringShown != ringShown ||
      oldDelegate.ripple != ripple;
}

/// Puts the tip [builder] builds beside [spot]: under it, or over it when
/// there's more room there, as wide as fits up to a phone's width, and
/// centred on it as far as the screen's edges let it be.
class _TipPlacement extends StatelessWidget {
  const _TipPlacement({super.key, required this.spot, required this.builder});

  final Rect spot;

  /// Builds the tip, with its arrow [arrowX] from its left edge, pointing up
  /// at the spot from under it, or down from over it.
  final Widget Function(BuildContext context, double arrowX, bool pointsUp)
      builder;

  /// The room between the tip's arrow and the spotlight, and between the tip
  /// and the screen's edges.
  static const _gap = 6.0;
  static const _margin = 16.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final minLeft = _margin + padding.left;
    final maxRight = size.width - _margin - padding.right;
    final width = math.min(maxRight - minLeft, 380.0);
    final left = clampDouble(spot.center.dx - width / 2, minLeft,
        math.max(minLeft, maxRight - width));
    final pointsUp =
        size.height - padding.bottom - spot.bottom >= spot.top - padding.top;
    return CustomSingleChildLayout(
      delegate: _TipLayout(
        spot: spot,
        left: left,
        width: width,
        below: pointsUp,
        minTop: padding.top + _gap,
        maxBottom: size.height - padding.bottom - _gap,
      ),
      child: builder(context, spot.center.dx - left, pointsUp),
    );
  }
}

class _TipLayout extends SingleChildLayoutDelegate {
  const _TipLayout({
    required this.spot,
    required this.left,
    required this.width,
    required this.below,
    required this.minTop,
    required this.maxBottom,
  });

  final Rect spot;
  final double left;
  final double width;
  final bool below;
  final double minTop;
  final double maxBottom;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(0, maxBottom - minTop),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final top = below
        ? spot.bottom + _TipPlacement._gap
        : spot.top - _TipPlacement._gap - childSize.height;
    return Offset(left,
        top.clamp(minTop, math.max(minTop, maxBottom - childSize.height)));
  }

  @override
  bool shouldRelayout(_TipLayout oldDelegate) =>
      oldDelegate.spot != spot ||
      oldDelegate.left != left ||
      oldDelegate.width != width ||
      oldDelegate.below != below ||
      oldDelegate.minTop != minTop ||
      oldDelegate.maxBottom != maxBottom;
}

/// A step's tip, a bubble pointing at the spotlight: the step's icon, title
/// and message, how far through the tour it is, and buttons to skip the
/// rest of the tour or go on.
class _Tip extends StatelessWidget {
  const _Tip({
    required this.step,
    required this.index,
    required this.count,
    required this.arrowX,
    required this.pointsUp,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int count;
  final double arrowX;
  final bool pointsUp;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final ink = context.colors.wB;
    final last = index == count - 1;
    const arrow = _TipBorder.arrowHeight;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: _TipBorder(
            arrowX: arrowX,
            pointsUp: pointsUp,
            side: BorderSide(
              width: 0.5,
              color: ink.withValues(alpha: isDarkTheme ? 0.12 : 0.06),
            ),
          ),
          // Solid rather than glass, as the page behind it is dimmed.
          color: isDarkTheme ? const Color(0xff2C2C2E) : Colors.white,
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkTheme ? 0.5 : 0.22),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16 + (pointsUp ? arrow : 0), 12, 12 + (pointsUp ? 0 : arrow)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TipIcon(icon: step.icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              color: ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            step.message,
                            style: TextStyle(
                              color: ink.withValues(alpha: 0.62),
                              fontSize: 15,
                              height: 1.35,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 2),
                  _Dots(index: index, count: count),
                  const Spacer(),
                  if (!last) _TipButton(label: "Skip", onPressed: onSkip),
                  const SizedBox(width: 4),
                  _TipButton(
                    label: last ? "Done" : "Next",
                    filled: true,
                    onPressed: onNext,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A step's icon on a tile in the add button's blues.
class _TipIcon extends StatelessWidget {
  const _TipIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 36,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(11)),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_accent, Color.lerp(_accent, _highlight, 0.7)!],
          ),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

/// A dot for each step of the tour, the one on show drawn longer.
class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return Semantics(
      label: "Tip ${index + 1} of $count",
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var dot = 0; dot < count; dot++)
            Container(
              margin: const EdgeInsets.only(right: 5),
              width: dot == index ? 16 : 6,
              height: 6,
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: dot == index
                    ? context.colors.moreLess
                    : ink.withValues(alpha: 0.18),
              ),
            ),
        ],
      ),
    );
  }
}

/// A capsule button on a tip: filled in the add button's blues, or plain.
class _TipButton extends StatelessWidget {
  const _TipButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    const shape = StadiumBorder();
    return Semantics(
      button: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          gradient: filled
              ? LinearGradient(
                  colors: [_accent, Color.lerp(_accent, _highlight, 0.7)!],
                )
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            customBorder: shape,
            splashFactory: NoSplash.splashFactory,
            highlightColor:
                (filled ? Colors.white : ink).withValues(alpha: 0.12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(
                      color:
                          filled ? Colors.white : ink.withValues(alpha: 0.55),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tip's outline: a box with continuous corners, and an arrow [arrowX]
/// from its left edge, out of its top or its bottom.
class _TipBorder extends ShapeBorder {
  const _TipBorder({
    required this.arrowX,
    required this.pointsUp,
    this.side = BorderSide.none,
  });

  static const arrowHeight = 9.0;
  static const _arrowWidth = 24.0;
  static const _radius = 20.0;

  final double arrowX;
  final bool pointsUp;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(
        top: pointsUp ? arrowHeight : 0,
        bottom: pointsUp ? 0 : arrowHeight,
      );

  Path _outline(Rect rect) {
    final body = pointsUp
        ? Rect.fromLTRB(
            rect.left, rect.top + arrowHeight, rect.right, rect.bottom)
        : Rect.fromLTRB(
            rect.left, rect.top, rect.right, rect.bottom - arrowHeight);
    // Clear of the corners, which it would otherwise stick out of.
    const inset = _radius + _arrowWidth / 2;
    final x =
        rect.left + arrowX.clamp(inset, math.max(inset, rect.width - inset));
    // A little into the box, so the two join without a seam.
    final base = pointsUp ? body.top + 1 : body.bottom - 1;
    final tip = pointsUp ? rect.top : rect.bottom;
    const half = _arrowWidth / 2;
    final arrow = Path()
      ..moveTo(x - half, base)
      ..cubicTo(x - half + 6, base, x - 4, tip, x, tip)
      ..cubicTo(x + 4, tip, x + half - 6, base, x + half, base)
      ..close();
    return Path.combine(
      PathOperation.union,
      const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(_radius)),
      ).getOuterPath(body),
      arrow,
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect.deflate(side.width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_outline(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) =>
      _TipBorder(arrowX: arrowX, pointsUp: pointsUp, side: side.scale(t));
}
