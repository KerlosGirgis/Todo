import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/task_tree.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/trashed.dart';

/// A task named for its uuid, in the task with the uuid [parent].
TodoItem task(String uuid,
        {String? parent,
        bool done = false,
        bool daily = false,
        bool folded = false,
        int? id}) =>
    TodoItem(
      id: id,
      uuid: uuid,
      title: uuid,
      parent: parent,
      done: done,
      folded: folded,
      time: daily ? const ClockTime(7, 0) : null,
      reminder: daily ? Reminder.daily : Reminder.none,
    );

/// The tree as an outline: each task's uuid, two spaces in for each task
/// it's inside of.
String outline(TaskTree tree) => [
      for (final node in tree.nodes) "${"  " * node.depth}${node.task.uuid}",
    ].join("\n");

void main() {
  /// A trip to plan, with shopping to do on the side:
  ///
  ///     trip
  ///       book
  ///         flights
  ///         hotel
  ///       pack
  ///     shop
  ///       milk
  List<TodoItem> plans() => [
        task("trip"),
        task("book", parent: "trip"),
        task("flights", parent: "book"),
        task("hotel", parent: "book"),
        task("pack", parent: "trip"),
        task("shop"),
        task("milk", parent: "shop"),
      ];

  group('TaskTree', () {
    test('puts each task in the task its parent names', () {
      final tree = TaskTree(plans());
      expect(outline(tree), """
trip
  book
    flights
    hotel
  pack
shop
  milk""");
      expect(tree.roots.map((node) => node.task.uuid), ["trip", "shop"]);
      final book = tree["book"]!;
      expect(book.parent!.task.uuid, "trip");
      expect(book.depth, 1);
      expect(book.children.map((node) => node.task.uuid), ["flights", "hotel"]);
      expect(tree["hotel"]!.ancestors.map((node) => node.task.uuid),
          ["book", "trip"]);
      expect(tree["trip"]!.descendants.map((node) => node.task.uuid),
          ["book", "flights", "hotel", "pack"]);
    });

    test('lists subtasks in their order, wherever their task is listed', () {
      final tree = TaskTree([
        task("b", parent: "list"),
        task("other"),
        task("a", parent: "list"),
        task("list"),
      ]);
      expect(outline(tree), "other\nlist\n  b\n  a");
    });

    test("a task whose parent isn't there is a task of its own", () {
      final tree =
          TaskTree([task("a", parent: "gone"), task("b", parent: "a")]);
      expect(outline(tree), "a\n  b");
      expect(tree["a"]!.task.parent, "gone");
    });

    test('a task is never inside itself, however the parents go round', () {
      expect(outline(TaskTree([task("a", parent: "a")])), "a");
      final ring = TaskTree([
        task("a", parent: "c"),
        task("b", parent: "a"),
        task("c", parent: "b"),
      ]);
      expect(ring.nodes, hasLength(3));
      expect(ring.roots, hasLength(1));
      expect(outline(ring), "c\n  a\n    b");
    });

    test('tells tasks that share a uuid apart, the first holding the subtasks',
        () {
      final tree = TaskTree([
        task("same", id: 1),
        task("same", id: 2),
        task("sub", parent: "same"),
      ]);
      expect(tree.nodes.map((node) => node.key), ["same", "sub", "same#1"]);
      expect(tree.nodeOf(task("same", id: 2))!.key, "same#1");
      expect(tree.nodeOf(task("same", id: 1))!.children, hasLength(1));
      expect(tree.nodeOf(task("nowhere")), isNull);
    });

    test('counts the tasks in a task, and the done ones, however deep', () {
      final tree = TaskTree([
        for (final each in plans())
          each.uuid == "flights" || each.uuid == "pack"
              ? each.copyWith(done: true)
              : each,
      ]);
      expect(tree["trip"]!.subtaskCount, 4);
      expect(tree["trip"]!.doneSubtaskCount, 2);
      expect(tree["book"]!.subtaskCount, 2);
      expect(tree["book"]!.doneSubtaskCount, 1);
      expect(tree["milk"]!.subtaskCount, 0);
    });

    test('a branch is a task with every task in it, in order', () {
      final branch = TaskTree(plans())["trip"]!.branch;
      expect(branch.task.uuid, "trip");
      expect(branch.subtasks.map((each) => each.uuid),
          ["book", "flights", "hotel", "pack"]);
      expect(branch.all, hasLength(5));
    });
  });

  group('a filtered tree', () {
    test('keeps a task in the nearest task above it that got through', () {
      final tree = TaskTree([
        task("trip"),
        task("book", parent: "trip", done: true),
        task("flights", parent: "book"),
        task("hotel", parent: "book", done: true),
        task("pack", parent: "trip"),
      ]);
      final undone = tree.where((each) => !each.done);
      expect(outline(undone), "trip\n  flights\n  pack");
      final done = tree.where((each) => each.done);
      expect(outline(done), "book\n  hotel");
      expect(done["hotel"]!.parent!.task.uuid, "book");
      expect(done["book"]!.parent, isNull);
    });

    test('still counts every task in a task, shown or not', () {
      final tree = TaskTree([
        task("trip"),
        task("book", parent: "trip", done: true),
        task("pack", parent: "trip"),
      ]);
      final undone = tree.where((each) => !each.done);
      expect(undone["trip"]!.children, hasLength(1));
      expect(undone["trip"]!.subtaskCount, 2);
      expect(undone["trip"]!.doneSubtaskCount, 1);
    });
  });

  group('marking a task done', () {
    List<String> marking(List<TodoItem> tasks, String uuid,
        {required bool done}) {
      final tree = TaskTree(tasks);
      return [
        for (final node in tree.marking(tree[uuid]!, done: done))
          node.task.uuid,
      ];
    }

    test('marks every task in it done, it first', () {
      expect(
          marking(plans(), "book", done: true), ["book", "flights", "hotel"]);
      expect(marking(plans(), "milk", done: true), ["milk", "shop"]);
    });

    test('leaves out the ones done already', () {
      final tasks = [
        task("trip"),
        task("book", parent: "trip", done: true),
        task("pack", parent: "trip"),
      ];
      expect(marking(tasks, "trip", done: true), ["trip", "pack"]);
    });

    test('finishes the task it is in once nothing is left to do there', () {
      final tasks = [
        task("trip"),
        task("book", parent: "trip"),
        task("flights", parent: "book", done: true),
        task("hotel", parent: "book"),
        task("pack", parent: "trip", done: true),
      ];
      // The last of its subtasks finishes "book", which finishes "trip".
      expect(marking(tasks, "hotel", done: true), ["hotel", "book", "trip"]);
    });

    test('leaves the task it is in alone while a subtask is still to do', () {
      expect(marking(plans(), "flights", done: true), ["flights"]);
    });

    test('not done again leaves the tasks it is in to do, not the ones in it',
        () {
      final tasks = [for (final each in plans()) each.copyWith(done: true)];
      expect(marking(tasks, "book", done: false), ["book", "trip"]);
      expect(marking(tasks, "trip", done: false), ["trip"]);
    });

    test('a daily task in one that is not leaves that one alone', () {
      final tasks = [
        task("trip", done: true),
        task("stretch", parent: "trip", daily: true, done: true),
      ];
      expect(marking(tasks, "stretch", done: false), ["stretch"]);
      final undone = [
        task("trip"),
        task("stretch", parent: "trip", daily: true)
      ];
      expect(marking(undone, "stretch", done: true), ["stretch"]);
      // The other way round, it counts: the day's routine is done with it.
      final routine = [
        task("routine", daily: true),
        task("water", parent: "routine"),
      ];
      expect(marking(routine, "water", done: true), ["water", "routine"]);
    });

    test('a task is not finished by daily tasks alone getting done', () {
      final tasks = [
        task("trip"),
        task("stretch", parent: "trip", daily: true),
        task("pack", parent: "trip"),
      ];
      expect(marking(tasks, "pack", done: true), ["pack", "trip"]);
    });
  });

  group('doneAheadOfSubtasks', () {
    List<String> ahead(List<TodoItem> tasks) => [
          for (final node in TaskTree(tasks).doneAheadOfSubtasks)
            node.task.uuid,
        ];

    test('finds the done tasks with a task in them still to do', () {
      expect(
          ahead([
            task("trip", done: true),
            task("book", parent: "trip", done: true),
            task("hotel", parent: "book"),
            task("shop", done: true),
            task("milk", parent: "shop", done: true),
          ]),
          ["book", "trip"]);
      expect(ahead(plans()), isEmpty);
    });

    test('lets a daily task be to do in a done task that is not daily', () {
      expect(
          ahead([
            task("trip", done: true),
            task("stretch", parent: "trip", daily: true),
          ]),
          isEmpty);
    });
  });

  group('moving a task', () {
    String? moved(String uuid, {String? into, String? before}) {
      final tree = TaskTree(plans());
      final tasks = tree.moving(tree[uuid]!,
          parent: into == null ? null : tree[into],
          before: before == null ? null : tree[before]);
      return tasks == null ? null : outline(TaskTree(tasks));
    }

    test('into another takes the tasks in it along, to the end', () {
      expect(moved("book", into: "shop"), """
trip
  pack
shop
  milk
  book
    flights
    hotel""");
    });

    test('ahead of a task puts it right there', () {
      expect(moved("pack", into: "book", before: "hotel"), """
trip
  book
    flights
    pack
    hotel
shop
  milk""");
      expect(moved("shop", before: "trip"), """
shop
  milk
trip
  book
    flights
    hotel
  pack""");
    });

    test('out of every task makes it a task of its own', () {
      final tree = TaskTree(plans());
      final tasks = tree.moving(tree["hotel"]!, parent: null)!;
      expect(tasks.last.uuid, "hotel");
      expect(tasks.last.parent, isNull);
      expect(TaskTree(tasks).roots.map((node) => node.task.uuid),
          ["trip", "shop", "hotel"]);
    });

    test('to where it already is changes nothing', () {
      expect(moved("pack", into: "trip"), isNull);
      expect(moved("book", into: "trip", before: "pack"), isNull);
      expect(moved("shop"), isNull);
      expect(moved("trip", before: "shop"), isNull);
    });
  });

  group('TaskBranch', () {
    test('is kept in the trash with the tasks in it, each with its id', () {
      final branch = TaskBranch(task("trip", id: 3), [
        task("book", parent: "trip", id: 4),
        task("hotel", parent: "book", id: 6, done: true),
      ]);
      final row = Trashed.toRow(
          kind: TrashKind.task,
          itemId: branch.task.id,
          item: branch.toMap(),
          deletedAt: DateTime(2026, 5, 13));
      final entry = Trashed.fromRow({...row, 'id': 1}, TaskBranch.fromMap)!;
      expect(entry.item.task.id, 3);
      expect(entry.item.task.toMap(), branch.task.toMap());
      expect(entry.item.subtasks.map((each) => each.id), [4, 6]);
      expect(entry.item.subtasks.map((each) => each.parent), ["trip", "book"]);
      expect(entry.item.subtasks.last.done, isTrue);
    });

    test('reads a task deleted before tasks had subtasks', () {
      final item = jsonEncode(task("call").toMap()..remove('parent'));
      final entry = Trashed.fromRow({
        'id': 1,
        'kind': "task",
        'itemId': 9,
        'item': item,
        'deletedAt': "2026-05-13T21:30:00.000",
      }, TaskBranch.fromMap)!;
      expect(entry.item.task.id, 9);
      expect(entry.item.task.parent, isNull);
      expect(entry.item.subtasks, isEmpty);
      // A task on its own is kept just as it always was.
      expect(TaskBranch(task("call")).toMap(), task("call").toMap());
    });
  });
}
