import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/utils/note_document_utils.dart';
import '../../../../../models/note.dart';
import '../../../../../models/note_preview.dart';
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
  /// Whether the card is held down. Only its scale follows it, so the card's
  /// text isn't laid out again each time it's pressed.
  final _pressed = ValueNotifier(false);

  @override
  void dispose() {
    _pressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final titleSize = context
        .select<UserViewModel, double>((user) => user.user.notesTitleSize);
    final casualFont =
        context.select<UserViewModel, bool>((user) => user.user.casual == 1);
    final coverColor = note.coverColor.toColor;
    final onCover = onCoverColor(coverColor);

    return ValueListenableBuilder<bool>(
      valueListenable: _pressed,
      builder: (context, pressed, child) => AnimatedScale(
        scale: pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: child,
      ),
      child: NoteCover(
        color: coverColor,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            widget.onLongPress();
          },
          onHighlightChanged: (pressed) => _pressed.value = pressed,
          // iOS dims a pressed card instead of rippling, and stays silent.
          enableFeedback: false,
          splashFactory: NoSplash.splashFactory,
          highlightColor: onCover.withValues(alpha: 0.06),
          child: NoteCardContent(
            note: note,
            titleSize: titleSize,
            casualFont: casualFont,
            heroTitle: true,
          ),
        ),
      ),
    );
  }
}

/// What a note's card shows on its cover: the note's title over the start
/// of its text, set out as the editor sets it, with its checklists' ticks
/// and its lists' bullets and numbers, and how far through its checklists
/// it is. Or, while it's locked, a lock over lines that give nothing away.
/// It fits the card at any [titleSize], so the settings can preview a size
/// on it.
class NoteCardContent extends StatelessWidget {
  const NoteCardContent({
    super.key,
    required this.note,
    required this.titleSize,
    required this.casualFont,
    this.heroTitle = false,
  });

  final Note note;

  /// The user's size for notes' titles, as a multiple of the default one.
  final double titleSize;
  final bool casualFont;

  /// Whether the title flies into the note's editor as it opens, as a
  /// [NoteTitleHero], which only a card on the notes page does.
  final bool heroTitle;

