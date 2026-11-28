import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../../core/tasks_widget_snapshot.dart';
import '../../../../../core/theme/palette.dart';
import '../../../../../models/clock_time.dart';
import '../../../../../models/repeat_progress.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../models/widget_look.dart';
import '../../../../../models/widget_style.dart';

// The widgets as the phone draws them, from res/layout/widget_tasks.xml,
// widget_task_row.xml and note.xml: the same sizes, in logical pixels for
// the layouts' dp and sp, so the preview matches them. Change both together.

/// The to-do widget's padding, title, count and empty message.
const _tasksPadding = EdgeInsets.fromLTRB(16, 14, 16, 4);
const _headerSize = 15.0;
const _countSize = 22.0;
const _headerGap = 6.0;
const _emptySize = 14.0;

/// A task's row: its padding, check, title and details, and how far in each
/// task it's in puts it, up to [_maxIndents] of them.
const _rowPadding = 5.0;
const _checkSize = 18.0;
const _checkGap = 10.0;
const _titleSize = 14.0;
const _detailsSize = 11.5;
const _indent = 22.0;
const _maxIndents = 3;

/// The note widget's padding and text.
const _notePadding = 16.0;
const _noteSize = 22.0;

/// How big each widget is drawn when there's none on the home screen to go
/// by: about its size as it's first added.
const _defaultSizes = {
  WidgetKind.tasks: (width: 260.0, height: 260.0),
  WidgetKind.note: (width: 170.0, height: 170.0),
};

/// A home screen widget as the phone draws it with [style], in light or
/// [dark] mode, as big as the first such widget on the home screen or as
/// one is first added, made smaller to fit if need be.
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({
    super.key,
    required this.kind,
    required this.style,
    required this.look,
    required this.dark,
    this.noteText,
  });

  final WidgetKind kind;
  final WidgetStyle style;
  final WidgetLook look;
  final bool dark;

  /// What the note widget shows.
  final String? noteText;

  @override
  Widget build(BuildContext context) {
    final size = look.sizes[kind] ?? _defaultSizes[kind]!;
    final colors = look.colors(dark: dark);
    final widget = SizedBox(
      width: size.width,
      height: size.height,
      child: _Surface(
        style: style,
        colors: colors,
        radius: look.radius,
        child: switch (kind) {
          WidgetKind.tasks => TasksWidgetContent(
            snapshot: sampleTasks(),
            style: style,
            colors: colors,
          ),
          WidgetKind.note => NoteWidgetContent(
            text: noteText ?? _sampleNote,
            style: style,
            colors: colors,
          ),
        },
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          1.0,
          math.min(
            constraints.maxWidth / size.width,
            constraints.maxHeight / size.height,
          ),
        );
        return Center(
          child: SizedBox(
            width: size.width * scale,
            height: size.height * scale,
            child: FittedBox(child: widget),
          ),
        );
      },
    );
  }
}

const _sampleNote = "Pick up the dry cleaning before six, then call Grandma.";

