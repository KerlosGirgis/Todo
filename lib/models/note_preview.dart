/// The start of a note's text as its card shows it, line by line with its
/// formatting, and how far through its checklist the note is.
class NotePreview {
  const NotePreview({
    required this.lines,
    this.checked = 0,
    this.unchecked = 0,
  });

  /// As many lines as a card could show, with no blank line at either end,
  /// nor two in a row.
  final List<NotePreviewLine> lines;

  /// How many of the items in the note's checklists are ticked off, and how
  /// many aren't, all through the note rather than only in [lines].
  final int checked;
  final int unchecked;
}

/// The kinds of list a line can be an item of.
enum NoteListKind { bullet, numbered, checked, unchecked }

/// A line of a note: a paragraph, a heading, or an item of a list, maybe in
/// a quote, as the editor sets it out.
class NotePreviewLine {
  const NotePreviewLine({
    required this.runs,
    this.heading = 0,
    this.list,
    this.number,
    this.indent = 0,
    this.quote = false,
  });

  final List<NotePreviewRun> runs;

  /// 1 for a title, 2 for a heading and 3 for a subheading, as the editor
  /// names them; 0 for the text in between.
  final int heading;

  /// The list the line is an item of, if it's in one.
  final NoteListKind? list;

  /// The item's number in a numbered list, as the editor counts them: "1",
  /// "b" or "iv", without the dot.
  final String? number;

  /// How many levels in the line is.
  final int indent;
  final bool quote;

  String get text => runs.map((run) => run.text).join();

  /// Whether the line is only there to space out the ones around it. An
  /// empty item of a list is still an item.
  bool get isBlank => list == null && text.trim().isEmpty;
}

/// A stretch of a line's text that's all in the same style.
class NotePreviewRun {
  const NotePreviewRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.link = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool link;
}
