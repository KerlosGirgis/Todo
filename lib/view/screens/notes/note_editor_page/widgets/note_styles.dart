import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../widgets/check_circle.dart';

/// A note's text as the editor draws it, at the user's text [size] and in
/// the casual font if they've chosen it.
TextStyle noteBodyStyle(BuildContext context,
        {required double size, required bool casualFont}) =>
    TextStyle(
      fontFamily: casualFont ? 'casual' : 'arial',
      fontWeight: casualFont ? FontWeight.w600 : FontWeight.w400,
      color: context.colors.wB,
      fontSize: 26 * size,
      height: 1.4,
      // As the theme spaces the app's text, which a list's numbers and
      // bullets pick up beside the text they lead.
      leadingDistribution: TextLeadingDistribution.even,
    );

/// How the editor draws a note's formatting, around [body], its plain text:
/// titles and headings larger and bolder, links in the accent, quotes set in
/// behind a bar of it, and checklists with the to-do page's checks.
DefaultStyles noteStyles(BuildContext context, TextStyle body) {
  final ink = body.color!;
  final fontSize = body.fontSize!;
  final link = context.colors.moreLess;
  DefaultTextBlockStyle heading(double scale, FontWeight weight,
          {required double spaceAbove}) =>
      DefaultTextBlockStyle(
        body.copyWith(
          fontSize: fontSize * scale,
          fontWeight: weight,
          height: 1.25,
          letterSpacing: -0.02 * fontSize * scale,
        ),
        HorizontalSpacing.zero,
        VerticalSpacing(fontSize * spaceAbove, fontSize * 0.1),
        VerticalSpacing.zero,
        null,
      );
  return DefaultStyles(
    paragraph: DefaultTextBlockStyle(body, HorizontalSpacing.zero,
        VerticalSpacing.zero, VerticalSpacing.zero, null),
    h1: heading(1.42, FontWeight.w700, spaceAbove: 0.5),
    h2: heading(1.2, FontWeight.w700, spaceAbove: 0.4),
    h3: heading(1.06, FontWeight.w700, spaceAbove: 0.3),
    placeHolder: DefaultTextBlockStyle(
        body.copyWith(color: ink.withValues(alpha: 0.3)),
        HorizontalSpacing.zero,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null),
    // Bolder than the casual font, which is already semibold.
    bold: TextStyle(
        fontWeight: body.fontWeight == FontWeight.w600
            ? FontWeight.w800
            : FontWeight.w700),
    link: TextStyle(
      color: link,
      decoration: TextDecoration.underline,
      decorationColor: link.withValues(alpha: 0.5),
    ),
    // Bullets and numbers in the text's own style.
    leading: DefaultTextBlockStyle(body, HorizontalSpacing.zero,
        VerticalSpacing.zero, VerticalSpacing.zero, null),
    lists: DefaultListBlockStyle(
      // A list's lines keep their paragraph's or heading's style.
      const TextStyle(),
      HorizontalSpacing.zero,
      VerticalSpacing(fontSize * 0.25, 0),
      VerticalSpacing(0, fontSize * 0.25),
      null,
      _CheckboxBuilder(body),
    ),
    quote: DefaultTextBlockStyle(
      TextStyle(color: ink.withValues(alpha: 0.65)),
      HorizontalSpacing.zero,
      VerticalSpacing(fontSize * 0.25, fontSize * 0.25),
      VerticalSpacing.zero,
      BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(width: 3, color: link.withValues(alpha: 0.7)),
        ),
      ),
    ),
  );
}

/// Draws the text of a checklist's ticked lines faded back and struck
/// through, as a task is once it's done. It's done to each run of the text,
/// rather than to the line, as the editor clears a line's decoration from
/// the runs it styles itself, such as bold ones.
TextSpanBuilder checkedLinesSpanBuilder(TextStyle body) {
  final faded = body.color!.withValues(alpha: 0.38);
  return (context, node, nodeOffset, text, style, recognizer) {
    final line = node.parent;
    if (line is Line &&
        line.style.attributes[Attribute.list.key] == Attribute.checked) {
      final decoration = style?.decoration;
      style = (style ?? const TextStyle()).copyWith(
        color: faded,
        // Underlined text stays underlined, too.
        decoration: TextDecoration.combine([
          if (decoration != null) decoration,
          TextDecoration.lineThrough,
        ]),
        decorationColor: faded,
        decorationThickness: 1.5,
      );
    }
    return defaultSpanBuilder(
        context, node, nodeOffset, text, style, recognizer);
  };
}

/// A checklist's checks, as the to-do page's.
class _CheckboxBuilder implements QuillCheckboxBuilder {
  const _CheckboxBuilder(this.body);

  final TextStyle body;

  @override
  Widget build({
    required BuildContext context,
    required bool isChecked,
    required ValueChanged<bool> onChanged,
  }) =>
      _Checkbox(body: body, checked: isChecked, onChanged: onChanged);
}

/// A check that ticks itself off, or fades back to a ring, as it's tapped.
/// The room before a line of a checklist, from the edge to the text, is all
/// for tapping it.
class _Checkbox extends StatelessWidget {
  const _Checkbox({
    required this.body,
    required this.checked,
    required this.onChanged,
  });

  final TextStyle body;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final fontSize = body.fontSize!;
    final size = fontSize * 0.92;
    // Level with the line's first line of text, however large it's scaled.
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(fontSize) * body.height!;
    return Semantics(
      checked: checked,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onChanged(!checked);
        },
        child: Align(
          alignment: AlignmentDirectional.topEnd,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              top: math.max(0, (lineHeight - size) / 2),
              end: fontSize * 0.4,
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: checked ? 1 : 0),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, doneness, child) =>
                  CheckCircle(doneness: doneness, size: size),
            ),
          ),
        ),
      ),
    );
  }
}