  @override
  Widget build(BuildContext context) {
    final cover = note.coverColor.toColor;
    final onCover = onCoverColor(cover);
    final titleStyle = TextStyle(
      color: note.titleColor.toColor,
      fontSize: 24 * titleSize,
      // As bold as the editor's title, which this one grows into.
      fontWeight: FontWeight.bold,
      height: 1.15,
      letterSpacing: -0.5 * titleSize,
    );
    // Nothing of a locked note's text is read, let alone shown.
    final preview =
        note.protected == 1 ? null : NoteDocumentUtils.preview(note);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Text(
            note.title,
            maxLines:
                _linesThatFit(context, constraints.maxHeight * 0.6, titleStyle)
                    .clamp(1, 3),
            overflow: TextOverflow.ellipsis,
            textDirection: _textDirection(note.title),
            style: titleStyle,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The title gets at most ~60% of the card so large title
              // sizes still leave room for the preview. The cap clips the
              // rare title whose first line can't fit.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                child: heroTitle
                    ? NoteTitleHero(note: note, title: title)
                    : title,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: switch (preview) {
                    null => Directionality(
                        // From the right under a title in Arabic.
                        textDirection: _textDirection(note.title),
                        child: _LockedPreview(ink: onCover),
                      ),
                    NotePreview(lines: []) => _EmptyPreview(ink: onCover),
                    _ => _TextPreview(
                        preview: preview,
                        ink: onCover,
                        cover: cover,
                        casualFont: casualFont,
                      ),
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The surface a note is drawn on: its cover colour, lit from the top left,
/// so the colour lifts and warms towards that corner and deepens and cools
/// towards the bottom right one, with a soft glow where the light falls and
/// a rim that catches it, as glass's edge does. A shadow lifts it off the
/// page, and on dark pages a colourful cover glows a little of its own
/// colour too, as the add button does. Ink from an [InkWell] in [child]
/// shows on top of it.
class NoteCover extends StatelessWidget {
  const NoteCover({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    // Apple's continuous corners, rather than circular ones.
    const shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
    );
    // Only colours tint the shadow or glow; greys, white and black cast a
    // plain one.
    final saturation = HSVColor.fromColor(color).saturation;
    final lightCover = onCoverColor(color) == Colors.black;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: isDarkTheme
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.34 * saturation),
                  blurRadius: 30,
                  spreadRadius: -8,
                  offset: const Offset(0, 12),
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
        foregroundPainter: _RimPainter(shape: shape, lightCover: lightCover),
        child: Material(
          color: color,
          clipBehavior: Clip.antiAlias,
          shape: shape,
          child: Ink(
            decoration: BoxDecoration(gradient: _coverLight(color)),
            child: Ink(
              decoration: BoxDecoration(
                // Where the light falls, in the top corner.
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -1.05),
                  radius: 1.2,
                  colors: [
                    Colors.white.withValues(alpha: lightCover ? 0.3 : 0.14),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The light across a note's [cover]: a little brighter and warmer at the
/// top left, where it comes from, and deeper and cooler at the bottom right,
/// as a painter shifts a colour's hue towards yellow in the light and blue
/// in the shade. Greys, white and black have no hue, so only lighten and
/// deepen.
LinearGradient _coverLight(Color cover) {
  final color = HSLColor.fromColor(cover);
  final lightness = color.lightness;
  final lit = color
      .withHue(_hueTowards(color.hue, 60, 12 * color.saturation))
      .withLightness(math.min(1, lightness + 0.07));
  // Less on the darkest covers, which would turn black, and on white, which
  // would turn grey. Less of a turn, too, as yellow soon looks orange.
  final depth = 0.08 * math.min(1, math.min(lightness / 0.4, 1.6 - lightness));
  final shade = color
      .withHue(_hueTowards(color.hue, 250, 8 * color.saturation))
      .withLightness(lightness - depth);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lit.toColor(), cover, shade.toColor()],
  );
}

/// [hue] turned the shorter way round towards [target], by [degrees] at
/// most.
double _hueTowards(double hue, double target, double degrees) {
  final difference = (target - hue + 540) % 360 - 180;
  return (hue + difference.clamp(-degrees, degrees) + 360) % 360;
}

/// A note's [title] as a [Hero], which flies between the note's card and the
/// head of its editor when it's opened or closed, growing into the editor's
/// larger title or shrinking back into the card's on the way.
class NoteTitleHero extends StatelessWidget {
  const NoteTitleHero({super.key, required this.note, required this.title});

  final Note note;
  final Text title;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: (NoteTitleHero, note.id),
      // Straight there, rather than along the arc Material's heroes take.
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      flightShuttleBuilder: _flightShuttle,
      child: title,
    );
  }

  /// The title in flight. The one it's leaving fades out as the one it's
  /// heading for fades in, each laid out at its own size, so its lines break
  /// as they do there. Both are scaled on the way, so the two are always as
  /// big as each other, and one seems to turn into the other.
  static Widget _flightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = (fromHeroContext.widget as Hero).child as Text;
    final to = (toHeroContext.widget as Hero).child as Text;
    final fromSize = _sizeOf(fromHeroContext);
    final toSize = _sizeOf(toHeroContext);
    // Both ways, the animation runs from the card, at 0, to the editor, at 1.
    final (card, cardSize, editor, editorSize) =
        flightDirection == HeroFlightDirection.push
            ? (from, fromSize, to, toSize)
            : (to, toSize, from, fromSize);
    // How much larger the editor's title is than the card's.
    final growth = editor.style!.fontSize! / card.style!.fontSize!;
    return Directionality(
      // From the right for a title in Arabic, as it's lined up at both ends.
      textDirection: card.textDirection ?? TextDirection.ltr,
      // Text in flight takes the app's style for text, as on both pages,
      // rather than the warning style text outside a Material gets.
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final progress = animation.value;
            final scale = lerpDouble(1, growth, progress)!;
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                _AtSize(
                  size: cardSize,
                  child: Opacity(
                    opacity: 1 - const Interval(0, 0.6).transform(progress),
                    child: Transform.scale(
                      scale: scale,
                      alignment: AlignmentDirectional.topStart,
                      child: card,
                    ),
                  ),
                ),
                _AtSize(
                  size: editorSize,
                  child: Opacity(
                    opacity: const Interval(0.3, 1).transform(progress),
                    child: Transform.scale(
                      scale: scale / growth,
                      alignment: AlignmentDirectional.topStart,
                      child: editor,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
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

/// A hairline around a cover, bright at the top left where the light catches
/// it, as on the glass buttons, and again a little at the bottom right, as
/// glass's far edge does.
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
        ..shader = (lightCover
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.9),
                      Colors.black.withValues(alpha: 0.1),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.42),
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.18),
                    ],
                    stops: const [0, 0.4, 0.75, 1],
                  ))
            .createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.lightCover != lightCover;
}

/// A note's cover in miniature, by default the size of the settings' icons:
/// its colour, with an icon in its title's colour, or a lock when it's
/// locked.
class NoteCoverSwatch extends StatelessWidget {
  const NoteCoverSwatch({super.key, required this.note, this.size = 30});

  final Note note;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cover = note.coverColor.toColor;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          // As round as the settings' icons, at any size.
          borderRadius: BorderRadius.all(Radius.circular(size * 8 / 30)),
          side: BorderSide(
            width: 0.5,
            color: context.colors.wB.withValues(alpha: 0.12),
          ),
        ),
        // Lit as the note's card is.
        gradient: _coverLight(cover),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(
          note.protected == 1 ? Icons.lock_rounded : Icons.notes_rounded,
          size: size * 0.56,
          color: note.titleColor.toColor,
        ),
      ),
    );
  }
}

