import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../../../../../core/utils/note_document_utils.dart';

/// A link in a note, and the stretch of the note's text it's on.
typedef NoteLink = ({String url, TextRange range});

/// The formatting panel's changes to a note that do more than turn a format
/// on or off.
extension NoteFormatting on QuillController {
  /// The link the cursor is on, or that the text picked out is all in.
  NoteLink? get linkAtSelection {
    final url = getSelectionStyle().attributes[Attribute.link.key]?.value;
    if (url is! String) return null;
    final line = document.queryChild(selection.start);
    // As for its style, the text before the cursor, or the first picked out.
    final leaf = (line.node as Line?)
        ?.queryChild(line.offset, selection.isCollapsed)
        .node;
    if (leaf == null || !leaf.style.containsKey(Attribute.link.key)) {
      return null;
    }
    return (url: url, range: getLinkRange(leaf));
  }

  /// Links [range] to [url], once its text is [text] if that's given, and
  /// puts the cursor after it.
  void setLink(TextRange range, String url, {String? text}) {
    var length = range.end - range.start;
    if (text != null && text != document.getPlainText(range.start, length)) {
      replaceText(range.start, length, text, null);
      length = text.length;
    }
    formatText(range.start, length, LinkAttribute(url));
    updateSelection(TextSelection.collapsed(offset: range.start + length),
        ChangeSource.local);
  }

  /// Makes [range] plain text again, rather than a link.
  void removeLink(TextRange range) =>
      formatText(range.start, range.end - range.start, Attribute.link);

  /// Puts a rule across the note where the cursor is, in place of any text
  /// picked out, on a line of its own, and carries on writing after it.
  void insertDivider() {
    final index = selection.start;
    if (!selection.isCollapsed) {
      replaceText(index, selection.end - index, '', null);
    }
    final line = document.queryChild(index).node! as Line;
    final start = line.documentOffset;
    final delta = Delta()..retain(index);
    final int after;
    if (index == start) {
      // At the start of a line, or on an empty one, it goes before the line.
      delta
        ..insert(NoteDocumentUtils.divider.toJson())
        ..insert('\n');
      after = index + 2;
    } else {
      // Further along, it splits the line, which goes on in its style after
      // it, as the line would after a line break.
      delta
        ..insert('\n', line.style.toJson())
        ..insert(NoteDocumentUtils.divider.toJson())
        ..insert('\n');
      // But a heading doesn't go on past its end.
      final end = start + line.length - 1;
      if (index == end && line.style.containsKey(Attribute.header.key)) {
        delta.retain(1, Attribute.header.toJson());
      }
      after = index + 3;
    }
    compose(delta, selection, ChangeSource.local);
    updateSelection(TextSelection.collapsed(offset: after), ChangeSource.local);
  }

  /// The text's own formats, such as bold or a link, rather than its lines':
  /// as it's written at the cursor, or anywhere in the text picked out.
  List<Attribute> get textFormats {
    if (selection.isCollapsed) {
      return [
        for (final attribute in getSelectionStyle().attributes.values)
          if (attribute.isInline) attribute,
      ];
    }
    final formats = <String, Attribute>{};
    final picked = document.toDelta().slice(selection.start, selection.end);
    for (final operation in picked.toList()) {
      operation.attributes?.forEach((key, value) {
        if (value != null && Attribute.inlineKeys.contains(key)) {
          formats[key] = Attribute.fromKeyValue(key, value)!;
        }
      });
    }
    return formats.values.toList();
  }

  /// Takes the text's own formats off it, which leaves it in its line's
  /// style.
  void clearTextFormats() {
    for (final attribute in textFormats) {
      formatSelection(Attribute.clone(attribute, null));
    }
  }
}
