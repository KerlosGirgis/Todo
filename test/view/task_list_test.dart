import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/core/result.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/task_tree.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/task_list.dart';
import 'package:todo/view_model/tasks_view_model.dart';

/// What the list and the map ask of the tasks, written down as it's asked,
/// with no view model behind it.
class RecordedActions implements TaskActions {
  final asked = <String>[];

  @override
  Future<Result> toggleDone(TodoItem task) async {
    asked.add("done ${task.title}");
    return const Success("Task Done");
  }

  @override
  Future<Result> toggleReminder(TodoItem task) async {
    asked.add("reminder ${task.title}");
    return const Info("A reminder needs a date and a time");
  }

  @override
  Future<Result> remindDaily(TodoItem task) async {
    asked.add("daily ${task.title}");
    return const Success("Reminder Set");
  }

  @override
  Future<void> setFolded(TodoItem task, bool folded) async =>
      asked.add("fold ${task.title} $folded");

  @override
  Future<Result?> syncAfterReorder(int oldIndex, int newIndex) async {
    asked.add("reorder $oldIndex $newIndex");
    return null;
  }

  @override
  Future<Result?> moveInto(TodoItem task, TodoItem? parent) async {
    asked.add("into ${task.title} ${parent?.title}");
    return null;
  }

  @override
  Future<Result?> moveBeside(
    TodoItem task,
    TodoItem sibling, {
    required bool after,
  }) async {
    asked.add("beside ${task.title} ${sibling.title} $after");
    return null;
  }
}

/// Noon on a Wednesday.
final now = DateTime(2026, 5, 13, 12);

/// Lets [duration] go by a frame at a time, as it does on a phone, for the
/// animations in it: a single pump would draw only their first frame.
Future<void> wait(
  WidgetTester tester, [
  Duration duration = const Duration(seconds: 1),
]) async {
  const frame = Duration(milliseconds: 50);
  for (var waited = Duration.zero; waited < duration; waited += frame) {
    await tester.pump(frame);
  }
}

void main() {
  late RecordedActions actions;
  late List<Result?> results;

  setUp(() {
    actions = RecordedActions();
    results = [];
  });

  final book = TodoItem(uuid: "book", title: "Book");
  final pack = TodoItem(uuid: "pack", title: "Pack");

  /// Shows the list of [tree], as the to-do page would, on a phone.
  Future<void> show(WidgetTester tester, TaskTree tree) {
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(isDarkMode: false),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              TaskList(
                tree: tree,
                now: now,
                byHand: true,
                titleScale: 1,
                descriptionScale: 1,
                descriptionLines: 2,
                actions: actions,
                listDelay: 0,
                onEdit: (task) {},
                onAddSubtask: (task) {},
                onDelete: (task) {},
                onResult: results.add,
                firstCardKey: null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets("a task that's new to the tree the list is given makes room for "
      "itself, with no view model behind the list", (tester) async {
    await show(tester, TaskTree([book, pack]));
    await wait(tester);
    final packTop = tester.getTopLeft(find.text("Pack")).dy;

    await show(
      tester,
      TaskTree([book, TodoItem(uuid: "visa", title: "Visa"), pack]),
    );
    // Its row starts with no room, and opens up.
    expect(tester.getTopLeft(find.text("Pack")).dy, closeTo(packTop, 2));
    await wait(tester);
    expect(tester.getTopLeft(find.text("Pack")).dy, greaterThan(packTop + 40));
    expect(find.text("Visa"), findsOneWidget);
  });

  testWidgets("its cards ask the actions they're given, and say how that "
      "went", (tester) async {
    await show(tester, TaskTree([book, pack]));
    await wait(tester);

    await tester.tap(find.text("Book"));
    await tester.pump();
    expect(actions.asked, ["done Book"]);
    expect((results.single as Success).message, "Task Done");

    await tester.tap(find.byIcon(Icons.notifications_none_rounded).last);
    await tester.pump();
    expect(actions.asked, ["done Book", "reminder Pack"]);
    expect(results.last, isA<Info>());
    await wait(tester);
  });
}
