import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/theme/palette.dart';
import '../../../../../core/utils/date_time_utils.dart';

/// The days of the week as a row of round buttons, each with its initial,
/// in the order the user's weeks run: filled in with the app's blues on the
/// days a weekly task comes round on, [selected]. A tap on a day picks it,
/// or unpicks it.
class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  /// The days picked, from [DateTime.monday] to [DateTime.sunday].
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  static const _gap = 6.0;
  static const _maxSize = 40.0;

  @override
  Widget build(BuildContext context) {
    // Sunday is 0 there, and 7 here.
    final first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final days = [
      for (var index = 0; index < DateTime.daysPerWeek; index++)
        switch ((first + index) % DateTime.daysPerWeek) {
          0 => DateTime.sunday,
          final day => day,
        },
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(
          _maxSize,
          (constraints.maxWidth - _gap * (days.length - 1)) / days.length,
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final day in days)
              _WeekdayButton(
                day: day,
                picked: selected.contains(day),
                size: size,
                onTap: () => onToggle(day),
              ),
          ],
        );
      },
    );
  }
}

/// A day of a [WeekdayPicker].
class _WeekdayButton extends StatelessWidget {
  const _WeekdayButton({
    required this.day,
    required this.picked,
    required this.size,
    required this.onTap,
  });

  final int day;
  final bool picked;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return Semantics(
      button: true,
      selected: picked,
      label: DateTimeUtils.weekdayName(day),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: picked ? null : ink.withValues(alpha: 0.07),
            gradient: picked
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppPalette.accent,
                      Color.lerp(AppPalette.accent, AppPalette.highlight, 0.7)!,
                    ],
                  )
                : null,
          ),
          child: Text(
            // January 2024 began on a Monday.
            DateFormat("EEEEE").format(DateTime(2024, 1, day)),
            // It has to fit in its circle.
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: 1.3),
            style: TextStyle(
              color: picked ? Colors.white : ink.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
