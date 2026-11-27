import 'dart:math' as math;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../models/note.dart';
import 'settings_group.dart';

const _accent = Color(0xff3D5AFE);

/// The colours on offer wherever a colour is picked, a note's cover or a
/// widget's background: iOS's system colours, with the app's own blue among
/// them, after graphite and white, which a new note has.
const colorPalette = <(String, Color)>[
  ("Graphite", Color(Note.defaultCoverColor)),
  ("White", Color(Note.defaultTitleColor)),
  ("Red", Color(0xffFF3B30)),
  ("Orange", Color(0xffFF9500)),
  ("Yellow", Color(0xffFFCC00)),
  ("Green", Color(0xff34C759)),
  ("Teal", Color(0xff30B0C7)),
  ("Blue", _accent),
  ("Indigo", Color(0xff5856D6)),
  ("Purple", Color(0xffAF52DE)),
  ("Pink", Color(0xffFF2D55)),
];

/// [color]'s name in the palette, "Custom" for any other colour, or
/// "Automatic" for none.
String colorName(Color? color) => color == null
    ? "Automatic"
    : colorPalette
          .firstWhere(
            (entry) => entry.$2 == color,
            orElse: () => ("Custom", color),
          )
          .$1;

/// A row for a colour, showing which it is, as the task dialog's rows show
/// their date and time. A tap opens the palette under it, or closes it
/// again. A row that [offersAutomatic] starts its palette with a choice of
/// no colour of its own, null, which works one out.
class ColorTile extends StatelessWidget {
  const ColorTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.open,
    required this.onTap,
    required this.onSelected,
    required this.onCustom,
    this.offersAutomatic = false,
  });

  final IconData icon;
  final Color color;
  final String title;

  /// The colour chosen, or null for automatic.
  final Color? value;

  /// Whether the palette is open under the row.
  final bool open;
  final VoidCallback onTap;
  final ValueChanged<Color?> onSelected;
  final VoidCallback onCustom;
  final bool offersAutomatic;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      color: color,
      title: title,
      trailing: ColorValue(color: value, open: open),
      onTap: onTap,
      bottom: open
          // Fades in as the group grows to make room for it.
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: ColorSwatches(
                selected: value,
                offersAutomatic: offersAutomatic,
                onSelected: onSelected,
                onCustom: onCustom,
              ),
            )
          : null,
    );
  }
}

/// A row's colour, as a swatch and its name, beside a chevron that turns to
/// the palette while it's [open]. The name takes the accent then, as iOS's
/// rows do while their pickers are open.
class ColorValue extends StatelessWidget {
  const ColorValue({super.key, required this.color, required this.open});

  /// The colour, or null for automatic.
  final Color? color;
  final bool open;

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final color = this.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 22,
          child: color == null ? const AutomaticDot() : ColorDot(color),
        ),
        const SizedBox(width: 8),
        AnimatedDefaultTextStyle(
          duration: _duration,
          style: TextStyle(
            color: open ? context.colors.moreLess : ink.withValues(alpha: 0.45),
            fontSize: 16,
            fontWeight: open ? FontWeight.w500 : FontWeight.w400,
          ),
          child: Text(colorName(color)),
        ),
        const SizedBox(width: 2),
        AnimatedRotation(
          turns: open ? 0.25 : 0,
          duration: _duration,
          curve: Curves.easeOutCubic,
          child: Icon(
            Icons.chevron_right_rounded,
            size: 24,
            color: ink.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

/// The palette's colours, then one more for any other colour, six to a row,
/// or seven after a choice of automatic when it [offersAutomatic].
class ColorSwatches extends StatelessWidget {
  const ColorSwatches({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onCustom,
    this.offersAutomatic = false,
  });

  /// The colour chosen, or null for automatic.
  final Color? selected;
  final ValueChanged<Color?> onSelected;
  final VoidCallback onCustom;
  final bool offersAutomatic;

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    final inPalette =
        selected == null || colorPalette.any((entry) => entry.$2 == selected);
    final swatches = [
      if (offersAutomatic)
        SwatchButton(
          label: "Automatic",
          selected: selected == null,
          ring: context.colors.wB.withValues(alpha: 0.45),
          onTap: () => onSelected(null),
          child: const AutomaticDot(),
        ),
      for (final (name, color) in colorPalette)
        SwatchButton(
          label: name,
          selected: color == selected,
          // Leans towards the text colour, so white and graphite rings still
          // show on the dialog.
          ring: Color.lerp(color, context.colors.wB, 0.25)!,
          onTap: () => onSelected(color),
          child: ColorDot(color),
        ),
      _CustomSwatch(color: inPalette ? null : selected, onTap: onCustom),
    ];
    final perRow = offersAutomatic ? 7 : 6;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(
          38.0,
          (constraints.maxWidth - (perRow - 1) * 8) / perRow,
        );
        return Column(
          children: [
            for (var start = 0; start < swatches.length; start += perRow) ...[
              if (start > 0) const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final swatch in swatches.skip(start).take(perRow))
                    SizedBox.square(dimension: size, child: swatch),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A rainbow swatch that opens a picker for any colour, with the colour
/// picked there in its middle while it's the one chosen.
class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({required this.color, required this.onTap});

  /// The colour picked, or null while the one chosen is one of the
  /// palette's.
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SwatchButton(
      label: "Custom Color",
      selected: color != null,
      ring: context.colors.wB.withValues(alpha: 0.3),
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              Color(0xffFF3B30),
              Color(0xffFFCC00),
              Color(0xff34C759),
              Color(0xff32ADE6),
              Color(0xff5856D6),
              Color(0xffAF52DE),
              Color(0xffFF3B30),
            ],
          ),
        ),
        child: color == null
            ? null
            : Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(width: 2, color: Colors.white),
                  ),
                ),
              ),
      ),
    );
  }
}

