import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/view/screens/notes/note_editor_page/widgets/format_panel.dart';

/// A line of [text] in the line format [attributes].
List<Map<String, dynamic>> lineOf(String text,
        [Map<String, dynamic>? attributes]) =>
    [
      {'insert': text},
      {'insert': '\n', if (attributes != null) 'attributes': attributes},
    ];

void main() {
  late QuillController controller;

  Future<void> showPanel(WidgetTester tester, List<Map<String, dynamic>> text,
      {int offset = 0}) async {
    controller = QuillController(
      document: Document.fromJson(text),
      selection: TextSelection.collapsed(offset: offset),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.getTheme(isDarkMode: false),
      home: Scaffold(
        body: Center(
          // As wide as the panel is on a phone.
          child: SizedBox(
            width: 380,
            child: FormatPanel(controller: controller, onLink: () {}),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Map<String, dynamic>? lineFormats() =>
      controller.document.root.children.first.style.toJson();

  /// Waits as long as the editor takes changes to be one change to undo.
  Future<void> pause(WidgetTester tester) => tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 450)));

  testWidgets('Body takes a line out of a block of code', (tester) async {
    await showPanel(tester, lineOf("let x = 1", {'code-block': true}));
    await tester.tap(find.text("Body"));
    await tester.pump();
    expect(lineFormats(), isNull);
  });

  /// Picks out the first [length] characters.
  void pick(int length) => controller.updateSelection(
      TextSelection(baseOffset: 0, extentOffset: length), ChangeSource.local);

  testWidgets(
      "the line's own style changes nothing, so it can't join the change "
      "after it to the one before in an undo", (tester) async {
    await showPanel(tester, lineOf("Hello"));
    pick(5);
    await tester.tap(find.byTooltip("Bold"));
    await tester.pump();
    await pause(tester);
    await tester.tap(find.text("Body"));
    await tester.tap(find.byTooltip("Italic"));
    await tester.pump();
    controller.undo();
    final style = controller.document.collectStyle(0, 5);
    expect(style.containsKey(Attribute.italic.key), isFalse);
    expect(style.containsKey(Attribute.bold.key), isTrue);
  });

  testWidgets('a block of code left for Body comes back on its own in an undo',
      (tester) async {
    await showPanel(tester, lineOf("let x = 1", {'code-block': true}));
    pick(3);
    await tester.tap(find.byTooltip("Bold"));
    await tester.pump();
    await pause(tester);
    await tester.tap(find.text("Body"));
    await tester.pump();
    expect(lineFormats(), isNull);
    controller.undo();
    expect(lineFormats(), {'code-block': true});
    expect(controller.document.collectStyle(0, 3).containsKey('bold'), isTrue);
  });

  testWidgets("the line's heading scrolls into view, the smallest too",
      (tester) async {
    await showPanel(tester, lineOf("Small", {'header': 6}));
    await tester.pumpAndSettle();
    final styles = tester.getRect(find.byType(SingleChildScrollView));
    final heading = tester.getRect(find.text("Heading 6"));
    expect(heading.left, greaterThanOrEqualTo(styles.left));
    expect(heading.right, lessThanOrEqualTo(styles.right));
    expect(find.text("Title").hitTestable(), findsNothing);
  });

  testWidgets('a heading is chosen from among the smaller ones',
      (tester) async {
    await showPanel(tester, lineOf("Plain"));
    await tester.dragUntilVisible(find.text("Heading 5"),
        find.byType(SingleChildScrollView), const Offset(-100, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Heading 5"));
    await tester.pump();
    expect(lineFormats(), {'header': 5});
  });
}
