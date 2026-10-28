import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/view/screens/notes/note_editor_page/widgets/note_formatting.dart';

const rule = Embed.kObjectReplacementCharacter;

/// A controller on [content], delta ops, with the cursor at [offset] or
/// [selection] picked out.
QuillController controllerOn(List<Map<String, dynamic>> content,
        {int offset = 0, TextSelection? selection}) =>
    QuillController(
      document: Document.fromJson(content),
      selection: selection ?? TextSelection.collapsed(offset: offset),
    );

/// The note's lines, each as its text, a rule's as [rule], and its line's
/// formats.
List<List<Object?>> linesOf(QuillController controller) => [
      for (final node in controller.document.root.children)
        for (final line
            in node is Block ? node.children.cast<Line>() : [node as Line])
          [line.toPlainText().replaceAll("\n", ""), line.style.toJson()],
    ];

void main() {
  group('a rule across the note', () {
    test('goes before a line the cursor starts', () {
      final controller = controllerOn([
        {'insert': 'Hello\n'}
      ]);
      controller.insertDivider();
      expect(linesOf(controller), [
        [rule, null],
        ["Hello", null]
      ]);
      expect(controller.selection.baseOffset, 2);
    });

    test('splits a line, which goes on in its style after it', () {
      final controller = controllerOn([
        {'insert': 'Hello'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'}
        },
      ], offset: 2);
      controller.insertDivider();
      expect(linesOf(controller), [
        [
          "He",
          {'list': 'bullet'}
        ],
        [rule, null],
        [
          "llo",
          {'list': 'bullet'}
        ],
      ]);
      expect(controller.selection.baseOffset, 5);
    });

    test('after a heading, leaves a plain line to write on', () {
      final controller = controllerOn([
        {'insert': 'Title'},
        {
          'insert': '\n',
          'attributes': {'header': 1}
        },
        {'insert': 'Text\n'},
      ], offset: 5);
      controller.insertDivider();
      expect(linesOf(controller), [
        [
          "Title",
          {'header': 1}
        ],
        [rule, null],
        ["", null],
        ["Text", null],
      ]);
      expect(controller.selection.baseOffset, 8);
    });

    test('takes the place of the text picked out', () {
      final controller = controllerOn([
        {'insert': 'Hello world\n'}
      ], selection: const TextSelection(baseOffset: 3, extentOffset: 8));
      controller.insertDivider();
      expect(linesOf(controller), [
        ["Hel", null],
        [rule, null],
        ["rld", null]
      ]);
    });

    test('comes off again in one undo', () {
      final controller = controllerOn([
        {'insert': 'Hello\n'}
      ], offset: 2);
      controller.insertDivider();
      controller.undo();
      expect(linesOf(controller), [
        ["Hello", null]
      ]);
    });
  });

  group('a link', () {
    final linked = [
      {'insert': 'Go to '},
      {
        'insert': 'the site',
        'attributes': {'link': 'https://example.com'}
      },
      {'insert': ' now\n'},
    ];

    test('is found from anywhere in it', () {
      for (final offset in [7, 13]) {
        final link = controllerOn(linked, offset: offset).linkAtSelection;
        expect(link?.url, 'https://example.com');
        expect(link?.range, const TextRange(start: 6, end: 14));
      }
    });

    test('is found from text picked out in it, but not partly out of it', () {
      expect(
          controllerOn(linked,
                  selection:
                      const TextSelection(baseOffset: 7, extentOffset: 10))
              .linkAtSelection
              ?.range,
          const TextRange(start: 6, end: 14));
      expect(
          controllerOn(linked,
                  selection:
                      const TextSelection(baseOffset: 4, extentOffset: 10))
              .linkAtSelection,
          isNull);
    });

    test(
        "isn't found from just before it, or after it, where what's written "
        "isn't in it", () {
      expect(controllerOn(linked, offset: 6).linkAtSelection, isNull);
      expect(controllerOn(linked, offset: 14).linkAtSelection, isNull);
    });

    test('takes its new text and where to, in one undo', () {
      final controller = controllerOn(linked);
      controller.setLink(const TextRange(start: 6, end: 14), 'https://x.org',
          text: "this");
      expect(controller.document.toPlainText(), "Go to this now\n");
      expect(controller.document.collectStyle(6, 4).attributes['link']?.value,
          'https://x.org');
      expect(controller.selection.baseOffset, 10);
      controller.undo();
      expect(controller.document.toDelta().toJson(), linked);
    });

    test('comes off its text', () {
      final controller = controllerOn(linked);
      controller.removeLink(const TextRange(start: 6, end: 14));
      expect(controller.document.toDelta().toJson(), [
        {'insert': 'Go to the site now\n'}
      ]);
    });
  });

  group("the text's formats", () {
    final styled = [
      {
        'insert': 'a',
        'attributes': {'bold': true}
      },
      {
        'insert': 'b',
        'attributes': {'italic': true}
      },
      {'insert': 'c'},
      {
        'insert': '\n',
        'attributes': {'header': 2}
      },
    ];

    test('are all of them anywhere in the text picked out, not the line\'s',
        () {
      final controller = controllerOn(styled,
          selection: const TextSelection(baseOffset: 0, extentOffset: 3));
      expect(controller.textFormats.map((format) => format.key).toSet(),
          {'bold', 'italic'});
    });

    test('come off, leaving the line as it was', () {
      final controller = controllerOn(styled,
          selection: const TextSelection(baseOffset: 0, extentOffset: 3));
      controller.clearTextFormats();
      expect(controller.document.toDelta().toJson(), [
        {'insert': 'abc'},
        {
          'insert': '\n',
          'attributes': {'header': 2}
        },
      ]);
      expect(controller.textFormats, isEmpty);
    });

    test('stop where the cursor is, for what\'s written next', () {
      final controller = controllerOn(styled, offset: 1);
      expect(controller.textFormats.map((format) => format.key), ['bold']);
      controller.clearTextFormats();
      expect(controller.textFormats, isEmpty);
      controller.replaceText(1, 0, "x", null);
      expect(
          controller.document.collectStyle(1, 1).containsKey('bold'), isFalse);
    });
  });
}
