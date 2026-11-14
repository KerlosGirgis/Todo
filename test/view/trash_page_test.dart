import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/note.dart';
import 'package:todo/models/task_tree.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/trashed.dart';
import 'package:todo/view/screens/trash/trash_page/screen/trash_page.dart';
import 'package:todo/view/screens/trash/trash_page/widgets/trash_card.dart';
import 'package:todo/view_model/notes_view_model.dart';
import 'package:todo/view_model/tasks_view_model.dart';

import '../view_model/notes_view_model_test.dart'
    show FakeAuth, FakeHomeWidget, FakeNotesRepository;
import '../view_model/tasks_view_model_test.dart'
    show FakeLock, FakeNotifications, FakeTasksRepository;

void main() {
  late FakeTasksRepository taskRows;
  late FakeNotesRepository noteRows;
  late TasksViewModel tasks;
  late NotesViewModel notes;

  final today = DateTime.now();
  DateTime daysAgo(int days, [int hour = 12, int minute = 0]) =>
      DateTime(today.year, today.month, today.day - days, hour, minute);

  setUp(() {
    taskRows = FakeTasksRepository();
    noteRows = FakeNotesRepository();
    tasks = TasksViewModel(
      repository: taskRows,
      notificationService: FakeNotifications(),
      lockService: FakeLock(),
    );
    notes = NotesViewModel(
      repository: noteRows,
      authService: FakeAuth(),
      lockService: FakeLock(),
      homeWidgetService: FakeHomeWidget(),
    );
  });

  /// Puts [task] in the trash, as deleted at [deletedAt].
  Future<void> trashTask(TodoItem task, DateTime deletedAt) async {
    final id = await taskRows.insertItem(task);
    await taskRows.moveToTrash(TaskBranch(task.copyWith(id: id)),
        deletedAt: deletedAt);
  }

  /// Puts [note] in the trash, as deleted at [deletedAt].
  Future<void> trashNote(Note note, DateTime deletedAt) async {
    noteRows.rows.add(note);
    await noteRows.moveToTrash(note, deletedAt: deletedAt);
  }

  /// Lets [duration] go by a frame at a time, as it does on a phone, for
  /// the animations in it: a single pump would draw only their first frame.
  Future<void> wait(WidgetTester tester,
      [Duration duration = const Duration(seconds: 1)]) async {
    const frame = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < duration; waited += frame) {
      await tester.pump(frame);
    }
  }

  Future<void> openTrash(WidgetTester tester, TrashKind kind) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: tasks),
        ChangeNotifierProvider.value(value: notes),
      ],
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: false),
          home: TrashPage(kind: kind),
        ),
      ),
    ));
    // The trash is read in, then its cards rise in.
    await wait(tester, const Duration(seconds: 2));
  }

  /// Lets the toasts close, then closes the page and lets the view models
  /// go, with their timers.
  Future<void> finish(WidgetTester tester) async {
    await wait(tester, const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    tasks.dispose();
  }

  /// The button with [tooltip] on the card titled [title].
  Finder buttonOn(String title, String tooltip) => find.descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byWidgetPredicate(
              (widget) => widget is TrashTaskCard || widget is TrashNoteCard),
        ),
        matching: find.byTooltip(tooltip),
      );

  testWidgets("lists the deleted tasks, the last first, and puts one back",
      (tester) async {
    await trashTask(TodoItem(uuid: "shop", title: "Shop"), daysAgo(3));
    await trashTask(
        TodoItem(uuid: "call", title: "Call", desc: "About the trip\nSoon"),
        daysAgo(0, 9, 30));
    await openTrash(tester, TrashKind.task);

    expect(find.text("2 TASKS"), findsOneWidget);
    expect(find.text("About the trip"), findsOneWidget);
    expect(find.text("Deleted today at 9:30 AM"), findsOneWidget);
    expect(find.text("Deleted 3 days ago"), findsOneWidget);
    expect(tester.getTopLeft(find.text("Call")).dy,
        lessThan(tester.getTopLeft(find.text("Shop")).dy));

    await tester.tap(buttonOn("Call", "Restore"));
    await wait(tester);
    expect(find.text("Call"), findsNothing);
    expect(find.text("Task Restored"), findsOneWidget);
    expect(taskRows.rows.map((task) => task.title), ["Call"]);
    expect(tasks.items.map((task) => task.title), ["Call"]);
    expect(find.text("1 TASK"), findsOneWidget);
    await finish(tester);
  });

  testWidgets("deletes a task for good only once the user says to",
      (tester) async {
    await trashTask(TodoItem(uuid: "shop", title: "Shop"), daysAgo(1));
    await openTrash(tester, TrashKind.task);
    expect(find.text("Deleted yesterday"), findsOneWidget);

    await tester.tap(buttonOn("Shop", "Delete Forever"));
    await wait(tester);
    expect(find.text("Delete Forever?"), findsOneWidget);
    await tester.tap(find.text("Cancel"));
    await wait(tester);
    expect(taskRows.trash, hasLength(1));

    await tester.tap(buttonOn("Shop", "Delete Forever"));
    await wait(tester);
    await tester.tap(find.text("Delete"));
    await wait(tester);
    expect(taskRows.trash, isEmpty);
    expect(find.text("Shop"), findsNothing);
    expect(find.text("No Deleted Tasks"), findsOneWidget);
    await finish(tester);
  });

  testWidgets("switches to the notes, a locked one without its text",
      (tester) async {
    await trashNote(
        const Note(id: 1, title: "Plans", body: "\nWalk by the river"),
        daysAgo(2));
    await trashNote(
        const Note(id: 2, title: "Diary", body: "secret", locked: true),
        daysAgo(2));
    await openTrash(tester, TrashKind.task);
    expect(find.text("No Deleted Tasks"), findsOneWidget);
    expect(find.text("2 NOTES"), findsOneWidget);

    await tester.tap(find.text("Notes"));
    await wait(tester, const Duration(seconds: 2));
    expect(find.text("Plans"), findsOneWidget);
    expect(find.text("Walk by the river"), findsOneWidget);
    expect(find.text("Diary"), findsOneWidget);
    expect(find.text("Locked"), findsOneWidget);
    expect(find.textContaining("secret"), findsNothing);
    await finish(tester);
  });

  testWidgets("Delete All empties what's on view, once the user says to",
      (tester) async {
    await trashNote(const Note(id: 1, title: "Plans"), daysAgo(2));
    await trashNote(const Note(id: 2, title: "Ideas"), daysAgo(1));
    await trashTask(TodoItem(uuid: "shop", title: "Shop"), daysAgo(1));
    await openTrash(tester, TrashKind.note);

    await tester.tap(find.byTooltip("Menu"));
    await wait(tester);
    await tester.tap(find.byTooltip("Delete All"));
    await wait(tester);
    expect(find.text("Delete All Notes?"), findsOneWidget);
    expect(
        find.text("The 2 notes in the Trash will be deleted for good. This "
            "can't be undone."),
        findsOneWidget);
    await tester.tap(find.text("Delete"));
    await wait(tester);
    expect(noteRows.trash, isEmpty);
    expect(taskRows.trash, hasLength(1));
    expect(find.text("No Deleted Notes"), findsOneWidget);
    await finish(tester);
  });
}
