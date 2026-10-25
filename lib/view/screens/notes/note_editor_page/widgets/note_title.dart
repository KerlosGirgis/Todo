import 'dart:math' as math;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../models/note.dart';
import '../../notes_page/widgets/note_card.dart';

/// The head of a note in its editor, set in line with its text rather than
/// apart from it: its title, which the title on its card grows into as it
/// opens, after a swatch of its cover.
class NoteTitle extends StatelessWidget {
  const NoteTitle({super.key, required this.note, required this.titleSize});

  final Note note;

  /// The user's size for notes' titles, as a multiple of the default one.
  final double titleSize;

  static const _fontSize = 34.0;
  static const _lineHeight = 1.15;

  /// How tall a line of the title is, as large as the user has their text.
  static double _lineHeightOf(BuildContext context, double titleSize) =>
      MediaQuery.textScalerOf(context).scale(_fontSize * titleSize) *
      _lineHeight;

  /// About how far the head scrolls before its title is under a bar above
  /// it, so the bar can bring in its own copy of the title.
  static double titleScrolledAway(BuildContext context, double titleSize) =>
      _lineHeightOf(context, titleSize) * 0.6;

  @override
  Widget build(BuildContext context) {
    final direction = intl.Bidi.detectRtlDirectionality(note.title)
        ? TextDirection.rtl
        : TextDirection.ltr;
    final lineHeight = _lineHeightOf(context, titleSize);
    // Grows with the title, a little shorter than its lines.
    final swatchSize = lineHeight * 0.8;
    return Directionality(
      // Before the title, which is on the right for one in Arabic.
      textDirection: direction,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Level with the title's first line, however many it takes.
            padding: EdgeInsets.only(top: (lineHeight - swatchSize) / 2),
            child: NoteCoverSwatch(note: note, size: swatchSize),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: NoteTitleHero(
              note: note,
              title: Text(
                note.title,
                textDirection: direction,
                style: TextStyle(
                  color: _titleInk(context, note.titleColor.toColor),
                  fontSize: _fontSize * titleSize,
                  fontWeight: FontWeight.bold,
                  height: _lineHeight,
                  letterSpacing: -0.7 * titleSize,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The colour [picked] for a note's title, as it reads on the page rather
/// than on the note's cover. A white, grey or black one was only picked to
/// read on the cover, so the title takes the page's own ink instead. A
/// colourful one keeps its colour, deepened or lightened just enough to
/// stand out from the page as large text should.
Color _titleInk(BuildContext context, Color picked) {
  final ink = context.colors.wB;
  if (HSVColor.fromColor(picked).saturation < 0.2) return ink;
  final page = context.colors.pageBackground.computeLuminance();
  for (var step = 0; step < 10; step++) {
    final color = Color.lerp(picked, ink, step / 10)!;
    final luminance = color.computeLuminance();
    final contrast = (math.max(luminance, page) + 0.05) /
        (math.min(luminance, page) + 0.05);
    if (contrast >= 3) return color;
  }
  return ink;
}
