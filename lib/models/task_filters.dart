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
      tasks.where((task) => task.status == 1).toList();
}

class UndoneTasksFilter implements TaskFilter {
  const UndoneTasksFilter();
  @override
  List<TodoItem> apply(List<TodoItem> tasks) =>
      tasks.where((task) => task.status == 0).toList();
}