import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readmore/readmore.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/theme/palette.dart';
import '../../../../../core/utils/date_time_utils.dart';
import '../../../../../core/utils/task_labels.dart';
import '../../../../../models/recurrence.dart';
import '../../../../../models/repeat_progress.dart';
import '../../../../../models/todo_item.dart';
import '../../../../widgets/check_circle.dart';

/// A task on the to-do page, on the same surface as the profile page's
/// cards: a round check that fills in once it's done, its title and
/// description, when it's due, and a bell for its reminder. A repeating
/// task's also shows how it repeats and until when, how its last few times
/// went, and its streak, and one with subtasks how many of them are done.
class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.now,
    required this.titleScale,
    required this.descriptionScale,
    required this.descriptionLines,
    this.subtasks,
    this.onToggle,
    this.onEdit,
    this.onReminder,
    this.onDailyReminder,
    this.onFold,
    this.checkKey,
    this.titleKey,
    this.bellKey,
  });

  // Apple's continuous corners, as on the note and profile cards.
  static const shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );

  final TodoItem task;

  /// The time the card shows the task as of: the tasks' own, as
  /// `TasksViewModel.now` has it, so the card agrees with the list.
  final DateTime now;

  /// How many tasks are in this one, however deep, and how many of them are
  /// done. Null for a task with none.
  final ({int done, int total})? subtasks;

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

  /// Folds the task's subtasks away, or brings them back out, on a tap of
  /// their count. Null when there are none on show to fold.
  final VoidCallback? onFold;

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
    // Worked out the once, rather than on each frame of the animation below,
    // which only changes the colours.
    final facts = _Facts.of(widget.task, widget.now);
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
                    _buildContent(context, doneness, facts),
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

  /// The card's insides, part way between to-do (0) and done (1), saying
  /// what [facts] has of the task.
  Widget _buildContent(BuildContext context, double doneness, _Facts facts) {
    final task = widget.task;
    final ink = context.colors.wB;
    // Text fades back as the task gets done.
    Color fade(double alpha, double doneAlpha) =>
        ink.withValues(alpha: lerpDouble(alpha, doneAlpha, doneness));
    final chips = _chips(context, doneness, facts);
    final subtasks = widget.subtasks;
    return Padding(
      // Less under the subtasks' row, which has room of its own to tap.
      padding: EdgeInsets.fromLTRB(14, 12, 6, subtasks == null ? 14 : 6),
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
                        alpha: math.max(0.38 * doneness, 1 / 255),
                      ),
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
          if (facts.recent case final recent?)
            Padding(
              padding: const EdgeInsets.fromLTRB(_textInset, 12, 10, 0),
              // Fades back with the chips once the task's done for now.
              child: Opacity(
                opacity: lerpDouble(1, 0.5, doneness)!,
                child: _RecentTimes(recent: recent, doneness: doneness),
              ),
            ),
          if (subtasks != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(_textInset - 8, 4, 4, 0),
              child: _SubtasksRow(
                done: subtasks.done,
                total: subtasks.total,
                folded: task.folded,
                strength: lerpDouble(1, 0.5, doneness)!,
                onTap: widget.onFold,
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
      color: context.colors.moreLess.withValues(
        alpha: lerpDouble(1, 0.5, doneness),
      ),
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

  /// When the task is due, how it repeats and until when, and for how many
  /// times in a row it's been done, as [facts] has them.
  List<Widget> _chips(BuildContext context, double doneness, _Facts facts) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final ink = context.colors.wB;
    // Done tasks' chips fade back with the rest of the card.
    final strength = lerpDouble(1, 0.5, doneness)!;
    final orange = context.colors.warning;
    // Red once it's overdue, as in Reminders, until it's done.
    final overdue = facts.overdue ? 1 - doneness : 0.0;
    final red = context.colors.systemRed;
    final whenColor = Color.lerp(ink.withValues(alpha: 0.6), red, overdue)!;
    final whenTint = Color.lerp(
      ink.withValues(alpha: isDarkTheme ? 0.08 : 0.05),
      red.withValues(alpha: isDarkTheme ? 0.18 : 0.12),
      overdue,
    )!;
    final plain = ink.withValues(alpha: 0.6 * strength);
    final plainTint = ink.withValues(
      alpha: (isDarkTheme ? 0.08 : 0.05) * strength,
    );
    return [
      if (facts.when case final due?)
        _Chip(
          icon: facts.hasDay
              ? Icons.calendar_today_rounded
              : Icons.schedule_rounded,
          label: due,
          color: whenColor.withValues(alpha: whenColor.a * strength),
          tint: whenTint.withValues(alpha: whenTint.a * strength),
        ),
      if (facts.repeat case final repeat?)
        _Chip(
          icon: Icons.repeat_rounded,
          label: repeat,
          color: Colors.white.withValues(alpha: strength),
          gradient: LinearGradient(
            colors: [
              AppPalette.accent.withValues(alpha: strength),
              AppPalette.highlight.withValues(alpha: strength),
            ],
          ),
        ),
      if (facts.end case final end?)
        _Chip(
          icon: facts.ended
              ? Icons.flag_rounded
              : Icons.hourglass_bottom_rounded,
          label: end,
          color: plain,
          tint: plainTint,
        ),
      if (facts.streak case final streak?)
        _Chip(
          icon: Icons.local_fire_department_rounded,
          label: streak,
          color: orange.withValues(alpha: strength),
          tint: orange.withValues(
            alpha: (isDarkTheme ? 0.18 : 0.12) * strength,
          ),
        ),
    ];
  }
}

/// What a task's card says of it, as of the card's time, worked out once
/// for each build of the card rather than on each frame of its done
/// animation, which only changes its colours.
class _Facts {
  const _Facts({
    required this.when,
    required this.hasDay,
    required this.overdue,
    required this.repeat,
    required this.end,
    required this.ended,
    required this.streak,
    required this.recent,
  });

  factory _Facts.of(TodoItem task, DateTime now) {
    final recurrence = task.recurrence;
    final occurrence = task.occurrenceOn(now);
    // The time that stands for it as the card has it, which is how the tour
    // can check it off.
    final progress = occurrence == null
        ? task.progress
        : task.progress.withDay(occurrence, done: task.done);
    final streak = recurrence?.streak(now, done: progress.doneDays) ?? 0;
    return _Facts(
      when: taskWhenLabel(task, now),
      hasDay: taskDayOf(task, now) != null,
      overdue: task.isPastDue(now),
      repeat: recurrence == null ? null : repeatChipLabel(recurrence),
      end: recurrence == null ? null : repeatEndLabel(recurrence, now),
      ended: recurrence?.hasEndedBy(now) ?? false,
      streak: recurrence != null && streak >= 2
          ? streakLabel(recurrence, streak)
          : null,
      recent: recurrence == null ? null : _Recent.of(recurrence, progress, now),
    );
  }

  /// When the task is due, and whether that's on a day, or only a time.
  final String? when;
  final bool hasDay;

  /// Whether the task was due before now, and still is.
  final bool overdue;

  /// How a repeating task repeats; until when, and whether that's gone; and
  /// how many times in a row it's been done, when that's two or more.
  final String? repeat;
  final String? end;
  final bool ended;
  final String? streak;

  /// A repeating task's last few times.
  final _Recent? recent;
}

/// A repeating task's last few times, each with its initial: filled in with
/// the app's blues for a time the task was done, ringed for one it missed,
/// and bare for a day it doesn't come round on, or one from before it
/// started repeating. The time that stands for it now is ringed in the
/// accent until it fills in as the task gets done.
///
/// A daily or weekly task shows its last seven days, up to today, or up to
/// its first time while that's still to come; a monthly one, its last six
/// months, each by its initial.
class _RecentTimes extends StatelessWidget {
  const _RecentTimes({required this.recent, required this.doneness});

  final _Recent recent;

  /// How far the time that stands for the task now has filled in, as the
  /// card goes from to-do (0) to done (1).
  final double doneness;

  @override
  Widget build(BuildContext context) {
    // Big enough for its initial at the user's text size.
    final size = math.max(
      24.0,
      MediaQuery.textScalerOf(context).scale(11.5) + 11,
    );
    return Semantics(
      label: recent.label,
      excludeSemantics: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        // Smaller, rather than off the card, at the largest text sizes.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, slot) in recent.slots.indexed) ...[
                if (index > 0) const SizedBox(width: 6),
                slot.current
                    ? _DayDot(
                        letter: slot.letter,
                        status: DayStatus.due,
                        fill: doneness,
                        size: size,
                      )
                    : _DayDot(
                        letter: slot.letter,
                        status: slot.status,
                        fill: slot.status == DayStatus.done ? 1 : 0,
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

/// A repeating task's last few times, as [_RecentTimes] shows them: each
/// with its initial and how it went, and what a screen reader says of them.
class _Recent {
  const _Recent(this.slots, this.label);

  /// A daily or weekly task's last seven days, up to today, or up to its
  /// first time while that's still to come; a monthly one's last six
  /// months, up to the one its time is in, each by the day it comes round
  /// on there: none, in a month without that day.
  factory _Recent.of(
    Recurrence recurrence,
    RepeatProgress progress,
    DateTime today,
  ) {
    final current = recurrence.currentAsOf(today);
    final monthly = recurrence.every == RepeatEvery.month;
    _Slot slot(DateTime day, DateFormat letter) => (
      letter: letter.format(day),
      status: recurrence.statusOf(day, today, done: progress.doneDays),
      current: day == current,
    );
    final List<_Slot> slots;
    if (monthly) {
      final last = current ?? today;
      final monthDay = recurrence.monthDay!;
      final letter = DateFormat("MMMMM");
      slots = [
        for (var back = _months - 1; back >= 0; back--)
          if (DateTime(last.year, last.month - back) case final month
              when DateTime(month.year, month.month + 1, 0).day < monthDay)
            (
              letter: letter.format(month),
              status: DayStatus.untracked,
              current: false,
            )
          else
            slot(DateTime(last.year, last.month - back, monthDay), letter),
      ];
    } else {
      final last = current != null && current.isAfter(today) ? current : today;
      final letter = DateFormat("EEEEE");
      slots = [
        for (var back = _days - 1; back >= 0; back--)
          slot(DateTime(last.year, last.month, last.day - back), letter),
      ];
    }
    int count(DayStatus status) =>
        slots.where((slot) => slot.status == status).length;
    final stillToDo = current != null && !progress.isDoneOn(current);
    return _Recent(
      slots,
      "Last ${monthly ? "$_months months" : "$_days days"}: "
      "${count(DayStatus.done)} done, ${count(DayStatus.missed)} missed"
      "${stillToDo ? ", ${DateTimeUtils.dayInSentence(current, today)} "
                "still to do" : ""}",
    );
  }

  static const _days = 7;
  static const _months = 6;

  /// The days, or the months, from the first.
  final List<_Slot> slots;

  /// What a screen reader says of them all.
  final String label;
}

/// A day, or a month, of [_RecentTimes]: its initial, how it went, and
/// whether it's the time that stands for the task now.
typedef _Slot = ({String letter, DayStatus status, bool current});

/// A day, or a month, of [_RecentTimes]: its initial, in a circle.
class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.letter,
    required this.status,
    required this.fill,
    required this.size,
  });

  final String letter;

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
    final (ring, letterColor) = switch (status) {
      DayStatus.due => (accent, accent),
      DayStatus.missed => (
        ink.withValues(alpha: isDarkTheme ? 0.3 : 0.22),
        ink.withValues(alpha: 0.5),
      ),
      DayStatus.done || DayStatus.untracked => (
        ink.withValues(alpha: 0),
        ink.withValues(alpha: 0.25),
      ),
    };
    return CustomPaint(
      painter: _DayDotPainter(ring: ring, fill: fill),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: Color.lerp(letterColor, Colors.white, fill),
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
            AppPalette.accent.withValues(alpha: math.min(1, fill * 1.6)),
            AppPalette.highlight.withValues(alpha: math.min(1, fill * 1.6)),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: fillRadius)),
    );
  }

  @override
  bool shouldRepaint(_DayDotPainter oldDelegate) =>
      oldDelegate.ring != ring || oldDelegate.fill != fill;
}

