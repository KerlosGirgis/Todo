import 'dart:collection';

import 'todo_item.dart';

/// A task with every task in it: its subtasks, theirs, and so on. They're
/// deleted together, wait in the trash together, and come back together.
class TaskBranch {
  const TaskBranch(this.task, [this.subtasks = const []]);

  final TodoItem task;

  /// The tasks in [task], however deep, each ahead of its own subtasks, in
  /// the order the list has them.
  final List<TodoItem> subtasks;

  /// The task, then the tasks in it.
  List<TodoItem> get all => [task, ...subtasks];

  /// A branch as the trash keeps it: its task as backups keep one, with the
  /// tasks in it listed beside it, each with the id it had. One from before
  /// tasks had subtasks is the task alone.
  factory TaskBranch.fromMap(Map<String, dynamic> map) {
    final subtasks = map['subtasks'];
    return TaskBranch(TodoItem.fromMap(map), [
      if (subtasks is List)
        for (final subtask in subtasks)
          if (subtask is Map<String, dynamic>) TodoItem.fromMap(subtask),
    ]);
  }

  Map<String, Object?> toMap() => {
        ...task.toMap(),
        if (subtasks.isNotEmpty)
          'subtasks': [
            for (final subtask in subtasks)
              {...subtask.toMap(), 'id': subtask.id},
          ],
      };
}

/// A task where it stands among the others: in the task it's a subtask of,
/// with its own subtasks in it.
class TaskNode {
  TaskNode._(this.task, this.key);

  final TodoItem task;

  /// Tells the task apart from every other in its tree: its uuid, with a
  /// count after it should tasks share one.
  final String key;

  TaskNode? _parent;
  final _children = <TaskNode>[];
  int _depth = 0;
  int _subtasks = 0;
  int _subtasksDone = 0;

  /// The task this one is a subtask of, or null for a task of its own.
  TaskNode? get parent => _parent;

  /// Its subtasks, in the order the list has them.
  late final List<TaskNode> children = UnmodifiableListView(_children);

  /// How many tasks it's inside of: none for a task of its own.
  int get depth => _depth;

  /// How many tasks are in it, however deep, and how many of those are
  /// done: all of them, whichever of them a filter lets through.
  int get subtaskCount => _subtasks;
  int get doneSubtaskCount => _subtasksDone;

  /// Every task in it, however deep, each ahead of its own subtasks.
  Iterable<TaskNode> get descendants sync* {
    for (final child in _children) {
      yield child;
      yield* child.descendants;
    }
  }

  /// The tasks it's inside of, the nearest first.
  Iterable<TaskNode> get ancestors sync* {
    for (var node = _parent; node != null; node = node._parent) {
      yield node;
    }
  }

  /// The task with every task in it.
  TaskBranch get branch =>
      TaskBranch(task, [for (final node in descendants) node.task]);

  /// Whether it's [other], or somewhere inside it.
  bool isOrIsIn(TaskNode other) {
    for (TaskNode? node = this; node != null; node = node._parent) {
      if (identical(node, other)) return true;
    }
    return false;
  }

  /// Whether [parent], the task it's in, is only done once it is. Not when
  /// it's a daily task in one that isn't: it starts over every day, and the
  /// task it's in doesn't.
  bool countsFor(TaskNode parent) => !task.isDaily || parent.task.isDaily;
}

/// The tasks as a tree: each in the task its [TodoItem.parent] names, in the
/// order they're listed in.
class TaskTree {
  TaskTree._(List<TaskNode> roots) : roots = UnmodifiableListView(roots) {
    for (final node in nodes) {
      _byKey[node.key] = node;
      (_byUuid[node.task.uuid] ??= []).add(node);
    }
  }

  /// The tree of [tasks]. A task whose parent isn't among them is a task of
  /// its own, and so is one that would end up inside itself.
  factory TaskTree(Iterable<TodoItem> tasks) {
    final nodes = <TaskNode>[];
    final byUuid = <String, TaskNode>{};
    final shared = <String, int>{};
    for (final task in tasks) {
      final count =
          shared.update(task.uuid, (count) => count + 1, ifAbsent: () => 0);
      final node =
          TaskNode._(task, count == 0 ? task.uuid : "${task.uuid}#$count");
      nodes.add(node);
      // A subtask of tasks that share a uuid is the first one's.
      if (task.uuid.isNotEmpty) byUuid.putIfAbsent(task.uuid, () => node);
    }
    final roots = <TaskNode>[];
    for (final node in nodes) {
      final parent = byUuid[node.task.parent];
      if (parent == null || parent.isOrIsIn(node)) {
        roots.add(node);
      } else {
        node._parent = parent;
        parent._children.add(node);
      }
    }
    for (final root in roots) {
      _count(root, 0);
    }
    return TaskTree._(roots);
  }

  static final empty = TaskTree(const []);

  /// Sets how deep [node] and the tasks in it are, and how many tasks each
  /// has in it.
  static void _count(TaskNode node, int depth) {
    node._depth = depth;
    var subtasks = 0;
    var done = 0;
    for (final child in node._children) {
      _count(child, depth + 1);
      subtasks += 1 + child._subtasks;
      done += (child.task.done ? 1 : 0) + child._subtasksDone;
    }
    node._subtasks = subtasks;
    node._subtasksDone = done;
  }

