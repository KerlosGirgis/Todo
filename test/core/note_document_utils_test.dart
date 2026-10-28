import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/utils/note_document_utils.dart';
import 'package:todo/models/note.dart';
import 'package:todo/models/note_preview.dart';

/// A note whose text is [content], delta ops.
Note noteOf(List<Map<String, dynamic>> content) =>
    NoteDocumentUtils.withContent(const Note(title: "Test"), content);

Map<String, dynamic> line([Map<String, dynamic>? attributes]) =>
    {'insert': '\n', if (attributes != null) 'attributes': attributes};

/// Every format Markdown has: the smaller headings, code in a line and in a
/// block of its own, highlighting, raised and lowered text, and a rule
/// across the note.
final markdown = [
  {'insert': 'Small'},
  line({'header': 6}),
  {'insert': 'Run '},
  {
    'insert': 'flutter test',
    'attributes': {'code': true}
  },
  {'insert': ' and '},
  {
    'insert': 'mark',
    'attributes': {'background': '#ffff00'}
  },
  {'insert': ' E=mc'},
  {
    'insert': '2',
    'attributes': {'script': 'super'}
  },
  {'insert': ' H'},
  {
    'insert': '2',
    'attributes': {'script': 'sub'}
  },
  {'insert': 'O'},
  line(),
  {
    'insert': {'divider': 'hr'}
  },
  line(),
  {'insert': 'void main() {'},
  line({'code-block': true}),
  line({'code-block': true}),
  {'insert': '}'},
  line({'code-block': true}),
];

void main() {
  group('preview', () {
    late List<NotePreviewLine> lines;

    setUp(() => lines = NoteDocumentUtils.preview(noteOf(markdown)).lines);

    test('reads the smaller headings', () {
      expect(lines.first.heading, 6);
      expect(lines.first.text, "Small");
    });

    test('reads code, highlighting, and raised and lowered text', () {
      final runs = {for (final run in lines[1].runs) run.text: run};
      expect(runs["flutter test"]!.code, isTrue);
      expect(runs["mark"]!.highlight, isTrue);
      expect(runs["mark"]!.code, isFalse);
      final scripts = lines[1].runs.where((run) => run.text == "2").toList();
      expect(scripts.map((run) => (run.superscript, run.subscript)),
          [(true, false), (false, true)]);
    });

    test('keeps a rule across the note as a line of its own', () {
      expect(lines[2].divider, isTrue);
      expect(lines[2].isBlank, isFalse);
    });

    test('keeps a block of code whole, its empty lines too', () {
      expect(lines.skip(3).map((line) => (line.code, line.text)), [
        (true, "void main() {"),
        (true, ""),
        (true, "}"),
      ]);
    });
  });

  test('a rule across the note reads as dashes in the plain text', () {
    expect(
      noteOf(markdown).body,
      "Small\n"
      "Run flutter test and mark E=mc2 H2O\n"
      "${NoteDocumentUtils.dividerText}\n"
      "void main() {\n"
      "\n"
      "}",
    );
  });

  test('a rule ends a numbered list, as the editor numbers them', () {
    final note = noteOf([
      {'insert': 'One'},
      line({'list': 'ordered'}),
      {
        'insert': {'divider': 'hr'}
      },
      line(),
      {'insert': 'One again'},
      line({'list': 'ordered'}),
    ]);
    expect(note.body, "1. One\n${NoteDocumentUtils.dividerText}\n1. One again");
  });
}