/// How many of a task's subtasks are done, as a line at the foot of its
/// card: a chevron that turns as they're folded away, the count, and a bar
/// that fills up with it. A tap on it folds them away, or brings them back.
class _SubtasksRow extends StatelessWidget {
  const _SubtasksRow({
    required this.done,
    required this.total,
    required this.folded,
    required this.strength,
    required this.onTap,
  });

  final int done;
  final int total;
  final bool folded;

  /// How strongly it's drawn: less on a done task's card, as the rest of it.
  final double strength;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final accent = context.colors.moreLess;
    final color = accent.withValues(alpha: strength);
    final things = total == 1 ? "subtask" : "subtasks";
    final label = done == 0 ? "$total $things" : "$done of $total $things";
    final onTap = this.onTap;
    return Semantics(
      button: onTap != null,
      label: "$label${done == 0 ? "" : " done"}",
      hint: onTap == null
          ? null
          : (folded ? "Shows the subtasks" : "Folds the subtasks away"),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        customBorder: const StadiumBorder(),
        splashFactory: NoSplash.splashFactory,
        highlightColor: accent.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          child: Row(
            children: [
              if (onTap != null)
                AnimatedRotation(
                  turns: folded ? -0.25 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: color,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    Icons.account_tree_rounded,
                    size: 14,
                    color: color,
                  ),
                ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Fills up as the subtasks get done.
              SizedBox(
                width: 44,
                height: 4,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: total == 0 ? 0.0 : done / total),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => CustomPaint(
                    painter: _BarPainter(
                      progress: value,
                      track: context.colors.wB.withValues(
                        alpha: isDarkTheme ? 0.14 : 0.09,
                      ),
                      strength: strength,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A thin, round-ended bar that fills with the app's blues.
class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.progress,
    required this.track,
    required this.strength,
  });

  final double progress;
  final Color track;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final bar = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, radius),
      Paint()..color = track,
    );
    if (progress <= 0) return;
    // Never shorter than a dot.
    final filled = Rect.fromLTWH(
      0,
      0,
      math.max(size.height, size.width * progress),
      size.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(filled, radius),
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppPalette.accent.withValues(alpha: strength),
            AppPalette.highlight.withValues(alpha: strength),
          ],
        ).createShader(bar),
    );
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.strength != strength;
}

