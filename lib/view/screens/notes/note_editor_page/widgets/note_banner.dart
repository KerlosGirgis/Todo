import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../../models/note.dart';
import '../../notes_page/widgets/note_card.dart';

/// The note's cover across the top of its editor, which its card grows into
/// as it opens: a line saying what it is, and its title in its own colour,
/// over a large, faint glyph of a note.
class NoteBanner extends StatelessWidget {
  const NoteBanner({super.key, required this.note, required this.titleSize});

  final Note note;

  /// The user's size for notes' titles, as a multiple of the default one.
  final double titleSize;

  static const _minHeight = 136.0;
  static const _padding = EdgeInsets.fromLTRB(22, 20, 22, 22);

  /// About how tall the line over the title is.
  static const _eyebrowHeight = 15.0;

  static double _titleLineHeight(double titleSize) => 30 * titleSize * 1.15;

  /// About how far the banner scrolls before its title is under a bar above
  /// it, so the bar can bring in its own copy of the title. Its title sits
  /// at the bottom, so this is for one line of it.
  static double titleScrolledAway(double titleSize) {
    final lineHeight = _titleLineHeight(titleSize);
    final titleTop = (_minHeight - _padding.bottom - lineHeight)
        .clamp(_padding.top + _eyebrowHeight + 12, double.infinity);
    return titleTop + lineHeight * 0.6;
  }

  @override
  Widget build(BuildContext context) {
    final cover = note.coverColor.toColor;
    final onCover = onCoverColor(cover);
    final muted = onCover.withValues(alpha: 0.6);
    final locked = note.protected == 1;
    return NoteCoverHero(
      note: note,
      cover: NoteCover(
        color: cover,
        radius: 28,
        child: Directionality(
          // Lined up with the title, on the right for one in Arabic.
          textDirection: intl.Bidi.detectRtlDirectionality(note.title)
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Stack(
            children: [
              PositionedDirectional(
                end: -20,
                bottom: -30,
                child: Icon(
                  locked ? Icons.lock_outline_rounded : Icons.edit_note_rounded,
                  size: 150,
                  color: onCover.withValues(alpha: 0.07),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _minHeight),
                child: Padding(
                  padding: _padding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (locked) ...[
                            Icon(Icons.lock_rounded, size: 14, color: muted),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            locked ? "LOCKED NOTE" : "NOTE",
                            style: TextStyle(
                              color: muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          note.title,
                          style: TextStyle(
                            color: note.titleColor.toColor,
                            fontSize: 30 * titleSize,
                            fontWeight: FontWeight.bold,
                            height: 1.15,
                            letterSpacing: -0.6 * titleSize,
                          ),
                        ),
                      ),
                    ],
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
