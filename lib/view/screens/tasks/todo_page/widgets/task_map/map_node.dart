import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

import '../../../../../../core/extensions/theme_extensions.dart';
import '../../../../../../models/task_tree.dart';
import '../../../../../../models/todo_item.dart';
import '../../../../../widgets/check_circle.dart';
import '../../../../../widgets/progress_ring.dart';
import '../task_card.dart';
import 'map_layout.dart';

/// The colours of the map's branches, one for each task of its own in turn,
/// which its subtasks share: iOS's system colours, as on the profile page's
/// settings, and their brighter versions for dark pages.
const _branchColors = [
  (Color(0xff007AFF), Color(0xff0A84FF)),
  (Color(0xffAF52DE), Color(0xffBF5AF2)),
  (Color(0xffFF9500), Color(0xffFF9F0A)),
  (Color(0xff34C759), Color(0xff30D158)),
  (Color(0xffFF2D55), Color(0xffFF375F)),
  (Color(0xff30B0C7), Color(0xff40C8E0)),
  (Color(0xff5856D6), Color(0xff5E5CE6)),
  (Color(0xff00C7BE), Color(0xff63E6E2)),
];

/// The colour of the centre's branch number [branch].
Color mapBranchColor(int branch, {required bool isDarkTheme}) {
  final (light, dark) = _branchColors[branch % _branchColors.length];
  return isDarkTheme ? dark : light;
}

/// iOS's system red, a touch brighter on dark pages, as there.
Color _systemRed(bool isDarkTheme) =>
    isDarkTheme ? const Color(0xffFF453A) : const Color(0xffFF3B30);

/// A few words about a task under its title on the map, after an icon, or
/// the icon alone.
class MapNodeBit {
  const MapNodeBit(this.icon, [this.label, this.urgent = false]);

  final IconData icon;
  final String? label;

  /// Whether it's something to see to, drawn in red: a time that's gone.
  final bool urgent;
}

/// How a task is drawn on the map, which says how big it is there: the map
/// is laid out from the tasks' sizes, before any of them is built.
class MapNodeStyle {
  MapNodeStyle.of(BuildContext context)
      : _base = DefaultTextStyle.of(context).style,
        _scaler = MediaQuery.textScalerOf(context),
        _direction = Directionality.of(context);

  final TextStyle _base;
  final TextScaler _scaler;
  final TextDirection _direction;

  /// The size of a task's check, the room around what's in its box, and
  /// between its check and its title.
  static const check = 22.0;
  static const padding = EdgeInsets.fromLTRB(10, 9, 13, 9);
  static const checkGap = 9.0;

  /// How wide a title gets before it goes on to a second line, which is as
  /// far as it goes.
  static const maxTitleWidth = 172.0;
  static const _minWidth = 92.0;
  static const _minHeight = 42.0;

  /// The size of a bit's icon, the room between it and its words, and
  /// between bits.
  static const bitIcon = 13.0;
  static const bitGap = 3.0;
  static const bitsGap = 9.0;

  /// The room between a title and the bits under it.
  static const titleGap = 4.0;

  /// A task of its own stands out a little from the tasks in it.
  TextStyle titleOf(TaskNode node) => _base.merge(TextStyle(
        fontSize: node.depth == 0 ? 15.5 : 14.5,
        fontWeight: node.depth == 0 ? FontWeight.w700 : FontWeight.w600,
        height: 1.22,
        letterSpacing: -0.2,
      ));

