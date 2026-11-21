import 'task_filters.dart';
import 'task_sort.dart';

/// Which tasks the to-do page shows, and in what order, as the user last
/// chose them: the database keeps it, so the page opens with them again.
class TaskListing {
  const TaskListing({
    this.filter = TaskFilter.all,
    this.sort = TaskSort.custom,
    this.direction = SortDirection.ascending,
  });

  final TaskFilter filter;
  final TaskSort sort;

  /// Which way they're sorted by due date. It's kept while they're in the
  /// user's own order, for when they're sorted by due date again.
  final SortDirection direction;

  TaskListing copyWith({
    TaskFilter? filter,
    TaskSort? sort,
    SortDirection? direction,
  }) => TaskListing(
    filter: filter ?? this.filter,
    sort: sort ?? this.sort,
    direction: direction ?? this.direction,
  );

  /// As the database keeps it: each as its index. One it doesn't know, as
  /// a newer version's might be, is the usual one, the first.
  factory TaskListing.fromMap(Map<String, Object?> map) {
    T pick<T>(List<T> values, Object? index) =>
        (index is int && index >= 0 ? values.elementAtOrNull(index) : null) ??
        values.first;
    return TaskListing(
      filter: pick(TaskFilter.values, map['taskFilter']),
      sort: pick(TaskSort.values, map['taskSort']),
      direction: pick(SortDirection.values, map['sortDirection']),
    );
  }

  Map<String, Object> toMap() => {
    'taskFilter': filter.index,
    'taskSort': sort.index,
    'sortDirection': direction.index,
  };

  @override
  bool operator ==(Object other) =>
      other is TaskListing &&
      other.filter == filter &&
      other.sort == sort &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(filter, sort, direction);

  @override
  String toString() =>
      "TaskListing(${filter.name}, ${sort.name}, ${direction.name})";
}
