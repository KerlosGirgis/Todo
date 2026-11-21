import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/task_filters.dart';
import 'package:todo/models/task_listing.dart';
import 'package:todo/models/task_sort.dart';

void main() {
  test('is kept as the indexes of its filter, sort and direction', () {
    const listing = TaskListing(
      filter: TaskFilter.weekly,
      sort: TaskSort.dueDate,
      direction: SortDirection.descending,
    );
    expect(listing.toMap(), {
      'taskFilter': 4,
      'taskSort': 1,
      'sortDirection': 1,
    });
    expect(TaskListing.fromMap(listing.toMap()), listing);
  });

  test("reads one it doesn't know, or one that's missing, as the usual", () {
    expect(
      TaskListing.fromMap({
        'taskFilter': 99,
        'taskSort': -1,
        'sortDirection': "x",
      }),
      const TaskListing(),
    );
    expect(TaskListing.fromMap({}), const TaskListing());
    expect(
      const TaskListing(),
      const TaskListing(
        filter: TaskFilter.all,
        sort: TaskSort.custom,
        direction: SortDirection.ascending,
      ),
    );
  });

  test('changes one thing at a time', () {
    const listing = TaskListing(filter: TaskFilter.done);
    expect(
      listing.copyWith(sort: TaskSort.dueDate),
      const TaskListing(filter: TaskFilter.done, sort: TaskSort.dueDate),
    );
    expect(listing.copyWith(), listing);
  });
}