  TextStyle get bit => _base.merge(const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: 0,
        fontFeatures: [FontFeature.tabularFigures()],
      ));

  /// What the map says under [node]'s title, as of [now]: when it's for,
  /// that it repeats or reminds, and how many of its subtasks are done.
  static List<MapNodeBit> bitsOf(TaskNode node, DateTime now) {
    final task = node.task;
    final when = taskWhenLabel(task, now);
    return [
      if (when != null)
        MapNodeBit(
          task.day == null
              ? Icons.schedule_rounded
              : Icons.calendar_today_rounded,
          when,
          task.isPastDue(now) && !task.done,
        ),
      if (task.reminder == Reminder.daily)
        const MapNodeBit(Icons.repeat_rounded)
      else if (task.reminder == Reminder.once)
        const MapNodeBit(Icons.notifications_active_rounded),
      if (node.subtaskCount > 0)
        MapNodeBit(Icons.account_tree_rounded,
            "${node.doneSubtaskCount}/${node.subtaskCount}"),
    ];
  }

  TextPainter _painter(String text, TextStyle style, {int maxLines = 1}) =>
      TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: maxLines,
        ellipsis: "…",
        textDirection: _direction,
        textScaler: _scaler,
        textWidthBasis: TextWidthBasis.longestLine,
      );

  /// How big [node]'s box is, with [bits] under its title.
  Size sizeOf(TaskNode node, List<MapNodeBit> bits) {
    final title = _painter(node.task.title, titleOf(node), maxLines: 2)
      ..layout(maxWidth: maxTitleWidth);
    var width = title.width.ceilToDouble();
    var height = title.height.ceilToDouble();
    title.dispose();
    if (bits.isNotEmpty) {
      var bitsWidth = bitsGap * (bits.length - 1);
      var bitsHeight = bitIcon;
      for (final bit in bits) {
        bitsWidth += bitIcon;
        final label = bit.label;
        if (label == null) continue;
        final words = _painter(label, this.bit)..layout();
        bitsWidth += bitGap + words.width.ceilToDouble();
        bitsHeight = math.max(bitsHeight, words.height.ceilToDouble());
        words.dispose();
      }
      width = math.max(width, math.min(bitsWidth, maxTitleWidth));
      height += titleGap + bitsHeight;
    }
    return Size(
      math.max(
          _minWidth, padding.left + check + checkGap + width + padding.right),
      math.max(_minHeight, padding.vertical + height),
    );
  }

  /// What tells one way of drawing the tasks from another, which changes
  /// their sizes.
  Object get signature => (_base, _scaler, _direction);
}

/// A task on the map: its check, which a tap fills in, its title, and a
/// few words under it. One of the centre's own branches is tinted with its
/// branch's [color]; the tasks further out are plain, on the lines of that
/// colour that lead to them.
class MapNodeCard extends StatelessWidget {
  const MapNodeCard({
    super.key,
    required this.node,
    required this.bits,
    required this.style,
    required this.color,
    this.selected = false,
    this.lifted = false,
    this.targeted = false,
    this.onCheck,
  });

  static const shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );

  final TaskNode node;
  final List<MapNodeBit> bits;
  final MapNodeStyle style;
  final Color color;

  /// Whether it's the task the map's buttons act on, ringed with the accent.
  final bool selected;

  /// Whether it's been picked up, to be moved to another task.
  final bool lifted;

  /// Whether a task being moved would go into it if dropped now.
  final bool targeted;

  /// Marks the task done, or not done again, on a tap of its check.
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final ink = context.colors.wB;
    final accent = context.colors.moreLess;
    final task = node.task;
    final top = node.depth == 0;
    final surface = isDarkTheme ? context.colors.cardBackground : Colors.white;
    final fill = top
        ? Color.alphaBlend(
            color.withValues(alpha: isDarkTheme ? 0.2 : 0.12), surface)
        : surface;
    final ringed = selected || targeted;
    final edge = ringed
        ? accent
        : top
            ? color.withValues(alpha: isDarkTheme ? 0.6 : 0.5)
            : ink.withValues(alpha: isDarkTheme ? 0.14 : 0.09);
    return TweenAnimationBuilder<double>(
      // Eases between the to-do and done looks, as a card does.
      tween: Tween(end: task.done ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, doneness, child) {
        Color fade(double alpha, double doneAlpha) =>
            ink.withValues(alpha: lerpDouble(alpha, doneAlpha, doneness));
        final strength = lerpDouble(1, 0.55, doneness)!;
        return DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape.copyWith(
              side: BorderSide(color: edge, width: ringed ? 2 : 1),
            ),
            color: fill,
            shadows: [
              if (ringed)
                BoxShadow(
                  color: accent.withValues(alpha: isDarkTheme ? 0.35 : 0.28),
                  blurRadius: 14,
                ),
              if (lifted)
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDarkTheme ? 0.5 : 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                )
              else if (!isDarkTheme)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 12,
                  spreadRadius: -3,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The check takes taps from the box's edge to the title, as
              // it's small for a fingertip.
              Semantics(
                container: true,
                button: onCheck != null,
                checked: task.done,
                label: "Done",
                onTap: onCheck,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCheck,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: MapNodeStyle.padding.left,
                      right: MapNodeStyle.checkGap,
                    ),
                    child: Center(
                      child: CheckCircle(
                          doneness: doneness, size: MapNodeStyle.check),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MapNodeStyle.padding.top,
                    right: MapNodeStyle.padding.right,
                    bottom: MapNodeStyle.padding.bottom,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textWidthBasis: TextWidthBasis.longestLine,
                          style: style.titleOf(node).copyWith(
                                color: fade(1, 0.4),
                                decoration: doneness > 0
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                // Never fully clear, which the engine takes
                                // as no colour, drawing the line in the
                                // text's.
                                decorationColor: ink.withValues(
                                    alpha: math.max(0.4 * doneness, 1 / 255)),
                                decorationThickness: 1.5,
                              ),
                        ),
                      ),
                      if (bits.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: MapNodeStyle.titleGap),
                          child: _Bits(
                            bits: bits,
                            style: style.bit,
                            color: ink.withValues(alpha: 0.55 * strength),
                            urgent: _systemRed(isDarkTheme)
                                .withValues(alpha: strength),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The few words under a task's title, each after its icon, on one line.
class _Bits extends StatelessWidget {
  const _Bits({
    required this.bits,
    required this.style,
    required this.color,
    required this.urgent,
  });

  final List<MapNodeBit> bits;
  final TextStyle style;
  final Color color;
  final Color urgent;

  Widget _words(String label, MapNodeBit bit) => Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style.copyWith(color: bit.urgent ? urgent : color),
      );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, bit) in bits.indexed) ...[
          if (index > 0) const SizedBox(width: MapNodeStyle.bitsGap),
          Icon(bit.icon,
              size: MapNodeStyle.bitIcon, color: bit.urgent ? urgent : color),
          if (bit.label case final label?) ...[
            const SizedBox(width: MapNodeStyle.bitGap),
            // Only the first gives way when they don't all fit: when the
            // task is for, which is the long one.
            if (index == 0)
              Flexible(child: _words(label, bit))
            else
              _words(label, bit),
          ],
        ],
      ],
    );
  }
}

