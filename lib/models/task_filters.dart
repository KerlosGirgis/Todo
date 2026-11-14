import 'todo_item.dart';

/// Which tasks a page shows.
abstract class TaskFilter {
  /// Whether [task] is one of them.
  bool shows(TodoItem task);
}

class AllTasksFilter implements TaskFilter {
  const AllTasksFilter();
  @override
  bool shows(TodoItem task) => true;
}

class DoneTasksFilter implements TaskFilter {
  const DoneTasksFilter();
  @override
  bool shows(TodoItem task) => task.done;
}

class UndoneTasksFilter implements TaskFilter {
  const UndoneTasksFilter();
  @override
  bool shows(TodoItem task) => !task.done;
}
