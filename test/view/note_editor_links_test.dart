import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:todo/core/result.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/note.dart';
import 'package:todo/repositories/notes_repository.dart';
import 'package:todo/services/home_widget_service.dart';
import 'package:todo/view/screens/notes/note_editor_page/screen/note_editor_page.dart';
import 'package:todo/view_model/notes_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';

/// The notes table, in memory.
class FakeNotesRepository extends NotesRepository {
  final rows = <Note>[const Note(id: 1, title: "Places")];

  @override
  Future<List<Note>> getNotes() async => List.of(rows);
}

/// A home screen without the widget.
class FakeHomeWidget extends HomeWidgetService {
  @override
  Future<({int? id, String? text})> shownNote() async => (id: null, text: null);
}

void main() {
  testWidgets("the editor opens links as the link dialog wrote them",
      (tester) async {
    final notes = NotesViewModel(
      repository: FakeNotesRepository(),
      homeWidgetService: FakeHomeWidget(),
    );
    await notes.get();
    final access =
        await notes.open(notes.notes.single, askForPassword: () async => null);
    final editor = (access as Granted<NoteEditorViewModel>).value;

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => UserViewModel(),
      child: MaterialApp(
        theme: AppTheme.getTheme(isDarkMode: false),
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        builder: (context, child) =>
            // ignore: deprecated_member_use
            MaterialUiCompatibilityBridge(child: child!),
        home: NoteEditorPage(editor: editor),
      ),
    ));

    // Quill opens a link through this, and on its own would put https://
    // before any it doesn't know.
    final open = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .config
        .transformLink!;
    expect(open("geo:30.0444,31.2357"), "geo:30.0444,31.2357");
    expect(open("HTTPS://Example.com"), "HTTPS://Example.com");
    expect(open("mailto:me@example.com"), "mailto:me@example.com");
    expect(open("example.com"), "https://example.com");

    // The page rises in on timers, which have to go off before it closes.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