/// A note's text as its card shows it: line by line, set out as in the
/// editor, in as many whole lines as fit, the last of them fading away when
/// there's more to the note than that. A note with a checklist shows how
/// far through it it is at the foot of the card.
class _TextPreview extends StatelessWidget {
  const _TextPreview({
    required this.preview,
    required this.ink,
    required this.cover,
    required this.casualFont,
  });

  final NotePreview preview;

  /// The colour that reads on the cover.
  final Color ink;
  final Color cover;
  final bool casualFont;

  @override
  Widget build(BuildContext context) {
    final lines = _PreviewLines(
      lines: preview.lines,
      ink: ink,
      cover: cover,
      casualFont: casualFont,
    );
    final total = preview.checked + preview.unchecked;
    return Directionality(
      // From the right for a note in Arabic, its bullets and ticks too.
      textDirection:
          _textDirection(preview.lines.map((line) => line.text).join("\n")),
      child: total == 0
          ? lines
          : _WithChip(
              chip: preview.unchecked == 0
                  ? _CardChip(
                      ink: ink,
                      icon: Icons.check_circle_rounded,
                      label: "All Done",
                    )
                  : _CardChip(
                      ink: ink,
                      progress: preview.checked / total,
                      label: "${preview.checked} of $total",
                    ),
              child: lines,
            ),
    );
  }
}

/// The lines of a note's preview, in as many whole lines of text as fit.
/// Every line is as tall as the others, headings too, so they can be
/// counted out.
class _PreviewLines extends StatelessWidget {
  const _PreviewLines({
    required this.lines,
    required this.ink,
    required this.cover,
    required this.casualFont,
  });

