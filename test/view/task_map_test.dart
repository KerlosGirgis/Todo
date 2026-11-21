import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/task_map/map_node.dart';
import 'package:todo/view/widgets/large_title.dart';
import 'package:todo/view_model/tour_view_model.dart';

import 'todo_page_test.dart' show TodoPageHarness, plans;

void main() {
  late TodoPageHarness page;

  setUp(() => page = TodoPageHarness());

  /// The box of the task titled [title], as the map draws it.
  Finder node(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(MapNodeCard));

  Rect rectOf(WidgetTester tester, String title) => tester.getRect(node(title));

  /// Picks [title]'s box up, carries it to [to], and drops it there.
  Future<void> dragNode(WidgetTester tester, String title, Offset to) async {
    final from = rectOf(tester, title).center;
    final gesture = await tester.startGesture(from);
    await page.wait(tester, const Duration(milliseconds: 700));
    const steps = 8;
    for (var step = 1; step <= steps; step++) {
      await gesture.moveTo(Offset.lerp(from, to, step / steps)!);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await page.wait(tester);
  }

  testWidgets("each task branches off the task it's in, from the centre out", (
    tester,
  ) async {
    await page.open(tester, plans(), view: TasksView.map);
    final hub = tester.getRect(find.byType(MapHub));
    final trip = rectOf(tester, "Trip");
    final book = rectOf(tester, "Book");
    final flights = rectOf(tester, "Flights");
    final pack = rectOf(tester, "Pack");
    final shop = rectOf(tester, "Shop");
    // On a phone held upright, everything is to the right of the centre.
    expect(trip.left, greaterThan(hub.right));
    expect(book.left, greaterThan(trip.right));
    expect(flights.left, greaterThan(book.right));
    expect(pack.left, book.left);
    expect(shop.left, trip.left);
    // A task's subtasks are stacked beside it, in their order, and it's
    // level with the middle of them.
    expect(pack.top, greaterThan(book.bottom));
    expect(shop.top, greaterThan(pack.bottom));
    expect(trip.center.dy, closeTo((book.top + pack.bottom) / 2, 1));
    // The centre says how far along they all are.
    expect(find.bySemanticsLabel("0 of 6 tasks done"), findsOneWidget);
    expect(tester.takeException(), isNull);
    await page.close(tester);
  });

  testWidgets("on a phone turned on its side, tasks branch off both sides", (
    tester,
  ) async {
    await page.open(
      tester,
      plans(),
      view: TasksView.map,
      size: const Size(915, 412),
    );
    final hub = tester.getRect(find.byType(MapHub));
    expect(rectOf(tester, "Trip").left, greaterThan(hub.right));
    expect(rectOf(tester, "Shop").right, lessThan(hub.left));
    expect(rectOf(tester, "Milk").right, lessThan(rectOf(tester, "Shop").left));
    await page.close(tester);
  });

  testWidgets("a tap on a task's circle checks it off", (tester) async {
    await page.open(tester, plans(), view: TasksView.map);
    await tester.tap(
      find.descendant(
        of: node("Milk"),
        matching: find.bySemanticsLabel("Done"),
      ),
    );
    await page.wait(tester);
    expect(page.task("Milk").done, isTrue);
    // Which finishes the task it's in.
    expect(page.task("Shop").done, isTrue);
    expect(find.text("Task done. That finishes “Shop”"), findsOneWidget);
    expect(find.bySemanticsLabel("2 of 6 tasks done"), findsOneWidget);
    await page.close(tester);
  });

  testWidgets("a tap on a task brings up buttons that act on it", (
    tester,
  ) async {
    await page.open(tester, plans(), view: TasksView.map);
    expect(find.byTooltip("Add Subtask"), findsNothing);
    await tester.tap(find.text("Shop"));
    await page.wait(tester);
    expect(find.byTooltip("Add Subtask"), findsOneWidget);

    await tester.tap(find.byTooltip("Add Subtask"));
    await page.wait(tester);
    expect(find.text("New Subtask"), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, "Eggs");
    await tester.pump();
    await tester.tap(find.text("Add"));
    await page.wait(tester, const Duration(seconds: 2));
    expect(page.outline, endsWith("Shop\n  Milk\n  Eggs"));
    // The new task is on the map, under the last of the others.
    expect(
      rectOf(tester, "Eggs").top,
      greaterThan(rectOf(tester, "Milk").bottom),
    );

    // The buttons are still Shop's, and come up beside it.
    final bar = tester.getRect(find.byTooltip("Mark Done"));
    expect(bar.bottom, lessThan(rectOf(tester, "Shop").top));
    await tester.tap(find.byTooltip("Mark Done"));
    await page.wait(tester);
    expect(page.task("Shop").done, isTrue);
    expect(page.task("Eggs").done, isTrue);
    expect(page.task("Trip").done, isFalse);
    expect(find.byTooltip("Mark Not Done"), findsOneWidget);

    await tester.tap(find.byTooltip("Edit"));
    await page.wait(tester);
    expect(find.text("Edit Task"), findsOneWidget);
    await tester.tap(find.text("Cancel"));
    await page.wait(tester);

    await tester.tap(find.byTooltip("Delete"));
    await page.wait(tester);
    expect(page.outline, "Trip\n  Book\n    Flights\n  Pack");
    expect(node("Shop"), findsNothing);
    expect(find.text("Task and its 2 subtasks moved to Trash"), findsOneWidget);
    // With its task gone, so are the buttons.
    expect(find.byTooltip("Add Subtask"), findsNothing);
    await page.close(tester);
  });

  testWidgets("a tap on the map lets go of the task picked out", (
    tester,
  ) async {
    await page.open(tester, plans(), view: TasksView.map);
    await tester.tap(find.text("Pack"));
    await page.wait(tester);
    expect(find.byTooltip("Delete"), findsOneWidget);
    await tester.tapAt(const Offset(60, 320));
    await page.wait(tester);
    expect(find.byTooltip("Delete"), findsNothing);
    await page.close(tester);
  });

  testWidgets("a task's knob folds its subtasks away into it, and back", (
    tester,
  ) async {
    await page.open(tester, plans(), view: TasksView.map);
    final shop = rectOf(tester, "Shop").top;
    await tester.tap(find.byType(MapKnob).first);
    await page.wait(tester);
    expect(find.text("Book"), findsNothing);
    expect(find.text("Flights"), findsNothing);
    expect(find.bySemanticsLabel("3 subtasks folded away"), findsOneWidget);
    expect(page.rows.rows.first.folded, isTrue);
    // The tasks under it close up.
    expect(rectOf(tester, "Shop").top, lessThan(shop));

    await tester.tap(find.bySemanticsLabel("3 subtasks folded away"));
    await page.wait(tester);
    expect(find.text("Flights"), findsOneWidget);
    expect(rectOf(tester, "Shop").top, closeTo(shop, 1));
    await page.close(tester);
  });

  testWidgets("a task dropped on another goes into it, with its subtasks", (
    tester,
  ) async {
    await page.open(tester, plans(), view: TasksView.map);
    await dragNode(tester, "Book", rectOf(tester, "Shop").center);
    expect(page.outline, """
Trip
  Pack
Shop
  Milk
  Book
    Flights""");
    expect(
      rectOf(tester, "Book").left,
      greaterThan(rectOf(tester, "Shop").right),
    );
    expect(tester.takeException(), isNull);
    await page.close(tester);
  });

  testWidgets("a task dropped just above or below another goes next to it", (
    tester,
  ) async {
    await page.open(tester, plans(), view: TasksView.map);
    final book = rectOf(tester, "Book");
    await dragNode(tester, "Milk", book.topCenter + const Offset(0, 2));
    expect(page.outline, """
Trip
  Milk
  Book
    Flights
  Pack
Shop""");
    final pack = rectOf(tester, "Pack");
    await dragNode(tester, "Milk", pack.bottomCenter - const Offset(0, 2));
    expect(page.outline, """
Trip
  Book
    Flights
  Pack
  Milk
Shop""");
    await page.close(tester);
  });

  testWidgets("a task dropped on the centre is a task of its own", (
    tester,
  ) async {
    await page.open(tester, plans(), view: TasksView.map);
    await dragNode(tester, "Book", tester.getCenter(find.byType(MapHub)));
    expect(page.outline, "Trip\n  Pack\nShop\n  Milk\nBook\n  Flights");
    expect(page.task("Book").parent, isNull);
    await page.close(tester);
  });

  testWidgets("a task dropped on nothing, or on its own subtask, stays put", (
    tester,
  ) async {
    await page.open(tester, plans(), view: TasksView.map);
    const before = "Trip\n  Book\n    Flights\n  Pack\nShop\n  Milk";
    await dragNode(tester, "Book", const Offset(60, 320));
    expect(page.outline, before);
    await dragNode(tester, "Trip", rectOf(tester, "Flights").center);
    expect(page.outline, before);
    expect(tester.takeException(), isNull);
    await page.close(tester);
  });

  testWidgets(
    "the bar over the map is one row, and in the corner the map's buttons "
    "sit side by side over the sort and filter",
    (tester) async {
      await page.open(tester, plans(), view: TasksView.map);
      expect(tester.getSize(find.byType(TitleBar)).height, TitleBar.height);
      // The map starts under it.
      expect(rectOf(tester, "Trip").top, greaterThan(TitleBar.height));
      final full = tester.getRect(find.byTooltip("Full Screen"));
      final fit = tester.getRect(find.byTooltip("Show Whole Map"));
      final sort = tester.getRect(find.byTooltip("Sort"));
      // In a row, full screen first, lined up with the sort and filter.
      expect(full.center.dy, fit.center.dy);
      expect(full.left, sort.left);
      // As far apart side by side as from the sort and filter under them.
      expect(fit.left - full.right, closeTo(sort.top - fit.bottom, 0.5));
      expect(
        tester.getRect(find.byTooltip("Filter")).bottom,
        closeTo(tester.getRect(find.byTooltip("Add Task")).bottom, 0.5),
      );
      await page.close(tester);
    },
  );

  testWidgets("the filter picks which tasks the map shows", (tester) async {
    await page.open(tester, plans(), view: TasksView.map);
    await tester.tap(
      find.descendant(
        of: node("Book"),
        matching: find.bySemanticsLabel("Done"),
      ),
    );
    // Once the toast that offers to undo it, over the buttons, has gone.
    await page.wait(tester, const Duration(seconds: 6));
    await page.pick(tester, "Filter", "Undone");
    await page.wait(tester);
    expect(find.text("Book"), findsNothing);
    expect(find.text("Flights"), findsNothing);
    expect(find.text("Pack"), findsOneWidget);
    await page.pick(tester, "Filter", "Done");
    await page.wait(tester);
    expect(find.text("Flights"), findsOneWidget);
    expect(find.text("Pack"), findsNothing);
    await page.pick(tester, "Filter", "Once");
    await page.wait(tester);
    expect(find.byType(MapNodeCard), findsNWidgets(6));
    await page.pick(tester, "Filter", "Monthly");
    expect(find.text("No Monthly Tasks"), findsOneWidget);
    expect(find.byType(MapHub), findsNothing);
    expect(tester.takeException(), isNull);
    await page.close(tester);
  });

  testWidgets("the sort puts each task's subtasks by due date on the map", (
    tester,
  ) async {
    TodoItem due(String uuid, int day, [String? parent]) => TodoItem(
      uuid: uuid,
      title: uuid,
      parent: parent,
      day: DateTime(2030, 1, day),
    );
    await page.open(tester, [
      due("Trip", 9),
      due("Pack", 8, "Trip"),
      due("Book", 2, "Trip"),
      due("Shop", 3),
    ], view: TasksView.map);
    expect(rectOf(tester, "Pack").top, lessThan(rectOf(tester, "Book").top));
    await page.pick(tester, "Sort", "Due Date");
    await page.wait(tester);
    expect(rectOf(tester, "Book").top, lessThan(rectOf(tester, "Pack").top));
    expect(rectOf(tester, "Shop").top, lessThan(rectOf(tester, "Trip").top));
    await page.close(tester);
  });

  testWidgets("sorted by due date, a task dropped on the edge of another goes "
      "into it, as its date says where", (tester) async {
    await page.open(tester, plans(), view: TasksView.map);
    await page.pick(tester, "Sort", "Due Date");
    await page.wait(tester);
    final book = rectOf(tester, "Book");
    await dragNode(tester, "Milk", book.topCenter + const Offset(0, 2));
    expect(page.outline, """
Trip
  Book
    Flights
    Milk
  Pack
Shop""");
    await page.close(tester);
  });

  testWidgets("with no tasks, the map says so, as the list does", (
    tester,
  ) async {
    await page.open(tester, const [], view: TasksView.map);
    expect(find.text("No Tasks"), findsOneWidget);
    expect(find.byType(MapHub), findsNothing);
    await page.close(tester);
  });

  group("full screen", () {
    /// What the page asks of the phone from now on, such as to hide its
    /// bars, as "method argument", in order.
    List<String> phoneCalls(WidgetTester tester) {
      final calls = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add("${call.method} ${call.arguments}");
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      return calls;
    }

    /// The modes the page has put the phone's bars in, in order.
    List<String> barModes(List<String> calls) => [
      for (final call in calls)
        if (call.startsWith("SystemChrome.setEnabledSystemUIMode "))
          call.split(" ").last,
    ];

    /// What's on the page's bar and in its corner, which the map covers in
    /// full screen.
    final aroundTheMap = {
      "the title": find.text("ToDo"),
      "the menu": find.byTooltip("Menu"),
      "the switch to the notes": find.byTooltip("Notes"),
      "the add button": find.byTooltip("Add Task"),
    };

    testWidgets("gives the map the whole screen, then the page its bar back", (
      tester,
    ) async {
      await page.open(tester, plans(), view: TasksView.map);
      final calls = phoneCalls(tester);
      final trip = rectOf(tester, "Trip");
      expect(find.byTooltip("Exit Full Screen"), findsNothing);

      await tester.tap(find.byTooltip("Full Screen"));
      await page.wait(tester);
      aroundTheMap.forEach(
        (what, finder) =>
            expect(finder.hitTestable(), findsNothing, reason: what),
      );
      expect(barModes(calls), ["SystemUiMode.immersiveSticky"]);
      // The map stays where it was on the screen, and works as before.
      expect(rectOf(tester, "Trip"), trip);
      expect(find.byTooltip("Show Whole Map").hitTestable(), findsOneWidget);
      // So do the sort and filter, under it.
      expect(find.byTooltip("Filter").hitTestable(), findsOneWidget);
      await tester.tap(find.text("Pack"));
      await page.wait(tester);
      expect(find.byTooltip("Add Subtask"), findsOneWidget);

      await tester.tap(find.byTooltip("Exit Full Screen"));
      await page.wait(tester);
      aroundTheMap.forEach(
        (what, finder) =>
            expect(finder.hitTestable(), findsOneWidget, reason: what),
      );
      expect(barModes(calls), [
        "SystemUiMode.immersiveSticky",
        "SystemUiMode.edgeToEdge",
      ]);
      expect(rectOf(tester, "Trip"), trip);
      expect(find.byTooltip("Full Screen"), findsOneWidget);
      await page.close(tester);
    });

    testWidgets("Back leaves full screen, and only then the app", (
      tester,
    ) async {
      await page.open(tester, plans(), view: TasksView.map);
      final calls = phoneCalls(tester);
      await tester.tap(find.byTooltip("Full Screen"));
      await page.wait(tester);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await page.wait(tester);
      expect(find.byTooltip("Menu").hitTestable(), findsOneWidget);
      expect(find.byType(MapHub), findsOneWidget);
      expect(barModes(calls).last, "SystemUiMode.edgeToEdge");
      expect(
        calls.where((call) => call.startsWith("SystemNavigator.pop")),
        isEmpty,
      );

      await tester.binding.handlePopRoute();
      expect(
        calls.where((call) => call.startsWith("SystemNavigator.pop")),
        hasLength(1),
      );
      await page.close(tester);
    });

    testWidgets("the page gets its bar back once the map has nothing on it", (
      tester,
    ) async {
      await page.open(tester, [
        TodoItem(uuid: "milk", title: "Milk"),
      ], view: TasksView.map);
      final calls = phoneCalls(tester);
      await tester.tap(find.byTooltip("Full Screen"));
      await page.wait(tester);
      await tester.tap(find.text("Milk"));
      await page.wait(tester);
      await tester.tap(find.byTooltip("Delete"));
      await page.wait(tester);
      expect(find.text("No Tasks"), findsOneWidget);
      expect(find.byTooltip("Menu").hitTestable(), findsOneWidget);
      expect(barModes(calls).last, "SystemUiMode.edgeToEdge");
      // Once the toast that says it's in the trash is out of the way.
      await page.wait(tester, const Duration(seconds: 6));
      expect(find.byTooltip("Add Task").hitTestable(), findsOneWidget);
      await page.close(tester);
    });

    testWidgets("the map's tour waits until the page has its bar back", (
      tester,
    ) async {
      await page.open(tester, plans(), due: {PageTour.map});
      await page.choose(tester, "Show as Map");
      // Before the tour starts.
      await page.wait(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip("Full Screen"));
      await page.wait(tester, const Duration(seconds: 3));
      expect(find.text("Your Tasks as a Map"), findsNothing);

      await tester.tap(find.byTooltip("Exit Full Screen"));
      await page.wait(tester, const Duration(seconds: 2));
      expect(find.text("Your Tasks as a Map"), findsOneWidget);
      await tester.tap(find.text("Skip"));
      await page.wait(tester);
      await page.close(tester);
    });
  });
}
