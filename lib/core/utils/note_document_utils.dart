import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../../models/note.dart';
import '../../models/note_preview.dart';

/// Turns a note's text into the delta ops its editor works on, and those
/// back into the note, with the plain text it keeps beside them.
class NoteDocumentUtils {
  /// [note]'s text with its formatting, as Quill delta ops: as it was saved,
  /// or as plain text for a note that has no formatting saved yet.
  static List<Map<String, dynamic>> contentOf(Note note) =>
      _toDocument(note).toDelta().toJson();

  /// [note] with [content], delta ops, as its text: as [Note.delta], and
  /// without its formatting as [Note.body].
  static Note withContent(Note note, List<Map<String, dynamic>> content) =>
      note.copyWith(
        body: _toBody(Document.fromJson(content)),
        delta: jsonEncode(content),
      );

  /// [note]'s text as a document: with its formatting, or as plain text for
  /// a note that has none saved yet.
  static Document _toDocument(Note note) {
    final delta = note.delta;
    if (delta != null) {
      try {
        return Document.fromJson(jsonDecode(delta) as List);
      } catch (e) {
        // Opens as its plain text, rather than not at all.
      }
    }
    return Document.fromDelta(Delta()..insert('${note.body}\n'));
  }

  /// [document]'s text without its formatting, for [Note.body]. Lists keep
  /// their bullets, numbers and checkboxes, so a checklist still reads as one
  /// on the home screen's widget.
  static String _toBody(Document document) {
    final lines = <String>[];
    for (final (line, number) in _numberedLines(document)) {
      final attributes = line.style.attributes;
      final level = attributes[Attribute.indent.key]?.value as int? ?? 0;
      final marker = switch (attributes[Attribute.list.key]) {
        Attribute.ul => "• ",
        Attribute.ol => "$number. ",
        // Rather than ☑, which Android draws as a colour emoji beside a
        // plain ☐.
        Attribute.checked => "☒ ",
        Attribute.unchecked => "☐ ",
        _ => "",
      };
      final text = line.toPlainText();
      lines
          .add("${"    " * level}$marker${text.substring(0, text.length - 1)}");
    }
    return lines.join("\n");
  }

  /// The start of [note]'s text, with its formatting, as the note's card
  /// shows it. The last few are kept, as cards are built far more often than
  /// notes change.
  static NotePreview preview(Note note) {
    // A note with no formatting saved is only its text.
    final key = note.delta ?? "\u0000${note.body}";
    // Taken out and put back, so the ones used least recently go first.
    final preview = _previews.remove(key) ?? _preview(_toDocument(note));
    _previews[key] = preview;
    if (_previews.length > 64) _previews.remove(_previews.keys.first);
    return preview;
  }

  static final _previews = <String, NotePreview>{};

  /// More than a card can show, however small its text and large the screen.
  static const _previewLength = 400;
  static const _previewLines = 30;

  static NotePreview _preview(Document document) {
    final lines = <NotePreviewLine>[];
    var length = 0;
    var checked = 0;
    var unchecked = 0;
    for (final (line, number) in _numberedLines(document)) {
      final attributes = line.style.attributes;
      final list = switch (attributes[Attribute.list.key]) {
        Attribute.ul => NoteListKind.bullet,
        Attribute.ol => NoteListKind.numbered,
        Attribute.checked => NoteListKind.checked,
        Attribute.unchecked => NoteListKind.unchecked,
        _ => null,
      };
      // The whole checklist is counted, beyond what the card shows of it.
      if (list == NoteListKind.checked) checked++;
      if (list == NoteListKind.unchecked) unchecked++;
      if (length >= _previewLength || lines.length >= _previewLines) continue;
      final previewLine = NotePreviewLine(
        runs: [
          for (final leaf in line.children)
            if (leaf is QuillText && leaf.value.isNotEmpty)
              NotePreviewRun(
                leaf.value,
                bold: leaf.style.containsKey(Attribute.bold.key),
                italic: leaf.style.containsKey(Attribute.italic.key),
                underline: leaf.style.containsKey(Attribute.underline.key),
                strikethrough:
                    leaf.style.containsKey(Attribute.strikeThrough.key),
                link: leaf.style.containsKey(Attribute.link.key),
              ),
        ],
        heading: attributes[Attribute.header.key]?.value as int? ?? 0,
        list: list,
        number: number,
        indent: attributes[Attribute.indent.key]?.value as int? ?? 0,
        quote: attributes.containsKey(Attribute.blockQuote.key),
      );
      // No blank line first, nor two in a row.
      if (previewLine.isBlank && (lines.isEmpty || lines.last.isBlank)) {
        continue;
      }
      lines.add(previewLine);
      length += previewLine.text.length;
    }
    // Nor one last.
    if (lines.isNotEmpty && lines.last.isBlank) lines.removeLast();
    return NotePreview(lines: lines, checked: checked, unchecked: unchecked);
  }

  /// [document]'s lines in order, each with its number if it's an item of a
  /// numbered list.
  static Iterable<(Line, String?)> _numberedLines(Document document) sync* {
    // How far each level of the numbered list being written out has counted.
    final counts = <int, int>{};
    for (final node in document.root.children) {
      final nodeLines =
          node is Block ? node.children.cast<Line>() : [node as Line];
      for (final line in nodeLines) {
        final attributes = line.style.attributes;
        final level = attributes[Attribute.indent.key]?.value as int? ?? 0;
        if (attributes[Attribute.list.key] == Attribute.ol) {
          // A deeper list that's ended starts again from one.
          counts.removeWhere((deeper, _) => deeper > level);
          counts[level] = (counts[level] ?? 0) + 1;
          yield (line, _numeral(counts[level]!, level));
        } else {
          counts.clear();
          yield (line, null);
        }
      }
    }
  }

  /// [count] as the editor numbers a list at [level]: 1, 2, 3, then a, b, c
  /// a level in, then i, ii, iii, and round again.
  static String _numeral(int count, int level) => switch (level % 3) {
        1 => _letters(count),
        2 => _roman(count),
        _ => "$count",
      };

  /// a to z, then aa, ab and on, as a spreadsheet's columns.
  static String _letters(int count) {
    var letters = "";
    for (var n = count; n > 0; n = (n - 1) ~/ 26) {
      letters = String.fromCharCode(97 + (n - 1) % 26) + letters;
    }
    return letters;
  }

  static String _roman(int count) {
    const numerals = [
      (1000, "m"),
      (900, "cm"),
      (500, "d"),
      (400, "cd"),
      (100, "c"),
      (90, "xc"),
      (50, "l"),
      (40, "xl"),
      (10, "x"),
      (9, "ix"),
      (5, "v"),
      (4, "iv"),
      (1, "i")
    ];
    final roman = StringBuffer();
    var rest = count;
    for (final (value, numeral) in numerals) {
      for (; rest >= value; rest -= value) {
        roman.write(numeral);
      }
    }
    return roman.toString();
  }
}
