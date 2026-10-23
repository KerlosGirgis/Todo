import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../../models/note.dart';

/// Turns a note into the document its editor works on, and that document
/// back into the plain text the note keeps beside it.
class NoteDocumentUtils {
  /// [note]'s text as a document: with its formatting, or as plain text for
  /// a note that has none saved yet.
  static Document toDocument(Note note) {
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
  /// on the note's card and on the home screen's widget.
  static String toBody(Document document) {
    final lines = <String>[];
    // How far each level of the numbered list being written out has counted.
    final counts = <int, int>{};
    for (final node in document.root.children) {
      final nodeLines =
          node is Block ? node.children.cast<Line>() : [node as Line];
      for (final line in nodeLines) {
        final attributes = line.style.attributes;
        final list = attributes[Attribute.list.key];
        final level = attributes[Attribute.indent.key]?.value as int? ?? 0;
        if (list == Attribute.ol) {
          // A deeper list that's ended starts again from one.
          counts.removeWhere((deeper, _) => deeper > level);
          counts[level] = (counts[level] ?? 0) + 1;
        } else {
          counts.clear();
        }
        final marker = switch (list) {
          Attribute.ul => "• ",
          Attribute.ol => "${_numeral(counts[level]!, level)}. ",
          // Rather than ☑, which Android draws as a colour emoji beside a
          // plain ☐.
          Attribute.checked => "☒ ",
          Attribute.unchecked => "☐ ",
          _ => "",
        };
        final text = line.toPlainText();
        lines.add(
            "${"    " * level}$marker${text.substring(0, text.length - 1)}");
      }
    }
    return lines.join("\n");
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
