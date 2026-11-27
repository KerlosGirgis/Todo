import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/task_filters.dart';
import 'package:todo/models/task_listing.dart';
import 'package:todo/models/task_sort.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/services/tour_service.dart';
import 'package:todo/view/screens/tasks/todo_page/screen/todo_page.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/task_card.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/task_map/map_node.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/tasks_summary_card.dart';
import 'package:todo/view/widgets/glass_popover.dart';
import 'package:todo/view_model/auth_view_model.dart';
import 'package:todo/view_model/tasks_view_model.dart';
import 'package:todo/view_model/tour_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:todo/view_model/widgets_view_model.dart';

import '../view_model/tasks_view_model_test.dart'
    show FakeLock, FakeNotifications, FakeTasksRepository;
import '../view_model/user_view_model_test.dart'
    show FakeDatabase, FakeDevice, FakeUserRepository, FakeVerses, newLock;
import '../view_model/widgets_view_model_test.dart' show FakeWidgets;

/// The to-do page over tasks kept in memory, for a test to open and use.
class TodoPageHarness {
  late FakeTasksRepository rows;
  late TasksViewModel tasks;
  late UserViewModel user;
  late WidgetsViewModel widgets;

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

  /// Opens the page on [seed], as a list or a map, on a phone of [size],
  /// with the tasks listed as [listing] if it was kept from before, and the
  /// tasks going by [clock], or the phone's. Every tour counts as seen,
  /// unless some are [due]. The tasks can't be read in when [unreadable].
  Future<void> open(
    WidgetTester tester,
    List<TodoItem> seed, {
    TasksView view = TasksView.list,
    Size size = const Size(412, 915),
    Set<PageTour> due = const {},
    TaskListing? listing,
    DateTime Function()? clock,
    bool unreadable = false,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      for (final tour in PageTour.values)
        if (!due.contains(tour)) 'tour.${tour.name}': tour.version,
    });
    rows = FakeTasksRepository()..listing = listing;
    for (final task in seed) {
      await rows.insertItem(task);
    }
    rows.failReads = unreadable;
    tasks = TasksViewModel(
      repository: rows,
      notificationService: FakeNotifications(),
      lockService: FakeLock(),
      clock: clock,
    );
    user = UserViewModel(
      repository: FakeUserRepository(),
      lockService: newLock(),
      deviceService: FakeDevice(),
      databaseService: FakeDatabase(),
    );
    await user.get();
    await user.setTasksView(view);
    final auth = AuthViewModel(
      user,
      lockService: newLock(),
      databaseService: FakeDatabase(),
      deviceService: FakeDevice(),
      verseService: FakeVerses(),
    );
    widgets = WidgetsViewModel(service: FakeWidgets());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          ChangeNotifierProvider.value(value: tasks),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: widgets),
          ChangeNotifierProvider(
            create: (_) => TourViewModel(service: TourService()),
          ),
        ],
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.getTheme(isDarkMode: false),
            home: const TodoPage(),
          ),
        ),
      ),
    );
    // The tasks are read in, then they rise in, or branch out.
    await wait(tester, const Duration(seconds: 2));
  }

  /// Lets the toasts close, then closes the page and lets the view model
  /// go, with its timers.
  Future<void> close(WidgetTester tester) async {
    await wait(tester, const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    tasks.dispose();
    widgets.dispose();
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

  /// The choice called [label] in the sort's or the filter's panel, while
  /// it's open.
  Finder choice(String label) => find.descendant(
    of: find.byType(GlassPopoverOption),
    matching: find.text(label),
  );

  /// Opens the panel of the bar's button with [tooltip], Sort or Filter,
  /// then picks [label] in it.
  Future<void> pick(WidgetTester tester, String tooltip, String label) async {
    await tester.tap(find.byTooltip(tooltip));
    await wait(tester);
    await tester.tap(choice(label));
    await wait(tester);
  }

  /// The titles of the list's cards, from the top down.
  List<String> cards(WidgetTester tester) => [
    for (final card in tester.widgetList<TaskCard>(find.byType(TaskCard)))
      card.task.title,
  ];

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
    expect(
      tester.getTopLeft(card("Pack")).dy,
      greaterThan(tester.getTopLeft(card("Flights")).dy),
    );
    // A task says how far along its subtasks are.
    expect(find.text("3 subtasks"), findsOneWidget);
    expect(find.text("1 subtask"), findsNWidgets(2));
    await page.close(tester);
  });

  for (final view in TasksView.values) {
    testWidgets("the ${view.name} shows the tasks as of their clock, not the "
        "phone's", (tester) async {
      await page.open(
        tester,
        [
          TodoItem(
            uuid: "w",
            title: "Water the plants",
            day: DateTime(2026, 5, 14),
            time: const ClockTime(9, 0),
          ),
        ],
        view: view,
        clock: () => DateTime(2026, 5, 13, 12),
      );
      expect(find.text("Tomorrow, 9:00 AM"), findsOneWidget);
      await page.close(tester);
    });
  }

  testWidgets("a tap on a task's subtasks folds them away, and back", (
    tester,
  ) async {
    await page.open(tester, plans());
    await tester.tap(find.text("3 subtasks"));
    await page.wait(tester);
    expect(find.text("Book"), findsNothing);
    expect(find.text("Flights"), findsNothing);
    expect(find.text("Pack"), findsNothing);
    expect(find.text("Milk"), findsOneWidget);
    expect(page.rows.rows.first.folded, isTrue);
    // Shop's card has come up under Trip's.
    expect(
      tester.getTopLeft(card("Shop")).dy,
      lessThan(tester.getBottomLeft(card("Trip")).dy + 20),
    );

    await tester.tap(find.text("3 subtasks"));
    await page.wait(tester);
    expect(find.text("Flights"), findsOneWidget);
    expect(page.rows.rows.first.folded, isFalse);
    await page.close(tester);
  });

  testWidgets("a swipe to the right adds a subtask to the task", (
    tester,
  ) async {
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

  testWidgets("a swipe to the left deletes a task with its subtasks, "
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

  testWidgets("checking a task off checks its subtasks off, until Undo", (
    tester,
  ) async {
    await page.open(tester, plans());
    await tester.tap(find.text("Trip"));
    await page.wait(tester);
    expect(find.text("Task Done, with its 3 subtasks"), findsOneWidget);
    expect(page.task("Flights").done, isTrue);
    expect(page.task("Milk").done, isFalse);
    expect(find.text("3 of 3 subtasks"), findsOneWidget);

    await tester.tap(find.text("Undo"));
    await page.wait(tester);
    expect(page.task("Trip").done, isFalse);
    expect(page.task("Flights").done, isFalse);
    await page.close(tester);
  });

  testWidgets("a dragged task takes its subtasks along, and lines up with "
      "the task under it", (tester) async {
    await page.open(tester, plans());
    // Shop, picked up and carried to just above Pack.
    final up =
        tester.getTopLeft(card("Pack")).dy -
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
      tester.getTopLeft(card("Shop")).dx,
      tester.getTopLeft(card("Pack")).dx,
    );
    expect(tester.takeException(), isNull);
    await page.close(tester);
  });

  testWidgets("tasks that can't be read in are said to be, rather than "
      "thrown", (tester) async {
    await page.open(tester, plans(), unreadable: true);
    expect(find.text("Couldn't read your tasks"), findsOneWidget);
    expect(tester.takeException(), isNull);
    await page.close(tester);
  });

  testWidgets("a task added while the list is open makes room for itself", (
    tester,
  ) async {
    await page.open(tester, plans());
    final packTop = tester.getTopLeft(card("Pack")).dy;
    // A subtask of Book, between Flights and Pack.
    await page.tasks.save(
      page.tasks.subtaskDraft(page.task("Book"))..setTitle("Visa"),
    );
    await tester.pump();
    // Its row starts with no room, and opens up.
    expect(tester.getTopLeft(card("Pack")).dy, closeTo(packTop, 2));
    await page.wait(tester);
    expect(tester.getTopLeft(card("Pack")).dy, greaterThan(packTop + 40));
    expect(find.text("Visa"), findsOneWidget);
    await page.close(tester);
  });

  testWidgets("a drag that can't be saved says so, and the tasks go back", (
    tester,
  ) async {
    await page.open(tester, plans());
    final before = page.outline;
    page.rows.failWrites = true;
    final up =
        tester.getTopLeft(card("Pack")).dy -
        tester.getTopLeft(card("Shop")).dy -
        10;
    await dragCard(tester, "Shop", Offset(0, up));
    expect(find.text("Couldn't move the task"), findsOneWidget);
    expect(page.outline, before);
    await page.close(tester);
  });

  testWidgets("a task picked up and put back keeps its subtasks on show", (
    tester,
  ) async {
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

  testWidgets("the form moves a task into the task picked for it", (
    tester,
  ) async {
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
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text("Milk")),
      findsOneWidget,
    );
    await tester.tap(find.text("Shop").last);
    await page.wait(tester);
    await tester.tap(find.text("Save"));
    await page.wait(tester);
    expect(page.outline, endsWith("Shop\n  Milk\n  Pack"));
    await page.close(tester);
  });

  testWidgets("the menu shows the tasks as a map, and as a list again", (
    tester,
  ) async {
    await page.open(tester, plans());
    expect(find.byType(MapHub), findsNothing);
    await page.choose(tester, "Show as Map");
    await page.wait(tester, const Duration(seconds: 2));
    expect(find.byType(MapHub), findsOneWidget);
    expect(find.byType(TaskCard), findsNothing);
    expect(find.text("Flights"), findsOneWidget);
    // For now: the page still opens with the view the settings pick.
    expect(page.user.user.tasksView, TasksView.list);

    await page.choose(tester, "Show as List");
    await page.wait(tester, const Duration(seconds: 2));
    expect(find.byType(MapHub), findsNothing);
    expect(find.byType(TaskCard), findsNWidgets(6));
    expect(page.user.user.tasksView, TasksView.list);
    await page.close(tester);
  });

  testWidgets("the settings' view takes over from the menu's", (tester) async {
    await page.open(tester, plans(), view: TasksView.map);
    await page.choose(tester, "Show as List");
    await page.wait(tester, const Duration(seconds: 2));
    expect(find.byType(TaskCard), findsNWidgets(6));
    expect(page.user.user.tasksView, TasksView.map);

    // As the settings, over the page, set it.
    await page.user.setTasksView(TasksView.list);
    await page.user.setTasksView(TasksView.map);
    await page.wait(tester, const Duration(seconds: 2));
    expect(find.byType(MapHub), findsOneWidget);
    expect(find.byType(TaskCard), findsNothing);
    await page.close(tester);
  });

  testWidgets("turned on its side, the list stays one column, clear of the "
      "camera", (tester) async {
    // The camera's cutout down the left side, as the phone is turned.
    tester.view.padding = const FakeViewPadding(left: 45 * 2);
    await page.open(tester, plans(), size: const Size(640, 360));
    final summary = tester.getRect(find.byType(TasksSummaryCard));
    final trip = tester.getRect(card("Trip"));
    // The cards come under the summary, as wide as it, not beside it.
    expect(trip.top - summary.bottom, closeTo(20, 0.5));
    expect(trip.left, summary.left);
    expect(trip.right, summary.right);
    expect(trip.left, 16 + 45);
    expect(trip.right, 640 - 16);
    await page.close(tester);
  });

  group("sort and filter", () {
    /// Tasks for days in January 2030, so none is overdue.
    TodoItem due(String title, int? day) => TodoItem(
      uuid: title,
      title: title,
      day: day == null ? null : DateTime(2030, 1, day),
    );

    testWidgets(
      "sit in the bottom left corner, across from the page's buttons",
      (tester) async {
        await page.open(tester, plans());
        final sort = tester.getRect(find.byTooltip("Sort"));
        final filter = tester.getRect(find.byTooltip("Filter"));
        final add = tester.getRect(find.byTooltip("Add Task"));
        expect(sort.left, 16);
        expect(sort.right, lessThanOrEqualTo(filter.left));
        // On the same line as the add button.
        expect(filter.bottom, closeTo(add.bottom, 0.5));
        // Under the title, the summary, then straight to the first card, with
        // no filter bar between them.
        expect(
          tester.getTopLeft(card("Trip")).dy -
              tester.getBottomLeft(find.byType(TasksSummaryCard)).dy,
          closeTo(20, 0.5),
        );
        await page.close(tester);
      },
    );

    testWidgets("the filter shows only the tasks picked, with their counts", (
      tester,
    ) async {
      await page.open(tester, [
        ...plans(),
        TodoItem(
          uuid: "stretch",
          title: "Stretch",
          time: const ClockTime(7, 0),
          reminder: Reminder.daily,
        ),
      ]);
      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
      await tester.tap(find.byTooltip("Filter"));
      await page.wait(tester);
      expect(find.text("SHOW"), findsOneWidget);
      int countOf(String label) => int.parse(
        tester
            .widget<Text>(
              find.descendant(
                of: find.ancestor(
                  of: page.choice(label),
                  matching: find.byType(GlassPopoverOption),
                ),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Text && int.tryParse(widget.data ?? "") != null,
                ),
              ),
            )
            .data!,
      );
      expect(
        {
          for (final label in [
            "All",
            "Done",
            "Undone",
            "Daily",
            "Weekly",
            "Monthly",
            "Once",
          ])
            label: countOf(label),
        },
        {
          "All": 7,
          "Done": 0,
          "Undone": 7,
          "Daily": 1,
          "Weekly": 0,
          "Monthly": 0,
          "Once": 6,
        },
      );

      await tester.tap(page.choice("Daily"));
      await page.wait(tester);
      expect(find.text("SHOW"), findsNothing);
      expect(page.cards(tester), ["Stretch"]);
      expect(page.tasks.filter, TaskFilter.daily);
      // For the next time the app opens, too.
      expect(page.rows.listing?.filter, TaskFilter.daily);
      // The button says a filter is on.
      expect(find.byIcon(Icons.filter_alt_rounded), findsOneWidget);

      await page.pick(tester, "Filter", "Weekly");
      expect(find.text("No Weekly Tasks"), findsOneWidget);
      expect(find.byType(TaskCard), findsNothing);

      await page.pick(tester, "Filter", "All");
      expect(page.cards(tester), hasLength(7));
      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
      await page.close(tester);
    });

    testWidgets("the sort puts the tasks by due date, either way, and back", (
      tester,
    ) async {
      await page.open(tester, [
        due("Later", 20),
        due("Sooner", 10),
        due("Someday", null),
        due("Soonest", 5),
      ]);
      const custom = ["Later", "Sooner", "Someday", "Soonest"];
      expect(page.cards(tester), custom);
      await page.pick(tester, "Sort", "Due Date");
      expect(page.cards(tester), ["Soonest", "Sooner", "Later", "Someday"]);
      expect(page.tasks.sort, TaskSort.dueDate);

      // Which way, once it's by due date.
      await page.pick(tester, "Sort", "Latest First");
      expect(page.cards(tester), ["Later", "Sooner", "Soonest", "Someday"]);
      expect(page.tasks.sortDirection, SortDirection.descending);
      expect(
        page.rows.listing,
        const TaskListing(
          sort: TaskSort.dueDate,
          direction: SortDirection.descending,
        ),
      );

      await page.pick(tester, "Sort", "Custom");
      expect(page.cards(tester), custom);
      await tester.tap(find.byTooltip("Sort"));
      await page.wait(tester);
      expect(page.choice("Due Date"), findsOneWidget);
      expect(page.choice("Latest First"), findsNothing);
      await page.close(tester);
    });

    testWidgets("sorted by due date, a card held says how to move it instead", (
      tester,
    ) async {
      await page.open(tester, plans());
      await page.pick(tester, "Sort", "Due Date");
      final gesture = await tester.startGesture(handle(tester, "Shop"));
      await page.wait(tester, const Duration(milliseconds: 700));
      for (var step = 0; step < 8; step++) {
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await page.wait(tester);
      expect(
        find.text("To move tasks by hand, sort them by Custom"),
        findsOneWidget,
      );
      expect(page.outline, startsWith("Trip\n  Book\n    Flights\n  Pack"));
      // Holding a title still edits its task.
      await tester.longPress(find.text("Pack"));
      await page.wait(tester);
      expect(find.text("Edit Task"), findsOneWidget);
      await tester.tap(find.text("Cancel"));
      await page.close(tester);
    });

    testWidgets(
      "a panel closes on a touch anywhere else, which does nothing else, "
      "and on Back",
      (tester) async {
        await page.open(tester, plans());
        await tester.tap(find.byTooltip("Filter"));
        await page.wait(tester);
        expect(find.text("SHOW"), findsOneWidget);
        await tester.tapAt(tester.getCenter(find.text("Milk")));
        await page.wait(tester);
        expect(find.text("SHOW"), findsNothing);
        expect(page.task("Milk").done, isFalse);

        await tester.tap(find.byTooltip("Sort"));
        await page.wait(tester);
        expect(find.text("SORT BY"), findsOneWidget);
        expect(await tester.binding.handlePopRoute(), isTrue);
        await page.wait(tester);
        expect(find.text("SORT BY"), findsNothing);
        expect(find.byType(TodoPage), findsOneWidget);
        await page.close(tester);
      },
    );

    testWidgets("a screen reader gets to the panel on the map as well", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await page.open(tester, plans());
      await page.choose(tester, "Show as Map");
      await page.wait(tester, const Duration(seconds: 2));
      await tester.tap(find.byTooltip("Filter"));
      await page.wait(tester);
      // As a screen reader goes through the page, which leaves out what
      // isn't in its order.
      final read = [
        for (final node in tester.semantics.simulatedAccessibilityTraversal())
          node.label,
      ];
      expect(read, contains("SHOW"));
      // Only the panel says it: the filter's on All.
      expect(read.where((label) => label.startsWith("Undone")), hasLength(1));
      await page.close(tester);
      semantics.dispose();
    });

    testWidgets("open as they were left, which the database keeps", (
      tester,
    ) async {
      await page.open(
        tester,
        [
          due("Later", 20),
          due("Done early", 3).copyWith(done: true),
          due("Sooner", 10),
        ],
        listing: const TaskListing(
          filter: TaskFilter.undone,
          sort: TaskSort.dueDate,
        ),
      );
      expect(page.cards(tester), ["Sooner", "Later"]);
      // Both buttons say they're on.
      expect(find.byIcon(Icons.filter_alt_rounded), findsOneWidget);
      await tester.tap(find.byTooltip("Sort"));
      await page.wait(tester);
      expect(
        tester
            .widget<GlassPopoverOption>(
              find.ancestor(
                of: page.choice("Due Date"),
                matching: find.byType(GlassPopoverOption),
              ),
            )
            .selected,
        isTrue,
      );
      await page.close(tester);
    });

    testWidgets("aren't there without tasks", (tester) async {
      await page.open(tester, const []);
      expect(find.text("No Tasks"), findsOneWidget);
      expect(find.byTooltip("Filter"), findsNothing);
      expect(find.byTooltip("Sort"), findsNothing);
      await page.close(tester);
    });

    testWidgets("stay while a filter is on, so it can be turned off", (
      tester,
    ) async {
      await page.open(tester, [
        TodoItem(uuid: "only", title: "Only", done: true),
      ]);
      await page.pick(tester, "Filter", "Done");
      await tester.drag(find.text("Only"), const Offset(-300, 0));
      await page.wait(tester);
      expect(find.text("No Tasks"), findsOneWidget);
      expect(find.byTooltip("Filter"), findsOneWidget);
      // Once the toast that says it's in the trash, over them, has gone.
      await page.wait(tester, const Duration(seconds: 6));
      await page.pick(tester, "Filter", "All");
      expect(find.byTooltip("Filter"), findsNothing);
      await page.close(tester);
    });
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

  testWidgets("each view's tour ends on the menu, where the other view is", (
    tester,
  ) async {
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
      "Sort and Filter",
      "More Options",
    ]) {
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text("Next"));
      await page.wait(tester);
    }
    expect(find.text("See Them as a Map"), findsOneWidget);
    expect(
      find.textContaining("Open this menu to switch to a map"),
      findsOneWidget,
    );
    await tester.tap(find.text("Done"));
    await page.wait(tester);

    await page.choose(tester, "Show as Map");
    await page.wait(tester, const Duration(seconds: 3));
    for (final title in [
      "Your Tasks as a Map",
      "Work on a Task",
      "Move a Task",
      "See It All",
      "Go Full Screen",
      "Sort and Filter",
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