  final List<NotePreviewLine> lines;
  final Color ink;
  final Color cover;
  final bool casualFont;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: ink.withValues(alpha: 0.66),
      fontSize: 15,
      height: 1.38,
      letterSpacing: -0.15,
      fontFamily: casualFont ? 'casual' : null,
      fontWeight: casualFont ? FontWeight.w600 : FontWeight.w400,
    );
    // Lines as tall as the text's, headings and ones with a check too.
    final strut = StrutStyle.fromTextStyle(style, forceStrutHeight: true);
    return LayoutBuilder(
      builder: (context, constraints) {
        final lineHeight = _lineHeightOf(context, style, strutStyle: strut);
        final layout = _LineLayout(
          fontSize: MediaQuery.textScalerOf(context).scale(style.fontSize!),
          lineHeight: lineHeight,
        );
        var room = (constraints.maxHeight / lineHeight).floor();
        final rows = <Widget>[];
        var cut = false;
        for (final line in lines) {
          if (room == 0) {
            cut = true;
            break;
          }
          final span = _spanOf(line, style);
          final width = constraints.maxWidth - layout.leadOf(line);
          final count = _lineCount(context, span, style, strut, width);
          final shown = math.min(count, room);
          rows.add(_PreviewRow(
            line: line,
            span: span,
            style: style,
            strut: strut,
            lines: shown,
            layout: layout,
            ink: ink,
            cover: cover,
          ));
          room -= shown;
          if (shown < count) {
            cut = true;
            break;
          }
        }
        if (rows.isEmpty) return const SizedBox.shrink();
        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
        return Align(
          alignment: AlignmentDirectional.topStart,
          // Faded, as an ellipsis only ends a line cut short, not a list
          // whose next item didn't fit.
          child: cut
              ? _FadeLastLine(lineHeight: lineHeight, child: column)
              : column,
        );
      },
    );
  }

  /// [line]'s text, in its heading's style, struck through once it's ticked
  /// off, and with its words' own formatting.
  TextSpan _spanOf(NotePreviewLine line, TextStyle style) {
    final done = line.list == NoteListKind.checked;
    // Bolder than the casual font, which is already semibold.
    final bold = casualFont ? FontWeight.w800 : FontWeight.w700;
    final lineStyle = switch (line.heading) {
      1 => TextStyle(
          color: ink.withValues(alpha: 0.92),
          fontSize: style.fontSize! * 1.12,
          fontWeight: bold,
          letterSpacing: -0.3,
        ),
      2 => TextStyle(
          color: ink.withValues(alpha: 0.88),
          fontSize: style.fontSize! * 1.06,
          fontWeight: bold,
          letterSpacing: -0.25,
        ),
      3 => TextStyle(color: ink.withValues(alpha: 0.82), fontWeight: bold),
      _ => line.quote ? TextStyle(color: ink.withValues(alpha: 0.5)) : null,
    };
    final faded = ink.withValues(alpha: 0.38);
    return TextSpan(
      style: done
          ? (lineStyle ?? const TextStyle()).copyWith(color: faded)
          : lineStyle,
      children: [
        for (final run in line.runs)
          TextSpan(
            text: run.text,
            style: TextStyle(
              fontWeight: run.bold ? bold : null,
              fontStyle: run.italic ? FontStyle.italic : null,
              decoration: TextDecoration.combine([
                if (done || run.strikethrough) TextDecoration.lineThrough,
                if (run.underline || run.link) TextDecoration.underline,
              ]),
              decorationColor: done ? faded : ink.withValues(alpha: 0.45),
              decorationThickness: done ? 1.5 : 1,
            ),
          ),
      ],
    );
  }
}

/// Where a preview's lines start: in from the edge by a step for each level
/// they're in, after a quote's bar, and after the bullet, number or check
/// of a list's item.
class _LineLayout {
  const _LineLayout({required this.fontSize, required this.lineHeight});

  /// The text's size, as large as the user has their text.
  final double fontSize;
  final double lineHeight;

  /// Room for a bullet, number or check, and for each level in.
  double get step => fontSize * 1.4;

  static const quoteBar = 2.5;
  double get quoteGap => fontSize * 0.55;

  double leadOf(NotePreviewLine line) =>
      step * line.indent +
      (line.quote ? quoteBar + quoteGap : 0) +
      (line.list != null ? step : 0);
}

/// A line of a preview, [lines] lines long, after its marks.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.line,
    required this.span,
    required this.style,
    required this.strut,
    required this.lines,
    required this.layout,
    required this.ink,
    required this.cover,
  });

  final NotePreviewLine line;
  final TextSpan span;
  final TextStyle style;
  final StrutStyle strut;
  final int lines;
  final _LineLayout layout;
  final Color ink;
  final Color cover;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (line.indent > 0) SizedBox(width: layout.step * line.indent),
        if (line.quote)
          Padding(
            padding: EdgeInsetsDirectional.only(end: layout.quoteGap),
            child: SizedBox(
              width: _LineLayout.quoteBar,
              height: layout.lineHeight * lines,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: ink.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        if (line.list case final list?)
          SizedBox(
            width: layout.step,
            height: layout.lineHeight,
            child: _ListMark(
              list: list,
              number: line.number,
              indent: line.indent,
              layout: layout,
              style: style,
              strut: strut,
              ink: ink,
              cover: cover,
            ),
          ),
        Expanded(
          child: Text.rich(
            span,
            maxLines: lines,
            overflow: TextOverflow.clip,
            style: style,
            strutStyle: strut,
          ),
        ),
      ],
    );
  }
}

/// The mark before an item of a list: a dot for a bullet, which is a ring a
/// level in; the item's number; or a check, filled in and ticked once the
/// item is done.
class _ListMark extends StatelessWidget {
  const _ListMark({
    required this.list,
    required this.number,
    required this.indent,
    required this.layout,
    required this.style,
    required this.strut,
    required this.ink,
    required this.cover,
  });

