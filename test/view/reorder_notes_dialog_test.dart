import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/note.dart';
import 'package:todo/view/screens/notes/notes_page/widgets/reorder_notes_dialog.dart';
import 'package:todo/view_model/notes_view_model.dart';

import '../view_model/notes_view_model_test.dart'
    show FakeAuth, FakeHomeWidget, FakeLock, FakeNotesRepository;

void main() {
  late FakeNotesRepository repository;
  late NotesViewModel notes;

  /// Lets [duration] go by a frame at a time, as it does on a phone, for
  /// the animations in it: a single pump would draw only their first frame.
  Future<void> wait(
    WidgetTester tester, [
    Duration duration = const Duration(seconds: 1),
  ]) async {
    const frame = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < duration; waited += frame) {
      await tester.pump(frame);
    }
  }

  /// Opens the dialog over three notes: Open, Shop and Call.
  Future<void> open(WidgetTester tester) async {
    repository = FakeNotesRepository();
    repository.rows.addAll(const [
      Note(id: 1, title: "Open"),
      Note(id: 2, title: "Shop"),
      Note(id: 3, title: "Call"),
    ]);
    notes = NotesViewModel(
      repository: repository,
      authService: FakeAuth(),
      lockService: FakeLock(),
      homeWidgetService: FakeHomeWidget(),
    );
    await notes.get();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notes,
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: false),
            home: const Scaffold(body: ReorderNotesDialog()),
          ),
        ),
      ),
    );
    await wait(tester);
  }

  /// The titles of the rows, from the top down.
  List<String> rows(WidgetTester tester) {
    final titles = ["Open", "Shop", "Call"];
    return titles..sort(
      (a, b) => tester
          .getTopLeft(find.text(a))
          .dy
          .compareTo(tester.getTopLeft(find.text(b)).dy),
    );
  }

  /// Carries the row titled [title] by its handle, [by], and drops it.
  Future<void> drag(WidgetTester tester, String title, Offset by) async {
    final handle = find.descendant(
      of: find.ancestor(
        of: find.text(title),
        matching: find.byType(ReorderableDelayedDragStartListener),
      ),
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    const steps = 8;
    for (var step = 0; step < steps; step++) {
      await gesture.moveBy(by / steps.toDouble());
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
  }

  testWidgets("a note dragged to another place is there while it's saved", (
    tester,
  ) async {
    await open(tester);
    final gate = Completer<void>();
    repository.rewriting = gate.future;
    final below =
        tester.getTopLeft(find.text("Call")).dy -
        tester.getTopLeft(find.text("Open")).dy +
        20;
    await drag(tester, "Open", Offset(0, below));
    await wait(tester);
    expect(rows(tester), ["Shop", "Call", "Open"]);

    gate.complete();
    await wait(tester);
    expect(rows(tester), ["Shop", "Call", "Open"]);
    expect(
      [for (final row in repository.rows) row.title],
      ["Shop", "Call", "Open"],
    );
  });

  testWidgets("a reorder that can't be saved says so, and the notes go back", (
    tester,
  ) async {
    await open(tester);
    repository.failUpdates = true;
    final below =
        tester.getTopLeft(find.text("Call")).dy -
        tester.getTopLeft(find.text("Open")).dy +
        20;
    await drag(tester, "Open", Offset(0, below));
    await wait(tester);
    expect(find.text("Couldn't move the note"), findsOneWidget);
    expect(rows(tester), ["Open", "Shop", "Call"]);
    // Through its toast.
    await wait(tester, const Duration(seconds: 4));
  });
}