/// A swatch that can be tapped, in a ring while it's [selected], inside
/// which it shrinks, as in iOS's colour pickers.
class SwatchButton extends StatelessWidget {
  const SwatchButton({
    super.key,
    required this.label,
    required this.selected,
    required this.ring,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final Color ring;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
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
          padding: EdgeInsets.all(selected ? 4.5 : 0),
          decoration: ShapeDecoration(
            shape: CircleBorder(
              side: BorderSide(
                width: 2,
                color: selected ? ring : ring.withValues(alpha: 0),
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A circle of [color] with a faint sheen from the top, as on the settings'
/// icons, and a hairline edge, so white and graphite show on the dialog.
class ColorDot extends StatelessWidget {
  const ColorDot(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.14)!, color],
        ),
        border: Border.all(
          width: 0.5,
          color: context.colors.wB.withValues(alpha: 0.14),
        ),
      ),
    );
  }
}

/// A circle that's half white and half graphite, as iOS draws its automatic
/// appearance: for a colour worked out for light and dark alike.
class AutomaticDot extends StatelessWidget {
  const AutomaticDot({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffffffff),
            Color(0xffffffff),
            Color(0xff2c2c2e),
            Color(0xff2c2c2e),
          ],
          stops: [0, 0.5, 0.5, 1],
        ),
        border: Border.all(
          width: 0.5,
          color: context.colors.wB.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Opens a picker for any colour, starting from [current], headed [title].
/// The colour picked, or [current] when the picker is cancelled.
Future<Color> pickCustomColor(
  BuildContext context,
  Color current,
  String title,
) {
  return showColorPickerDialog(
    context,
    current,
    pickersEnabled: const {
      ColorPickerType.both: false,
      ColorPickerType.primary: true,
      ColorPickerType.accent: false,
      ColorPickerType.bw: false,
      ColorPickerType.custom: false,
      ColorPickerType.customSecondary: false,
      ColorPickerType.wheel: true,
    },
    // Round, like the palette's swatches, and ringed, so a shade as dark as
    // the dialog still shows.
    width: 38,
    height: 38,
    borderRadius: 19,
    hasBorder: true,
    borderColor: context.colors.wB.withValues(alpha: 0.14),
    spacing: 6,
    runSpacing: 6,
    wheelDiameter: 220,
    heading: Text(
      title,
      style: TextStyle(
        color: context.colors.wB,
        fontSize: 21,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.4,
      ),
    ),
    subheading: const _PickerSubheading("Shades"),
    wheelSubheading: const _PickerSubheading("Shades"),
    selectedPickerTypeColor: _accent,
    backgroundColor: context.colors.dialogBackground,
    surfaceTintColor: Colors.transparent,
    shape: RoundedSuperellipseBorder(
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      side: context.colors.dialogSide,
    ),
    barrierColor: Colors.black54,
    actionButtons: ColorPickerActionButtons(
      dialogOkButtonLabel: "Choose",
      dialogOkButtonStyle: TextButton.styleFrom(
        foregroundColor: context.colors.moreLess,
      ),
      dialogCancelButtonStyle: TextButton.styleFrom(
        foregroundColor: context.colors.moreLess,
      ),
    ),
    // Fades and grows in, like the dialog it opens from.
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

/// A heading over the colour picker's shades.
class _PickerSubheading extends StatelessWidget {
  const _PickerSubheading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: context.colors.wB.withValues(alpha: 0.5),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}
