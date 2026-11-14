import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/services/tour_service.dart';
import 'package:todo/view/screens/tasks/todo_page/screen/todo_page.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/task_card.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/task_map/map_node.dart';
import 'package:todo/view_model/tasks_view_model.dart';
import 'package:todo/view_model/tour_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';

import '../view_model/tasks_view_model_test.dart'
    show FakeLock, FakeNotifications, FakeTasksRepository;
import '../view_model/user_view_model_test.dart'
    show FakeDatabase, FakeDevice, FakeHomeWidget, FakeUserRepository, newLock;

/// The to-do page over tasks kept in memory, for a test to open and use.
class TodoPageHarness {
  late FakeTasksRepository rows;
  late TasksViewModel tasks;
  late UserViewModel user;

  /// Lets [duration] go by a frame at a time, as it does on a phone, for
  /// the animations in it: a single pump would draw only their first frame.
  Future<void> wait(WidgetTester tester,
      [Duration duration = const Duration(seconds: 1)]) async {
    const frame = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < duration; waited += frame) {
      await tester.pump(frame);
    }
  }

  /// Opens the page on [seed], as a list or a map, on a phone of [size].
  /// Every tour counts as seen, unless some are [due].
  Future<void> open(
    WidgetTester tester,
    List<TodoItem> seed, {
    TasksView view = TasksView.list,
    Size size = const Size(412, 915),
    Set<PageTour> due = const {},
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      for (final tour in PageTour.values)
        if (!due.contains(tour)) 'tour.${tour.name}': tour.version,
    });
    rows = FakeTasksRepository();
    for (final task in seed) {
      await rows.insertItem(task);
    }
    tasks = TasksViewModel(
      repository: rows,
      notificationService: FakeNotifications(),
      lockService: FakeLock(),
    );
    user = UserViewModel(
      repository: FakeUserRepository(),
      homeWidgetService: FakeHomeWidget(),
      lockService: newLock(),
      deviceService: FakeDevice(),
      databaseService: FakeDatabase(),
    );
    await user.get();
    await user.setTasksView(view);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: user),
        ChangeNotifierProvider.value(value: tasks),
        ChangeNotifierProvider(
            create: (_) => TourViewModel(service: TourService())),
      ],
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: false),
          home: const TodoPage(),
        ),
      ),
    ));
    // The tasks are read in, then they rise in, or branch out.
    await wait(tester, const Duration(seconds: 2));
  }

  /// Lets the toasts close, then closes the page and lets the view model
  /// go, with its timers.
  Future<void> close(WidgetTester tester) async {
    await wait(tester, const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    tasks.dispose();
  }

  /// Opens the menu at the end of the bar, then picks its item with
  /// [tooltip].
  Future<void> choose(WidgetTester tester, String tooltip) async {
    // Only on view once the menu is open.
    expect(find.byTooltip(tooltip).hitTestable(), findsNothing);
    await tester.tap(find.byTooltip("Menu"));
    await wait(tester);
    await tester.tap(find.byTooltip(tooltip));
  }

  /// The tasks as an outline: each task's title, two spaces in for each
  /// task it's inside of.
  String get outline => [
        for (final node in tasks.tree.nodes)
          "${"  " * node.depth}${node.task.title}",
      ].join("\n");

  TodoItem task(String title) =>
      tasks.items.singleWhere((task) => task.title == title);
}

/// A trip to plan, with shopping to do on the side:
///
///     Trip
///       Book
///         Flights
///       Pack
///     Shop
///       Milk
List<TodoItem> plans() => [
      TodoItem(uuid: "trip", title: "Trip"),
      TodoItem(uuid: "book", title: "Book", parent: "trip"),
      TodoItem(uuid: "flights", title: "Flights", parent: "book"),
      TodoItem(uuid: "pack", title: "Pack", parent: "trip"),
      TodoItem(uuid: "shop", title: "Shop"),
      TodoItem(uuid: "milk", title: "Milk", parent: "shop"),
    ];

