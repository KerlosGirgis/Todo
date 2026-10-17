import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../../../../models/note.dart';
import '../../../../../view_model/user_view_model.dart';

class NoteCard extends StatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  // Apple's continuous corners, rather than circular ones.
  static const _shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final titleSize = context
        .select<UserViewModel, double>((user) => user.user.notesTitleSize);
    final casualFont =
        context.select<UserViewModel, bool>((user) => user.user.casual == 1);
    final coverColor = note.coverColor.toColor;
    // White or black, whichever reads better on the cover.
    final onCover =
        ThemeData.estimateBrightnessForColor(coverColor) == Brightness.dark
            ? Colors.white
            : Colors.black;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final titleStyle = TextStyle(
      color: note.titleColor.toColor,
      fontSize: 24 * titleSize,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: -0.4 * titleSize,
    );

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: _shape,
          // A soft, layered shadow on light pages; on dark ones the hairline
          // edge does the separating, as in Apple's dark mode.
          shadows: isDarkTheme
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 24,
                    spreadRadius: -6,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Material(
          color: coverColor,
          clipBehavior: Clip.antiAlias,
          shape: _shape.copyWith(
            side: BorderSide(
              width: 0.5,
              color: onCover.withValues(
                  alpha: onCover == Colors.white ? 0.14 : 0.1),
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: () {
              HapticFeedback.mediumImpact();
              widget.onLongPress();
            },
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            // iOS dims a pressed card instead of rippling, and stays silent.
            enableFeedback: false,
            splashFactory: NoSplash.splashFactory,
            highlightColor: onCover.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The title gets at most ~60% of the card so large
                      // title sizes still leave room for the preview. The
                      // cap clips the rare title whose first line can't fit.
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: constraints.maxHeight),
                        child: Text(
                          note.title,
                          maxLines: _linesThatFit(context,
                                  constraints.maxHeight * 0.6, titleStyle)
                              .clamp(1, 3),
                          overflow: TextOverflow.ellipsis,
                          textDirection: _textDirection(note.title),
                          style: titleStyle,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: note.protected == 1
                              ? _LockedPreview(color: onCover)
                              : _BodyPreview(
                                  body: note.body,
                                  color: onCover,
                                  casualFont: casualFont,
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BodyPreview extends StatelessWidget {
  const _BodyPreview({
    required this.body,
    required this.color,
    required this.casualFont,
  });

  final String body;
  final Color color;
  final bool casualFont;

  @override
  Widget build(BuildContext context) {
    // Only the start of a note fits on a card, so the rest is never laid out.
    final preview = body
        .trim()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .characters
        .take(400)
        .toString();
    if (preview.isEmpty) {
      return Text(
        "No additional text",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color.withValues(alpha: 0.4),
          fontSize: 15,
          letterSpacing: -0.15,
        ),
      );
    }
    final style = TextStyle(
      color: color.withValues(alpha: 0.62),
      fontSize: 15,
      height: 1.38,
      letterSpacing: -0.15,
      fontFamily: casualFont ? 'casual' : null,
      fontWeight: casualFont ? FontWeight.w600 : FontWeight.w400,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLines = _linesThatFit(context, constraints.maxHeight, style);
        if (maxLines < 1) return const SizedBox.shrink();
        // Fade rather than ellipsis: an ellipsis is never drawn when the last
        // visible line ends in a line break, so lists would look complete.
        // The Column lets the text size to its lines, so the fade lands on
        // the last one instead of the empty space below it.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preview,
              maxLines: maxLines,
              overflow: TextOverflow.fade,
              textDirection: _textDirection(preview),
              style: style,
            ),
          ],
        );
      },
    );
  }
}

class _LockedPreview extends StatelessWidget {
  const _LockedPreview({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final muted = color.withValues(alpha: 0.42);
    // Scales down rather than overflowing when a large title leaves little room.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 24, color: muted),
            const SizedBox(height: 6),
            Text(
              "Locked",
              style: TextStyle(
                color: muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextDirection _textDirection(String text) =>
    intl.Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr;

/// Whole lines of [style] that fit in [height], so text is never cut mid-line.
int _linesThatFit(BuildContext context, double height, TextStyle style) {
  final lineHeight =
      MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
  return (height / lineHeight).floor();
}
