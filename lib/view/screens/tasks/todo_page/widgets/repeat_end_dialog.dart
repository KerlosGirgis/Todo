import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/utils/date_time_utils.dart';
import '../../../../../models/recurrence.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../profile/profile_page/widgets/profile_button.dart';
import '../../../profile/profile_page/widgets/settings_group.dart';
import 'form_dialog.dart';

/// iOS's system red, as for the task's date.
const _red = Color(0xffFF3B30);

/// Has the user pick how long a task that's to repeat, as [draft] has it,
/// keeps repeating: for good, for a number of days, weeks or months from
/// today, or until a day; with how many times that has it come round, and
/// the last of them. Gives the last day picked, or null for good, in a
/// record; or null when the user cancels.
class RepeatEndDialog extends StatefulWidget {
  const RepeatEndDialog({super.key, required this.draft});

  final TaskDraft draft;

  @override
  State<RepeatEndDialog> createState() => _RepeatEndDialogState();
}

class _RepeatEndDialogState extends State<RepeatEndDialog> {
  late final RepeatEndDraft _end = widget.draft.endDraft();

  @override
  void dispose() {
    _end.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final first = _end.firstDay;
    // Far enough for the longest while.
    final last = DateTime(first.year + 10);
    final day = _end.day;
    final picked = await showDatePicker(
      context: context,
      // One that has ended stopped before the first day on offer.
      initialDate: day.isBefore(first)
          ? first
          : day.isAfter(last)
              ? last
              : day,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) _end.setDay(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _end,
      builder: (context, child) {
        final now = DateTime.now();
        return FormDialog(
          icon: Icons.hourglass_bottom_rounded,
          title: "Repeat For",
          subtitle: "How long should it keep coming round?",
          content: [
            CupertinoSlidingSegmentedControl<RepeatSpan>(
              groupValue: _end.span,
              onValueChanged: (span) {
                if (span != null) _end.setSpan(span);
              },
              children: const {
                RepeatSpan.forever: FormSegment("Forever"),
                RepeatSpan.forAWhile: FormSegment("For a While"),
                RepeatSpan.untilADay: FormSegment("Until"),
              },
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: switch (_end.span) {
                RepeatSpan.forever => const SizedBox(width: double.infinity),
                RepeatSpan.forAWhile => Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FormDialogGroup(
                      children: [_WhileStepper(end: _end)],
                    ),
                  ),
                RepeatSpan.untilADay => Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FormDialogGroup(
                      children: [
                        SettingsTile(
                          icon: Icons.calendar_today_rounded,
                          color: _red,
                          title: "Last Day",
                          trailing: DisclosureValue(
                              DateTimeUtils.friendlyDay(_end.day, now)),
                          onTap: _pickDay,
                        ),
                      ],
                    ),
                  ),
              },
            ),
            const SizedBox(height: 14),
            _TimesLeft(end: _end, now: now),
          ],
          actions: [
            ProfileButton(
              label: "Cancel",
              tinted: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
            // Only while it would come round at all.
            ProfileButton(
              label: "Done",
              onPressed: _end.canSave
                  ? () => Navigator.of(context).pop((until: _end.until))
                  : null,
            ),
          ],
        );
      },
    );
  }
}

/// How many days, weeks or months the task is to repeat for: a count
/// between buttons that take one off and add one, over what it's counted
/// in.
class _WhileStepper extends StatelessWidget {
  const _WhileStepper({required this.end});

  final RepeatEndDraft end;

  @override
  Widget build(BuildContext context) {
    final amount = end.amount;
    final unit = switch (end.unit) {
      RepeatUnit.days => amount == 1 ? "day" : "days",
      RepeatUnit.weeks => amount == 1 ? "week" : "weeks",
      RepeatUnit.months => amount == 1 ? "month" : "months",
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
      child: Column(
        children: [
          Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                tooltip: "Fewer",
                onPressed: amount > 1 ? () => end.setAmount(amount - 1) : null,
              ),
              Expanded(
                child: Text(
                  "$amount $unit",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.wB,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                tooltip: "More",
                onPressed: amount < RepeatEndDraft.maxAmount
                    ? () => end.setAmount(amount + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<RepeatUnit>(
                groupValue: end.unit,
                onValueChanged: (unit) {
                  if (unit != null) end.setUnit(unit);
                },
                children: const {
                  RepeatUnit.days: FormSegment("Days"),
                  RepeatUnit.weeks: FormSegment("Weeks"),
                  RepeatUnit.months: FormSegment("Months"),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A round button beside the count, tinted with the accent, or faint when
/// it can't go further.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final accent = context.colors.moreLess;
    final onPressed = this.onPressed;
    return IconButton(
      onPressed: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed();
            },
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: accent.withValues(alpha: isDarkTheme ? 0.18 : 0.12),
        disabledBackgroundColor: context.colors.wB.withValues(alpha: 0.05),
        foregroundColor: accent,
        disabledForegroundColor: context.colors.wB.withValues(alpha: 0.25),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}

/// How many more times the task would come round, and when the last is, or
/// that it would stop before it does.
class _TimesLeft extends StatelessWidget {
  const _TimesLeft({required this.end, required this.now});

  final RepeatEndDraft end;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final times = end.times;
    // "today" and "tomorrow" read on their own, and a date after "on".
    String on(DateTime day) {
      final named = DateTimeUtils.dayInSentence(day, now);
      final days = DateTime.utc(day.year, day.month, day.day)
          .difference(DateTime.utc(now.year, now.month, now.day))
          .inDays;
      return days <= 1 ? named : "on $named";
    }

    final last = times?.last;
    final (text, warning) = times == null
        ? ("It keeps coming round until you change it.", false)
        : last == null
            ? ("It would stop before it comes round.", true)
            : times.count == 1
                ? ("It comes round just once, ${on(last)}.", false)
                : (
                    "It comes round ${times.count} times, the last "
                        "${on(last)}.",
                    false
                  );
    return Text(
      text,
      style: TextStyle(
        color: warning
            ? (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xffFF9F0A)
                : const Color(0xffC93400))
            : context.colors.wB.withValues(alpha: 0.55),
        fontSize: 13.5,
        height: 1.3,
      ),
    );
  }
}