/// The widget's background, in its colour or the phone's own, showing as
/// much as its opacity has it, with the phone's corners.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.style,
    required this.colors,
    required this.radius,
    required this.child,
  });

  final WidgetStyle style;
  final WidgetThemeColors colors;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final background = Color(style.background ?? colors.background);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background.withValues(alpha: background.a * style.opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// The colours a widget's text is in: its own, or the phone's.
class _Inks {
  _Inks(WidgetStyle style, WidgetThemeColors colors, {int? phoneText})
    : primary = Color(style.ink ?? phoneText ?? colors.text),
      secondary = style.ink == null
          ? Color(colors.secondaryText)
          : Color(style.ink!).withValues(alpha: Color(style.ink!).a * 0.6);

  final Color primary;
  final Color secondary;
}

TextStyle _text(
  WidgetStyle style,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  color: color,
  fontSize: size * style.textSize,
  fontWeight: weight,
  fontFamily: style.font == WidgetFont.casual ? 'casual' : null,
  height: 1.2,
);

/// The to-do widget's title, count and tasks, as the phone lays them out
/// from [snapshot] at [now].
class TasksWidgetContent extends StatelessWidget {
  const TasksWidgetContent({
    super.key,
    required this.snapshot,
    required this.style,
    required this.colors,
    this.now,
  });

  final TasksWidgetSnapshot snapshot;
  final WidgetStyle style;
  final WidgetThemeColors colors;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final now = this.now ?? DateTime.now();
    final inks = _Inks(style, colors);
    final accent = Color(style.accent);
    final rows = snapshot.locked
        ? const <WidgetRow>[]
        : snapshot.rowsOn(now, showDone: style.showDone);
    final empty = switch (snapshot) {
      TasksWidgetSnapshot(locked: true) => "Unlock the app to see your tasks",
      TasksWidgetSnapshot(total: 0) => "No tasks yet",
      _ => "All done",
    };
    return Padding(
      padding: _tasksPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  "To-Do",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    style,
                    _headerSize,
                    inks.primary,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                "${snapshot.leftOn(now)}",
                style: _text(
                  style,
                  _countSize,
                  accent,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: _headerGap),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      empty,
                      textAlign: TextAlign.center,
                      style: _text(style, _emptySize, inks.secondary),
                    ),
                  )
                : ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final row in rows)
                            _TaskRow(
                              row: row,
                              style: style,
                              inks: inks,
                              accent: accent,
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.row,
    required this.style,
    required this.inks,
    required this.accent,
  });

  final WidgetRow row;
  final WidgetStyle style;
  final _Inks inks;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final details = row.details;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _indent * math.min(row.depth, _maxIndents),
        _rowPadding,
        0,
        _rowPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              row.done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: _checkSize,
              color: accent,
            ),
          ),
          const SizedBox(width: _checkGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      _text(
                        style,
                        _titleSize,
                        row.done ? inks.secondary : inks.primary,
                      ).copyWith(
                        decoration: row.done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: inks.secondary,
                      ),
                ),
                if (details != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(
                        style,
                        _detailsSize,
                        // Red once it's overdue, as on the widget itself.
                        row.late ? SystemColors.red : inks.secondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The note widget's text, bold in the middle, as the phone lays it out:
/// from its first line, cut off at the bottom when it doesn't fit.
class NoteWidgetContent extends StatelessWidget {
  const NoteWidgetContent({
    super.key,
    required this.text,
    required this.style,
    required this.colors,
  });

  final String text;
  final WidgetStyle style;
  final WidgetThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final inks = _Inks(style, colors, phoneText: colors.noteText);
    return Padding(
      padding: const EdgeInsets.all(_notePadding),
      child: Center(
        child: Text(
          text,
          overflow: TextOverflow.clip,
          textWidthBasis: TextWidthBasis.longestLine,
          style: _text(style, _noteSize, inks.primary, weight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Tasks to show the to-do widget's style with, as of [now]: one for
/// later today, one overdue, one with subtasks, one of them done, and a
/// daily one done for today.
TasksWidgetSnapshot sampleTasks([DateTime? now]) {
  now ??= DateTime.now();
  // Counted by the calendar, as a day isn't always 24 hours long.
  DateTime day(int from) => DateTime(now!.year, now.month, now.day + from);
  final today = day(0);
  // Still to come, as the overdue one shows what overdue looks like.
  final evening = now.hour < 17;
  return TasksWidgetSnapshot.of([
    TodoItem(
      uuid: "plants",
      title: "Water the plants",
      day: evening ? today : day(1),
      time: evening ? const ClockTime(18, 0) : const ClockTime(9, 0),
      reminder: Reminder.once,
    ),
    TodoItem(uuid: "groceries", title: "Groceries"),
    TodoItem(uuid: "milk", title: "Oat milk", parent: "groceries"),
    TodoItem(uuid: "eggs", title: "Eggs", parent: "groceries", done: true),
    TodoItem(
      uuid: "run",
      title: "Morning run",
      time: const ClockTime(7, 0),
      reminder: Reminder.daily,
      progress: RepeatProgress(since: day(-14), doneDays: [today]),
    ),
    TodoItem(
      uuid: "bank",
      title: "Call the bank",
      day: day(-1),
      time: const ClockTime(10, 0),
    ),
    TodoItem(uuid: "book", title: "Read 20 pages"),
  ], now: now);
}