  /// The tasks of their own, which the others are in.
  final List<TaskNode> roots;

  final _byKey = <String, TaskNode>{};
  final _byUuid = <String, List<TaskNode>>{};

  /// Every task, each ahead of its subtasks: the order a list shows them in.
  late final List<TaskNode> nodes = List.unmodifiable([
    for (final root in roots) ...[root, ...root.descendants],
  ]);

  /// Every task, in the order of [nodes].
  List<TodoItem> get tasks => [for (final node in nodes) node.task];

  bool get isEmpty => roots.isEmpty;

  /// The task with [key] as its [TaskNode.key].
  TaskNode? operator [](String key) => _byKey[key];

  /// Where [task] stands: found by its uuid, or by its id as well when
  /// tasks share a uuid. Null when it isn't in the tree.
  TaskNode? nodeOf(TodoItem task) {
    final sameUuid = _byUuid[task.uuid];
    if (sameUuid == null) return null;
    if (sameUuid.length == 1) return sameUuid.single;
    return sameUuid.where((node) => node.task.id == task.id).firstOrNull;
  }

  /// Only the tasks [test] lets through, each in the nearest of the tasks
  /// it's inside of that got through too, or on its own when none did.
  TaskTree where(bool Function(TodoItem task) test) {
    final roots = <TaskNode>[];
    void visit(TaskNode node, TaskNode? shownParent) {
      var parent = shownParent;
      if (test(node.task)) {
        final shown = TaskNode._(node.task, node.key)
          .._parent = shownParent
          .._depth = shownParent == null ? 0 : shownParent._depth + 1
          .._subtasks = node._subtasks
          .._subtasksDone = node._subtasksDone;
        (shownParent?._children ?? roots).add(shown);
        parent = shown;
      }
      for (final child in node._children) {
        visit(child, parent);
      }
    }

    for (final root in this.roots) {
      visit(root, null);
    }
    return TaskTree._(roots);
  }

  /// The tasks that marking [node] done, or not done again, changes, [node]
  /// first:
  ///
  /// * Done, every task in it is done too. If that leaves the task it's in
  ///   with nothing to do, that one is done as well, and so on up.
  /// * Not done, the tasks it's inside of aren't done anymore either. The
  ///   tasks in it stay as they are.
  ///
  /// A daily task in one that isn't leaves that one alone either way.
  List<TaskNode> marking(TaskNode node, {required bool done}) {
    final changed = <TaskNode>[];
    if (!done) {
      if (node.task.done) changed.add(node);
      var child = node;
      for (var parent = node._parent;
          parent != null && child.countsFor(parent);
          child = parent, parent = parent._parent) {
        if (parent.task.done) changed.add(parent);
      }
      return changed;
    }
    for (final each in [node, ...node.descendants]) {
      if (!each.task.done) changed.add(each);
    }
    final marked = changed.toSet();
    var child = node;
    for (var parent = node._parent;
        parent != null && child.countsFor(parent) && !parent.task.done;
        child = parent, parent = parent._parent) {
      final within = parent;
      final nothingLeft = within._children.every((each) =>
          !each.countsFor(within) || each.task.done || marked.contains(each));
      if (!nothingLeft) break;
      changed.add(within);
      marked.add(within);
    }
    return changed;
  }

  /// The tasks that are done while a task in them isn't, which they can't
  /// be: as when a task that's still to do is added to one, or moved into
  /// it.
  List<TaskNode> get doneAheadOfSubtasks {
    final found = <TaskNode>[];
    bool isDone(TaskNode node) {
      var done = node.task.done;
      for (final child in node._children) {
        if (!isDone(child) && child.countsFor(node)) done = false;
      }
      if (done != node.task.done) found.add(node);
      return done;
    }

    for (final root in roots) {
      isDone(root);
    }
    return found;
  }

  /// Every task, in the order of [nodes], once [node] has gone into
  /// [parent] with the tasks in it, or out on its own for null: ahead of
  /// [before] among the tasks there, or after them all. Null if that's where
  /// it is already.
  List<TodoItem>? moving(TaskNode node,
      {required TaskNode? parent, TaskNode? before}) {
    assert(parent == null || !parent.isOrIsIn(node));
    final from = node._parent;
    final others = [
      for (final each in parent?._children ?? roots)
        if (!identical(each, node)) each,
    ];
    var index = before == null ? others.length : others.indexOf(before);
    if (index == -1) index = others.length;
    if (identical(from, parent) &&
        (from?._children ?? roots).indexOf(node) == index) {
      return null;
    }

    List<TaskNode> childrenOf(TaskNode? each) {
      if (identical(each, parent)) {
        return [...others.take(index), node, ...others.skip(index)];
      }
      final children = each?._children ?? roots;
      if (!identical(each, from)) return children;
      return [
        for (final child in children)
          if (!identical(child, node)) child,
      ];
    }

    final moved = node.task.under(parent?.task.uuid);
    final tasks = <TodoItem>[];
    void list(TaskNode each) {
      tasks.add(identical(each, node) ? moved : each.task);
      childrenOf(each).forEach(list);
    }

    childrenOf(null).forEach(list);
    return tasks;
  }
}
