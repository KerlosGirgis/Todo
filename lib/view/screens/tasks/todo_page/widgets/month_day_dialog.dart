import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../profile/profile_page/widgets/profile_button.dart';
import 'form_dialog.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

/// Has the user pick the day of the month a monthly task comes round on,
/// from 1 to 31, in a grid of a week to a row, with [day], the one it's on
/// now, filled in. Gives the day picked, or null.
class MonthDayDialog extends StatelessWidget {
  const MonthDayDialog({super.key, required this.day});

  final int day;

  static const _perRow = 7;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return FormDialog(
      icon: Icons.event_rounded,
      title: "Day of the Month",
      subtitle: "Pick the day it comes round on.",
      content: [
        Material(
          color: ink.withValues(alpha: 0.06),
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (var first = 1; first <= 31; first += _perRow)
                  Row(
                    children: [
                      for (var each = first; each < first + _perRow; each++)
                        Expanded(
                          child: each > 31
                              ? const SizedBox.shrink()
                              : _DayButton(day: each, picked: each == day),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "On the 29th, 30th or 31st, it skips the months without that day.",
          style: TextStyle(
            color: ink.withValues(alpha: 0.55),
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
      actions: [
        ProfileButton(
          label: "Cancel",
          tinted: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// A day of a [MonthDayDialog], which a tap picks.
class _DayButton extends StatelessWidget {
  const _DayButton({required this.day, required this.picked});

  final int day;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return Semantics(
      button: true,
      selected: picked,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop(day);
        },
        radius: 20,
        splashFactory: NoSplash.splashFactory,
        highlightColor: ink.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: picked
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _accent,
                          Color.lerp(_accent, _highlight, 0.7)!,
                        ],
                      )
                    : null,
              ),
              child: SizedBox.square(
                dimension: 36,
                child: Center(
                  child: Text(
                    "$day",
                    // It has to fit in its circle.
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.3),
                    style: TextStyle(
                      color: picked ? Colors.white : ink,
                      fontSize: 15,
                      fontWeight: picked ? FontWeight.w700 : FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
