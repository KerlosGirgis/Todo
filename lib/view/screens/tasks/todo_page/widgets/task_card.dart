import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:readmore/readmore.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/utils/date_time_utils.dart';
import '../../../../../models/daily_progress.dart';
import '../../../../../models/todo_item.dart';
import '../../../../widgets/check_circle.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

/// iOS's system red, a touch brighter on dark pages, as there.
Color _systemRed(bool isDarkTheme) =>
    isDarkTheme ? const Color(0xffFF453A) : const Color(0xffFF3B30);

/// iOS's system orange on dark pages, and a deeper one that reads on light
/// ones.
Color _orange(bool isDarkTheme) =>
    isDarkTheme ? const Color(0xffFF9F0A) : const Color(0xffC93400);

/// A task on the to-do page, on the same surface as the profile page's
/// cards: a round check that fills in once it's done, its title and
/// description, when it's due, and a bell for its reminder. A daily task's
/// also shows how its last seven days went, and its streak.
class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.titleScale,
    required this.descriptionScale,
    required this.descriptionLines,
    this.onToggle,
    this.onEdit,
    this.onReminder,
    this.onDailyReminder,
    this.checkKey,
    this.titleKey,
    this.bellKey,
  });

  // Apple's continuous corners, as on the note and profile cards.
  static const shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );

  final TodoItem task;

  /// The user's text sizes, as multiples of the default ones.
  final double titleScale;
  final double descriptionScale;

  /// How many lines of the description show before "Show More"; 0 shows it
  /// all.
  final int descriptionLines;

  /// Marks the task done, or not done again. A tap anywhere on the card
  /// does it.
  final VoidCallback? onToggle;

  /// Opens the task's editor, on a long press of its title. A long press
  /// anywhere else is left free for picking the card up to reorder it.
  final VoidCallback? onEdit;

  /// Turns a one-time reminder on, or the reminder off when there is one.
  final VoidCallback? onReminder;

  /// Turns a daily reminder on, on a long press of the bell.
  final VoidCallback? onDailyReminder;

  /// Keys for the check, the title and the bell, so that a tour can point at
  /// them on a copy of the card.
  final Key? checkKey;
  final Key? titleKey;
  final Key? bellKey;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  /// Where the description and chips start, under the title rather than the
  /// check.
  static const _textInset = CheckCircle.defaultSize + 12;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final ink = context.colors.wB;
    final done = widget.task.done;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: TaskCard.shape,
          // A soft, layered shadow on light pages; on dark ones the hairline
          // edge does the separating, as on the profile page.
          shadows: isDarkTheme
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    spreadRadius: -6,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Material(
          // White rather than the card grey, which barely shows on the light
          // page background.
          color: isDarkTheme ? context.colors.cardBackground : Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: TaskCard.shape.copyWith(
            side: BorderSide(
              width: 0.5,
              color: ink.withValues(alpha: isDarkTheme ? 0.08 : 0.05),
            ),
          ),
          child: Semantics(
            checked: done,
            child: InkWell(
              onTap: widget.onToggle == null ? null : _toggle,
              onHighlightChanged: (pressed) =>
                  setState(() => _pressed = pressed),
              // iOS dims a pressed card instead of rippling, and stays silent.
              enableFeedback: false,
              splashFactory: NoSplash.splashFactory,
              highlightColor: ink.withValues(alpha: 0.05),
              // Eases between the to-do and done looks, rather than snapping.
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: done ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                builder: (context, doneness, child) =>
                    _buildContent(context, doneness),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    widget.onToggle!();
  }

  void _edit() {
    HapticFeedback.mediumImpact();
    widget.onEdit!();
  }

  /// The card's insides, part way between to-do (0) and done (1).
  Widget _buildContent(BuildContext context, double doneness) {
    final task = widget.task;
    final ink = context.colors.wB;
    // Text fades back as the task gets done.
    Color fade(double alpha, double doneAlpha) =>
        ink.withValues(alpha: lerpDouble(alpha, doneAlpha, doneness));
    final now = DateTime.now();
    // Today as the card has it, which is how the tour can check it off.
    final progress = task.progress.withDay(now, done: task.done);
    final chips = _chips(context, doneness, now, progress);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CheckCircle(key: widget.checkKey, doneness: doneness),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  key: widget.titleKey,
                  onLongPress: widget.onEdit == null ? null : _edit,
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fade(1, 0.38),
                      fontSize: 20 * widget.titleScale,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      letterSpacing: -0.4,
                      // Struck through in a colour that fades in as the task
                      // gets done. It's never fully clear, which the engine
                      // takes as no colour, drawing the line in the text's.
                      decoration: doneness > 0
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: ink.withValues(
                          alpha: math.max(0.38 * doneness, 1 / 255)),
                      decorationThickness: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              // Done tasks have no reminder; the bell fades away but keeps
              // its room, so the card doesn't change height.
              IgnorePointer(
                ignoring: doneness > 0.5,
                child: ExcludeSemantics(
                  excluding: doneness > 0.5,
                  child: Opacity(
                    opacity: 1 - doneness,
                    child: _ReminderButton(
                      key: widget.bellKey,
                      on: task.reminder != Reminder.none,
                      onTap: widget.onReminder,
                      onLongPress: widget.onDailyReminder,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (task.desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(_textInset, 2, 10, 0),
              child: _description(context, fade(0.6, 0.3), doneness),
            ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(_textInset, 10, 10, 0),
              child: Wrap(spacing: 6, runSpacing: 6, children: chips),
            ),
          if (task.isDaily)
            Padding(
              padding: const EdgeInsets.fromLTRB(_textInset, 12, 10, 0),
              // Fades back with the chips once the task's done for the day.
              child: Opacity(
                opacity: lerpDouble(1, 0.5, doneness)!,
                child: _WeekStrip(
                  progress: progress,
                  today: now,
                  doneness: doneness,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _description(BuildContext context, Color color, double doneness) {
    final style = TextStyle(
      color: color,
      fontSize: 16 * widget.descriptionScale,
      height: 1.35,
      letterSpacing: -0.1,
    );
    if (widget.descriptionLines == 0) {
      return Text(widget.task.desc, style: style);
    }
    // The whole description style, as ReadMoreText measures the link with
    // this alone: without the size, it would make too little room for it.
    final linkStyle = style.copyWith(
      color: context.colors.moreLess
          .withValues(alpha: lerpDouble(1, 0.5, doneness)),
      fontWeight: FontWeight.w600,
    );
    return ReadMoreText(
      widget.task.desc,
      trimMode: TrimMode.Line,
      trimLines: widget.descriptionLines,
      // Non-breaking, so the link never splits over two lines.
      trimCollapsedText: "Show More",
      trimExpandedText: " Show Less",
      moreStyle: linkStyle,
      lessStyle: linkStyle,
      style: style,
    );
  }

  /// When the task is due, whether it repeats daily, and for how many days
  /// in a row it's been done.
  List<Widget> _chips(BuildContext context, double doneness, DateTime now,
      DailyProgress progress) {
    final task = widget.task;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final ink = context.colors.wB;
    // Done tasks' chips fade back with the rest of the card.
    final strength = lerpDouble(1, 0.5, doneness)!;
    final streak = progress.streak(now);
    final orange = _orange(isDarkTheme);
    final when = _whenLabel(task, now);
    // Red once it's overdue, as in Reminders, until it's done.
    final overdue = task.isPastDue(now) ? 1 - doneness : 0.0;
    final red = _systemRed(isDarkTheme);
    final whenColor = Color.lerp(ink.withValues(alpha: 0.6), red, overdue)!;
    final whenTint = Color.lerp(
      ink.withValues(alpha: isDarkTheme ? 0.08 : 0.05),
      red.withValues(alpha: isDarkTheme ? 0.18 : 0.12),
      overdue,
    )!;
    return [
      if (when != null)
        _Chip(
          icon: task.day == null
              ? Icons.schedule_rounded
              : Icons.calendar_today_rounded,
          label: when,
          color: whenColor.withValues(alpha: whenColor.a * strength),
          tint: whenTint.withValues(alpha: whenTint.a * strength),
        ),
      if (task.reminder == Reminder.daily)
        _Chip(
          icon: Icons.repeat_rounded,
          label: "Daily",
          color: Colors.white.withValues(alpha: strength),
          gradient: LinearGradient(
            colors: [
              _accent.withValues(alpha: strength),
              _highlight.withValues(alpha: strength),
            ],
          ),
        ),
      if (task.isDaily && streak >= 2)
        _Chip(
          icon: Icons.local_fire_department_rounded,
          label: "$streak-day streak",
          color: orange.withValues(alpha: strength),
          tint:
              orange.withValues(alpha: (isDarkTheme ? 0.18 : 0.12) * strength),
        ),
    ];
  }
}

/// A daily task's last seven days, today last, each with its initial: filled
/// in with the app's blues on a day the task was done, ringed on one it
/// wasn't, and bare on one from before it was daily. Today's is ringed in
/// the accent until it fills in as the task gets done.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.progress,
    required this.today,
    required this.doneness,
  });

  final DailyProgress progress;
  final DateTime today;

  /// How far today has filled in, as the card goes from to-do (0) to done
  /// (1).
  final double doneness;

  static const _length = 7;

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var back = _length - 1; back >= 0; back--)
        DateTime(today.year, today.month, today.day - back),
    ];
    final statuses = [for (final day in days) progress.statusOf(day, today)];
    int count(DayStatus status) =>
        statuses.where((each) => each == status).length;
    // Big enough for its initial at the user's text size.
    final size =
        math.max(24.0, MediaQuery.textScalerOf(context).scale(11.5) + 11);
    return Semantics(
      label: "Last $_length days: ${count(DayStatus.done)} done, "
          "${count(DayStatus.missed)} missed"
          "${statuses.last == DayStatus.due ? ", today still to do" : ""}",
      excludeSemantics: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        // Smaller, rather than off the card, at the largest text sizes.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, day) in days.indexed) ...[
                if (index > 0) const SizedBox(width: 6),
                index == _length - 1
                    ? _DayDot(
                        day: day,
                        status: DayStatus.due,
                        fill: doneness,
                        size: size,
                      )
                    : _DayDot(
                        day: day,
                        status: statuses[index],
                        fill: statuses[index] == DayStatus.done ? 1 : 0,
                        size: size,
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A day of a [_WeekStrip]: its initial, in a circle.
class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.day,
    required this.status,
    required this.fill,
    required this.size,
  });

  final DateTime day;

  /// How the day went, short of being done.
  final DayStatus status;

  /// How far it's filled in with the app's blues: all the way on a day the
  /// task was done.
  final double fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final ink = context.colors.wB;
    final accent = context.colors.moreLess;
    final (ring, letter) = switch (status) {
      DayStatus.due => (accent, accent),
      DayStatus.missed => (
          ink.withValues(alpha: isDarkTheme ? 0.3 : 0.22),
          ink.withValues(alpha: 0.5)
        ),
      DayStatus.done || DayStatus.untracked => (
          ink.withValues(alpha: 0),
          ink.withValues(alpha: 0.25)
        ),
    };
    return CustomPaint(
      painter: _DayDotPainter(ring: ring, fill: fill),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            DateFormat("EEEEE").format(day),
            style: TextStyle(
              color: Color.lerp(letter, Colors.white, fill),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayDotPainter extends CustomPainter {
  const _DayDotPainter({required this.ring, required this.fill});

  final Color ring;
  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    if (fill < 1 && ring.a > 0) {
      canvas.drawCircle(
        center,
        radius - 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = ring.withValues(alpha: ring.a * (1 - fill)),
      );
    }
    if (fill <= 0) return;
    // Grows in from the middle, as the task's check does.
    final fillRadius = radius * (0.6 + 0.4 * fill);
    canvas.drawCircle(
      center,
      fillRadius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withValues(alpha: math.min(1, fill * 1.6)),
            _highlight.withValues(alpha: math.min(1, fill * 1.6)),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: fillRadius)),
    );
  }

  @override
  bool shouldRepaint(_DayDotPainter oldDelegate) =>
      oldDelegate.ring != ring || oldDelegate.fill != fill;
}

/// What a [TaskCard] uncovers as it's swiped away: the red of a delete
/// action, the same shape as the card, with the action's icon and name
/// where the swipe started.
class TaskDeleteBackground extends StatelessWidget {
  const TaskDeleteBackground({super.key, required this.alignment});

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: TaskCard.shape,
        color: _systemRed(isDarkTheme),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Align(
          alignment: alignment,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_rounded, size: 22, color: Colors.white),
              SizedBox(width: 6),
              Text(
                "Delete",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today, 9:30 AM", "Tomorrow", "Fri, Oct 24" or "Jan 3, 2027, 9:30 AM",
/// or null when the task has neither a date nor a time.
String? _whenLabel(TodoItem task, DateTime now) {
  final day = task.day;
  final time = task.time;
  final parts = [
    if (day != null) DateTimeUtils.friendlyDay(day, now),
    if (time != null) time.label,
  ];
  return parts.isEmpty ? null : parts.join(", ");
}

/// A small capsule with an icon and a few words about the task.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    this.tint,
    this.gradient,
  });

  final IconData icon;
  final String label;
  final Color color;

  /// The capsule's fill: a flat [tint], or a [gradient].
  final Color? tint;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: tint,
        gradient: gradient,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bell at the end of a card: tinted with the accent while a reminder is
/// on, and faint while it's off.
class _ReminderButton extends StatelessWidget {
  const _ReminderButton({
    super.key,
    required this.on,
    this.onTap,
    this.onLongPress,
  });

  final bool on;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final accent = context.colors.moreLess;
    return Semantics(
      button: true,
      label: on ? "Reminder on" : "Reminder off",
      hint: on ? "Turns the reminder off" : "Reminds you once, or daily",
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 40,
        child: InkResponse(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          onLongPress: onLongPress == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                },
          radius: 19,
          splashFactory: NoSplash.splashFactory,
          highlightColor: accent.withValues(alpha: 0.16),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(
                    alpha: on ? (isDarkTheme ? 0.18 : 0.12) : 0),
              ),
              child: Icon(
                on
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                size: on ? 18 : 21,
                color: on ? accent : context.colors.wB.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