/// What a [TaskCard] uncovers as it's swiped away: the red of a delete
/// action, the same shape as the card, with the action's icon and name
/// where the swipe started.
class TaskDeleteBackground extends StatelessWidget {
  const TaskDeleteBackground({super.key, required this.alignment});

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return _SwipeBackground(
      alignment: alignment,
      color: context.colors.systemRed,
      icon: Icons.delete_rounded,
      label: "Delete",
    );
  }
}

/// What a [TaskCard] uncovers as it's swiped the other way, to add a
/// subtask to it: the app's blues, with the action's icon and name where
/// the swipe started.
class TaskSubtaskBackground extends StatelessWidget {
  const TaskSubtaskBackground({super.key, required this.alignment});

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return _SwipeBackground(
      alignment: alignment,
      gradient: LinearGradient(
        colors: [
          AppPalette.accent,
          Color.lerp(AppPalette.accent, AppPalette.highlight, 0.7)!,
        ],
      ),
      icon: Icons.subdirectory_arrow_right_rounded,
      label: "Subtask",
    );
  }
}

/// A swipe's action, behind the card: its colour in the card's shape, with
/// its icon and name at [alignment].
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    this.color,
    this.gradient,
    required this.icon,
    required this.label,
  });

  final AlignmentGeometry alignment;
  final Color? color;
  final Gradient? gradient;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: TaskCard.shape,
        color: color,
        gradient: gradient,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Align(
          alignment: alignment,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
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
                  alpha: on ? (isDarkTheme ? 0.18 : 0.12) : 0,
                ),
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
