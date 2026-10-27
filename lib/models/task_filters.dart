import 'todo_item.dart';

abstract class TaskFilter {
  List<TodoItem> apply(List<TodoItem> tasks);
}

class AllTasksFilter implements TaskFilter {
  const AllTasksFilter();
  @override
  List<TodoItem> apply(List<TodoItem> tasks) => List.from(tasks);
}

class DoneTasksFilter implements TaskFilter {
  const DoneTasksFilter();
  @override
  List<TodoItem> apply(List<TodoItem> tasks) =>
      tasks.where((task) => task.done).toList();
}

class UndoneTasksFilter implements TaskFilter {
  const UndoneTasksFilter();
  @override
  List<TodoItem> apply(List<TodoItem> tasks) =>
      tasks.where((task) => !task.done).toList();
}