  final NoteListKind list;
  final String? number;
  final int indent;
  final _LineLayout layout;
  final TextStyle style;
  final StrutStyle strut;
  final Color ink;
  final Color cover;

  @override
  Widget build(BuildContext context) {
    final fontSize = layout.fontSize;
    return switch (list) {
      NoteListKind.numbered => Padding(
          padding: EdgeInsetsDirectional.only(end: fontSize * 0.35),
          child: Align(
            alignment: AlignmentDirectional.topEnd,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "$number.",
                maxLines: 1,
                style: style.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                strutStyle: strut,
              ),
            ),
          ),
        ),
      NoteListKind.bullet => Align(
          alignment: const AlignmentDirectional(-0.2, 0.1),
          child: CustomPaint(
            size: Size.square(fontSize * 0.34),
            painter: _BulletPainter(
              color: ink.withValues(alpha: 0.62),
              hollow: indent.isOdd,
            ),
          ),
        ),
      NoteListKind.checked || NoteListKind.unchecked => Align(
          alignment: const AlignmentDirectional(-1, 0.1),
          child: CustomPaint(
            size: Size.square(fontSize * 0.94),
            painter: _CheckPainter(
              done: list == NoteListKind.checked,
              ink: ink,
              cover: cover,
            ),
          ),
        ),
    };
  }
}

class _BulletPainter extends CustomPainter {
  const _BulletPainter({required this.color, required this.hollow});

  final Color color;
  final bool hollow;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final paint = Paint()..color = color;
    if (hollow) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.45;
    }
    canvas.drawCircle(size.center(Offset.zero),
        hollow ? radius - paint.strokeWidth / 2 : radius, paint);
  }

  @override
  bool shouldRepaint(_BulletPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.hollow != hollow;
}

/// A checklist's check on a cover: a ring in the cover's ink, or, once it's
/// [done], a disc of it with the tick cut out of it in the cover's colour,
/// so it reads on any cover, as the to-do page's blue would not.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.done,
    required this.ink,
    required this.cover,
  });

  final bool done;
  final Color ink;
  final Color cover;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    if (!done) {
      final stroke = size.shortestSide * 0.1;
      canvas.drawCircle(
        center,
        radius - stroke / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = ink.withValues(alpha: 0.5),
      );
      return;
    }
    canvas.drawCircle(
        center, radius, Paint()..color = ink.withValues(alpha: 0.88));
    // The same tick as the to-do page's.
    final width = size.width;
    final height = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(width * 0.29, height * 0.52)
        ..lineTo(width * 0.44, height * 0.67)
        ..lineTo(width * 0.72, height * 0.37),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = cover,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.done != done ||
      oldDelegate.ink != ink ||
      oldDelegate.cover != cover;
}

/// Fades [child]'s last line away to nothing at its foot.
class _FadeLastLine extends StatelessWidget {
  const _FadeLastLine({required this.lineHeight, required this.child});

  final double lineHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.white, Colors.white, Color(0x00FFFFFF)],
        stops: [
          0,
          math.max(0, 1 - lineHeight * 0.75 / bounds.height),
          1,
        ],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// [child] above a [chip] at the foot of the card, as far down as it goes,
/// or [child] alone when the card's too full for the chip.
class _WithChip extends StatelessWidget {
  const _WithChip({required this.chip, required this.child});

  final Widget chip;
  final Widget child;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < _CardChip.heightOf(context) + _gap) {
          return child;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: child),
            const SizedBox(height: _gap),
            chip,
          ],
        );
      },
    );
  }
}

/// A small capsule at the foot of a card with an [icon], or a ring filled
/// as far as [progress], and a few words about the note, as a task's card
/// has for when it's due, in the cover's ink.
class _CardChip extends StatelessWidget {
  const _CardChip({
    required this.ink,
    required this.label,
    this.icon,
    this.progress,
  });

  final Color ink;
  final String label;
  final IconData? icon;
  final double? progress;

  static const _iconSize = 14.0;
  static const _alpha = 0.85;
  static const _padding = EdgeInsetsDirectional.fromSTEB(7, 4, 9, 4);
  static const _style = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// How tall a chip is, as large as the user has their text.
  static double heightOf(BuildContext context) =>
      math.max(MediaQuery.textScalerOf(context).scale(_iconSize),
          _lineHeightOf(context, _style)) +
      _padding.vertical;

