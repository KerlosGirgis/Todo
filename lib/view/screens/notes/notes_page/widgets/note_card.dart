import 'dart:ui' show lerpDouble;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../../../../models/note.dart';
import '../../../../../view_model/user_view_model.dart';

/// White or black, whichever reads better on a note's [cover].
Color onCoverColor(Color cover) =>
    ThemeData.estimateBrightnessForColor(cover) == Brightness.dark
        ? Colors.white
        : Colors.black;

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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final titleSize = context
        .select<UserViewModel, double>((user) => user.user.notesTitleSize);
    final casualFont =
        context.select<UserViewModel, bool>((user) => user.user.casual == 1);
    final coverColor = note.coverColor.toColor;
    final onCover = onCoverColor(coverColor);

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: NoteCoverHero(
        note: note,
        cover: NoteCover(
          color: coverColor,
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
            child: NoteCardContent(
              note: note,
              titleSize: titleSize,
              casualFont: casualFont,
            ),
          ),
        ),
      ),
    );
  }
}

/// What a note's card shows on its cover: the note's title over as much of
/// its text as fits, or a lock while it's locked. It fits the card at any
/// [titleSize], so the settings can preview a size on it.
class NoteCardContent extends StatelessWidget {
  const NoteCardContent({
    super.key,
    required this.note,
    required this.titleSize,
    required this.casualFont,
  });

  final Note note;

  /// The user's size for notes' titles, as a multiple of the default one.
  final double titleSize;
  final bool casualFont;

  @override
  Widget build(BuildContext context) {
    final onCover = onCoverColor(note.coverColor.toColor);
    final titleStyle = TextStyle(
      color: note.titleColor.toColor,
      fontSize: 24 * titleSize,
      fontWeight: FontWeight.w600,
      height: 1.15,
      letterSpacing: -0.4 * titleSize,
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The title gets at most ~60% of the card so large title
              // sizes still leave room for the preview. The cap clips the
              // rare title whose first line can't fit.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                child: Text(
                  note.title,
                  maxLines: _linesThatFit(
                          context, constraints.maxHeight * 0.6, titleStyle)
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
    );
  }
}

/// The surface a note is drawn on: its cover colour, lit softly from above,
/// with a rim that catches the light along its top edge. A shadow lifts it
/// off light pages, and on dark ones a colourful cover glows a little of its
/// own colour, as the add button does. Ink from an [InkWell] in [child]
/// shows on top of it.
class NoteCover extends StatelessWidget {
  const NoteCover({
    super.key,
    required this.color,
    required this.child,
    this.radius = 24,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    // Apple's continuous corners, rather than circular ones.
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
    );
    // Only colours tint the shadow or glow; greys, white and black cast a
    // plain one.
    final saturation = HSVColor.fromColor(color).saturation;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: isDarkTheme
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3 * saturation),
                  blurRadius: 28,
                  spreadRadius: -8,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Color.lerp(Colors.black, color, 0.5 * saturation)!
                      .withValues(alpha: 0.08 + 0.1 * saturation),
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
      child: CustomPaint(
        foregroundPainter: _RimPainter(
          shape: shape,
          lightCover: onCoverColor(color) == Colors.black,
        ),
        child: Material(
          color: color,
          clipBehavior: Clip.antiAlias,
          shape: shape,
          child: Ink(
            decoration: BoxDecoration(
              // A faint sheen from the top, as on the settings' icons.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(color, Colors.white, 0.08)!,
                  color,
                  Color.lerp(color, Colors.black, 0.04)!,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A note's [cover] as a [Hero], which flies between the note's card and the
/// top of its editor when it's opened or closed, turning from one into the
/// other on the way.
class NoteCoverHero extends StatelessWidget {
  const NoteCoverHero({super.key, required this.note, required this.cover});

  final Note note;
  final NoteCover cover;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: (NoteCoverHero, note.id),
      // Straight there, rather than along the arc Material's heroes take.
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      flightShuttleBuilder: _flightShuttle,
      child: cover,
    );
  }

  /// The cover in flight. It eases between the two covers' corners, while
  /// the content it's leaving fades out and then the content it's heading
  /// for fades in. Each is laid out at its own cover's size, rather than
  /// rewrapping as the cover grows or shrinks, and cropped to it.
  static Widget _flightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = (fromHeroContext.widget as Hero).child as NoteCover;
    final to = (toHeroContext.widget as Hero).child as NoteCover;
    final fromSize = _sizeOf(fromHeroContext);
    final toSize = _sizeOf(toHeroContext);
    // Both ways, the animation runs from the card, at 0, to the editor, at 1.
    final (card, cardSize, editor, editorSize) =
        flightDirection == HeroFlightDirection.push
            ? (from, fromSize, to, toSize)
            : (to, toSize, from, fromSize);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;
        return NoteCover(
          color: editor.color,
          radius: lerpDouble(card.radius, editor.radius, progress)!,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _AtSize(
                size: cardSize,
                child: Opacity(
                  opacity: 1 - const Interval(0, 0.4).transform(progress),
                  child: card.child,
                ),
              ),
              _AtSize(
                size: editorSize,
                child: Opacity(
                  opacity: const Interval(0.5, 1).transform(progress),
                  child: editor.child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Size? _sizeOf(BuildContext context) {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : null;
  }
}

/// Lays [child] out at [size], from the top start corner of the room it's
/// given, or fills that room when there's no [size].
class _AtSize extends StatelessWidget {
  const _AtSize({required this.size, required this.child});

  final Size? size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = this.size;
    if (size == null) return child;
    return OverflowBox(
      alignment: AlignmentDirectional.topStart,
      minWidth: size.width,
      maxWidth: size.width,
      minHeight: size.height,
      maxHeight: size.height,
      child: child,
    );
  }
}

/// A hairline around a cover, bright along the top where the light catches
/// it and fading towards the bottom, as on the glass buttons.
class _RimPainter extends CustomPainter {
  const _RimPainter({required this.shape, required this.lightCover});

  final ShapeBorder shape;
  final bool lightCover;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawPath(
      shape.getOuterPath(rect.deflate(0.25)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: lightCover
              ? [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.black.withValues(alpha: 0.1),
                ]
              : [
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.08),
                ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.lightCover != lightCover;
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
              // Every line as tall as they're counted, even one with a
              // checklist's box, which comes from another font.
              strutStyle:
                  StrutStyle.fromTextStyle(style, forceStrutHeight: true),
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