void main() {
  late TodoPageHarness page;

  setUp(() => page = TodoPageHarness());

  /// The card of the task titled [title].
  Finder card(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(TaskCard));

  /// A place on [title]'s card to press and hold to pick it up: its check,
  /// as holding its title edits it instead.
  Offset handle(WidgetTester tester, String title) =>
      tester.getTopLeft(card(title)) + const Offset(26, 26);

  /// Picks [title]'s card up, carries it [by], and drops it.
  Future<void> dragCard(WidgetTester tester, String title, Offset by) async {
    final gesture = await tester.startGesture(handle(tester, title));
    await page.wait(tester, const Duration(milliseconds: 700));
    const steps = 8;
    for (var step = 0; step < steps; step++) {
      await gesture.moveBy(by / steps.toDouble());
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await page.wait(tester);
  }

  testWidgets("lists each task's subtasks under it, a step in", (tester) async {
    await page.open(tester, plans());
    final left = {
      for (final title in ["Trip", "Book", "Flights", "Pack", "Shop", "Milk"])
        title: tester.getTopLeft(card(title)).dx,
    };
    expect(left["Book"], greaterThan(left["Trip"]!));
    expect(left["Flights"], greaterThan(left["Book"]!));
    expect(left["Pack"], left["Book"]);
    expect(left["Shop"], left["Trip"]);
    expect(left["Milk"], left["Book"]);
    expect(tester.getTopLeft(card("Pack")).dy,
        greaterThan(tester.getTopLeft(card("Flights")).dy));
    // A task says how far along its subtasks are.
    expect(find.text("3 subtasks"), findsOneWidget);
    expect(find.text("1 subtask"), findsNWidgets(2));
    await page.close(tester);
  });

  testWidgets("a tap on a task's subtasks folds them away, and back",
      (tester) async {
    await page.open(tester, plans());
    await tester.tap(find.text("3 subtasks"));
    await page.wait(tester);
    expect(find.text("Book"), findsNothing);
    expect(find.text("Flights"), findsNothing);
    expect(find.text("Pack"), findsNothing);
    expect(find.text("Milk"), findsOneWidget);
    expect(page.rows.rows.first.folded, isTrue);
    // Shop's card has come up under Trip's.
    expect(tester.getTopLeft(card("Shop")).dy,
        lessThan(tester.getBottomLeft(card("Trip")).dy + 20));

    await tester.tap(find.text("3 subtasks"));
    await page.wait(tester);
    expect(find.text("Flights"), findsOneWidget);
    expect(page.rows.rows.first.folded, isFalse);
    await page.close(tester);
  });

  testWidgets("a swipe to the right adds a subtask to the task",
      (tester) async {
    await page.open(tester, plans());
    await tester.drag(find.text("Shop"), const Offset(160, 0));
    await page.wait(tester);
    expect(find.text("New Subtask"), findsOneWidget);
    // The card is still there, under the form.
    expect(page.outline.split("\n"), hasLength(6));

    await tester.enterText(find.byType(TextField).first, "Eggs");
    await tester.pump();
    await tester.tap(find.text("Add"));
    await page.wait(tester);
    expect(page.outline, endsWith("Shop\n  Milk\n  Eggs"));
    expect(find.text("2 subtasks"), findsOneWidget);
    await page.close(tester);
  });

  testWidgets(
      "a swipe to the left deletes a task with its subtasks, "
      "until Undo", (tester) async {
    await page.open(tester, plans());
    await tester.drag(find.text("Trip"), const Offset(-300, 0));
    await page.wait(tester);
    expect(page.outline, "Shop\n  Milk");
    expect(find.text("Book"), findsNothing);
    expect(find.text("Task and its 3 subtasks moved to Trash"), findsOneWidget);
    expect(page.rows.trash.single.item.subtasks, hasLength(3));

    await tester.tap(find.text("Undo"));
    await page.wait(tester);
    expect(page.outline, startsWith("Trip\n  Book\n    Flights\n  Pack"));
    expect(find.text("Flights"), findsOneWidget);
    expect(page.rows.trash, isEmpty);
    await page.close(tester);
  });

  testWidgets("checking a task off checks its subtasks off, until Undo",
      (tester) async {
    await page.open(tester, plans());
    await tester.tap(find.text("Trip"));
    await page.wait(tester);
    expect(find.text("Task done, with its 3 subtasks"), findsOneWidget);
    expect(page.task("Flights").done, isTrue);
    expect(page.task("Milk").done, isFalse);
    expect(find.text("3 of 3 subtasks"), findsOneWidget);

    await tester.tap(find.text("Undo"));
    await page.wait(tester);
    expect(page.task("Trip").done, isFalse);
    expect(page.task("Flights").done, isFalse);
    await page.close(tester);
  });

  testWidgets(
      "a dragged task takes its subtasks along, and lines up with "
      "the task under it", (tester) async {
    await page.open(tester, plans());
    // Shop, picked up and carried to just above Pack.
    final up = tester.getTopLeft(card("Pack")).dy -
        tester.getTopLeft(card("Shop")).dy -
        10;
    await dragCard(tester, "Shop", Offset(0, up));
    expect(page.outline, """
Trip
  Book
    Flights
  Shop
    Milk
  Pack""");
    expect(find.text("Milk"), findsOneWidget);
    expect(
        tester.getTopLeft(card("Shop")).dx, tester.getTopLeft(card("Pack")).dx);
    expect(tester.takeException(), isNull);
    await page.close(tester);
  });

  testWidgets("a task picked up and put back keeps its subtasks on show",
      (tester) async {
    await page.open(tester, plans());
    final gesture = await tester.startGesture(handle(tester, "Trip"));
    await page.wait(tester, const Duration(milliseconds: 700));
    // Its subtasks fold away under it while it's held.
    await page.wait(tester, const Duration(milliseconds: 400));
    expect(find.text("Flights"), findsNothing);
    await gesture.up();
    await page.wait(tester);
    expect(find.text("Flights"), findsOneWidget);
    expect(page.outline, startsWith("Trip\n  Book"));
    await page.close(tester);
  });

  testWidgets("the form moves a task into the task picked for it",
      (tester) async {
    await page.open(tester, plans());
    await tester.longPress(find.text("Pack"));
    await page.wait(tester);
    expect(find.text("Edit Task"), findsOneWidget);
    // It says which task it's in, and offers the others, but not itself.
    expect(find.text("Part Of"), findsOneWidget);
    await tester.tap(find.text("Part Of"));
    await page.wait(tester);
    expect(find.text("Pick the task this one is a part of."), findsOneWidget);
    expect(find.text("A task of its own"), findsOneWidget);
    // Not itself.
    expect(
        find.descendant(of: find.byType(ListView), matching: find.text("Pack")),
        findsNothing);
    expect(
        find.descendant(of: find.byType(ListView), matching: find.text("Milk")),
        findsOneWidget);
    await tester.tap(find.text("Shop").last);
    await page.wait(tester);
    await tester.tap(find.text("Save"));
    await page.wait(tester);
    expect(page.outline, endsWith("Shop\n  Milk\n  Pack"));
    await page.close(tester);
  });

  testWidgets("the menu shows the tasks as a map, and as a list again",
      (tester) async {
    await page.open(tester, plans());
    expect(find.byType(MapHub), findsNothing);
    await page.choose(tester, "Show as Map");
    await page.wait(tester, const Duration(seconds: 2));
    expect(find.byType(MapHub), findsOneWidget);
    expect(find.byType(TaskCard), findsNothing);
    expect(find.text("Flights"), findsOneWidget);
    expect(page.user.user.tasksView, TasksView.map);

    await page.choose(tester, "Show as List");
    await page.wait(tester, const Duration(seconds: 2));
    expect(find.byType(MapHub), findsNothing);
    expect(find.byType(TaskCard), findsNWidgets(6));
    expect(page.user.user.tasksView, TasksView.list);
    await page.close(tester);
  });

  testWidgets("each view's tour shows the first time it's on", (tester) async {
    await page.open(tester, plans(), due: {PageTour.tasks, PageTour.map});
    await page.wait(tester, const Duration(seconds: 2));
    expect(find.text("Check Off a Task"), findsOneWidget);
    await tester.tap(find.text("Skip"));
    await page.wait(tester);

    await page.choose(tester, "Show as Map");
    await page.wait(tester, const Duration(seconds: 3));
    expect(find.text("Your Tasks as a Map"), findsOneWidget);
    await tester.tap(find.text("Skip"));
    await page.wait(tester);

    // Neither shows again.
    await page.choose(tester, "Show as List");
    await page.wait(tester, const Duration(seconds: 3));
    expect(find.text("Check Off a Task"), findsNothing);
    final seen = await SharedPreferences.getInstance();
    expect(seen.getInt('tour.tasks'), PageTour.tasks.version);
    expect(seen.getInt('tour.map'), PageTour.map.version);
    await page.close(tester);
  });

  testWidgets("each view's tour ends on the menu, where the other view is",
      (tester) async {
    await page.open(tester, plans(), due: {PageTour.tasks, PageTour.map});
    await page.wait(tester, const Duration(seconds: 2));
    // To the last step, with none skipped for want of something to point at.
    for (final title in [
      "Check Off a Task",
      "Edit a Task",
      "Break a Task Down",
      "Move a Task",
      "Delete a Task",
      "Get Reminded",
      "Add a Task",
      "More Options",
    ]) {
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text("Next"));
      await page.wait(tester);
    }
    expect(find.text("See Them as a Map"), findsOneWidget);
    expect(find.textContaining("Open this menu to switch to a map"),
        findsOneWidget);
    await tester.tap(find.text("Done"));
    await page.wait(tester);

    await page.choose(tester, "Show as Map");
    await page.wait(tester, const Duration(seconds: 3));
    for (final title in [
      "Your Tasks as a Map",
      "Work on a Task",
      "Move a Task",
      "See It All",
    ]) {
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text("Next"));
      await page.wait(tester);
    }
    expect(find.text("Back to the List"), findsOneWidget);
    await tester.tap(find.text("Done"));
    await page.wait(tester);
    await page.close(tester);
  });
}