  @override
  Widget build(BuildContext context) {
    final lightCover = ink == Colors.black;
    final color = ink.withValues(alpha: _alpha);
    // As large as the words beside it.
    final iconSize = MediaQuery.textScalerOf(context).scale(_iconSize);
    final progress = this.progress;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: ink.withValues(alpha: lightCover ? 0.08 : 0.16),
      ),
      child: Padding(
        padding: _padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            progress == null
                ? Icon(icon, size: iconSize, color: color)
                : CustomPaint(
                    // A ring looks larger than an icon's glyph its size.
                    size: Size.square(iconSize * 0.9),
                    painter: _ProgressPainter(progress: progress, color: ink),
                  ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How far through its checklists a note is, as a ring that fills up.
class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.17;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.28),
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: _CardChip._alpha),
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// What a card shows for a note with nothing written in it yet.
class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Text(
      "No additional text",
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: ink.withValues(alpha: 0.4),
        fontSize: 15,
        letterSpacing: -0.15,
      ),
    );
  }
}

/// A locked note's card: lines blurred past reading, as text seen through
/// frosted glass, over a lock at its foot. They're always the same lines,
/// so they don't give away how much the note says.
class _LockedPreview extends StatelessWidget {
  const _LockedPreview({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    final lightCover = ink == Colors.black;
    return LayoutBuilder(
      builder: (context, constraints) {
        final lineHeight =
            _lineHeightOf(context, const TextStyle(fontSize: 15, height: 1.38));
        final chipHeight = _CardChip.heightOf(context);
        final lines = ((constraints.maxHeight - chipHeight - 8) / lineHeight)
            .floor()
            .clamp(0, _HiddenLinesPainter.widths.length);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lines > 0)
              CustomPaint(
                size: Size(constraints.maxWidth, lineHeight * lines),
                painter: _HiddenLinesPainter(
                  lines: lines,
                  lineHeight: lineHeight,
                  color: ink.withValues(alpha: lightCover ? 0.1 : 0.16),
                  rtl: Directionality.of(context) == TextDirection.rtl,
                ),
              ),
            const Spacer(),
            if (constraints.maxHeight >= chipHeight)
              _CardChip(ink: ink, icon: Icons.lock_rounded, label: "Locked"),
          ],
        );
      },
    );
  }
}

class _HiddenLinesPainter extends CustomPainter {
  const _HiddenLinesPainter({
    required this.lines,
    required this.lineHeight,
    required this.color,
    required this.rtl,
  });

  /// How much of the width each line takes, like the ragged ends of text.
  static const widths = [0.94, 0.78, 0.9, 0.55];

  final int lines;
  final double lineHeight;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final height = lineHeight * 0.36;
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    for (var line = 0; line < lines; line++) {
      final width = size.width * widths[line];
      final top = lineHeight * line + (lineHeight - height) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rtl ? size.width - width : 0, top, width, height),
          Radius.circular(height / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HiddenLinesPainter oldDelegate) =>
      oldDelegate.lines != lines ||
      oldDelegate.lineHeight != lineHeight ||
      oldDelegate.color != color ||
      oldDelegate.rtl != rtl;
}

TextDirection _textDirection(String text) =>
    intl.Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr;

/// Whole lines of [style] that fit in [height], so text is never cut mid-line.
int _linesThatFit(BuildContext context, double height, TextStyle style,
        {StrutStyle? strutStyle}) =>
    (height / _lineHeightOf(context, style, strutStyle: strutStyle)).floor();

/// How tall a line of [style] is laid out, as large as the user has their
/// text. A line is measured as [Text] lays it out, with [strutStyle] if it
/// has one, rather than worked out from the style: the lines come out
/// rounded to whole pixels, so 20.7 points of line are laid out 21 tall.
double _lineHeightOf(BuildContext context, TextStyle style,
    {StrutStyle? strutStyle}) {
  final line = TextPainter(
    text: TextSpan(
      text: " ",
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    strutStyle: strutStyle,
  )..layout();
  final height = line.height;
  line.dispose();
  return height;
}

/// How many lines [span] takes in [style], as [Text] lays it out [width]
/// wide.
int _lineCount(BuildContext context, TextSpan span, TextStyle style,
    StrutStyle strut, double width) {
  final painter = TextPainter(
    text: TextSpan(
      style: DefaultTextStyle.of(context).style.merge(style),
      children: [span],
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    strutStyle: strut,
  )..layout(maxWidth: math.max(0, width));
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  // An empty line is still a line.
  return math.max(1, lines);
}