/// The middle of the map, which every task of its own branches off: how far
/// through all their tasks the user is, as on the list's summary.
class MapHub extends StatelessWidget {
  const MapHub({
    super.key,
    required this.done,
    required this.total,
    this.targeted = false,
  });

  final int done;
  final int total;

  /// Whether a task being moved would become a task of its own if dropped
  /// now.
  final bool targeted;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final accent = context.colors.moreLess;
    const size = MapLayout.hubRadius * 2;
    return Semantics(
      label: total == 0
          ? "No tasks"
          : "$done of ${total == 1 ? "1 task" : "$total tasks"} done",
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDarkTheme ? context.colors.cardBackground : Colors.white,
          border: targeted ? Border.all(color: accent, width: 2) : null,
          boxShadow: [
            if (targeted)
              BoxShadow(
                color: accent.withValues(alpha: isDarkTheme ? 0.4 : 0.3),
                blurRadius: 18,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkTheme ? 0.4 : 0.1),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          // Fills up from empty as the map opens, then follows the counts
          // as tasks get done.
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: total == 0 ? 0.0 : done / total),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) =>
                ProgressRing(progress: value, size: size - 14),
          ),
        ),
      ),
    );
  }
}

/// The knob on the far side of a task with subtasks, which folds them away
/// into it, or brings them back out: how many are folded away in it, or a
/// line to fold them along.
class MapKnob extends StatelessWidget {
  const MapKnob({
    super.key,
    required this.folded,
    required this.count,
    required this.color,
    required this.onTap,
  });

  /// How big the knob is to a fingertip, and how big it's drawn.
  static const touch = 36.0;
  static const size = 21.0;

  final bool folded;

  /// How many tasks are folded away in it.
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final surface = isDarkTheme ? context.colors.cardBackground : Colors.white;
    return Semantics(
      button: true,
      label: folded
          ? (count == 1
              ? "1 subtask folded away"
              : "$count subtasks folded away")
          : "Subtasks",
      hint: folded ? "Shows the subtasks" : "Folds the subtasks away",
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            // Wider for a count of two figures or more.
            width: folded && count > 9 ? size + 7 : size,
            height: size,
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: color, width: 1.6)),
              color: folded ? color : surface,
            ),
            alignment: Alignment.center,
            child: folded
                ? Text(
                    count > 99 ? "99+" : "$count",
                    maxLines: 1,
                    softWrap: false,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  )
                : Icon(Icons.remove_rounded, size: 14, color: color),
          ),
        ),
      ),
    );
  }
}
