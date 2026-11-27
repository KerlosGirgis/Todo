import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/result.dart';
import 'package:todo/models/trashed.dart';
import 'package:todo/view_model/trash_bin.dart';

/// A trash table in memory, of titles, the last deleted last.
class MemoryTrash {
  final rows = <Trashed<String>>[];

  /// Whether reading the table fails, or deleting from it does.
  bool failReads = false;
  bool failDeletes = false;

  void add(int id, String title) =>
      rows.add(Trashed(id: id, item: title, deletedAt: DateTime(2026, 11, id)));

  List<String> get titles => [for (final row in rows) row.item];

  /// The last deleted first, as the real table reads.
  Future<List<Trashed<String>>> read() async {
    if (failReads) throw StateError("Can't read the trash");
    return rows.reversed.toList();
  }

  Future<void> delete(Iterable<int> ids) async {
    if (failDeletes) throw StateError("Disk full");
    final gone = ids.toSet();
    rows.removeWhere((row) => gone.contains(row.id));
  }
}

void main() {
  late MemoryTrash table;
  late TrashBin<String> bin;
  late int changes;

  setUp(() async {
    table = MemoryTrash()
      ..add(1, "Shop")
      ..add(2, "Call")
      ..add(3, "secret");
    changes = 0;
    bin = TrashBin<String>(
      noun: "task",
      read: table.read,
      delete: table.delete,
      changed: () => changes++,
      // As a locked note's text is kept from the pages.
      shown: (entry) => entry.item == "secret" ? entry.withItem("") : entry,
    );
    await bin.load();
  });

  List<String> shown() => [for (final entry in bin.entries) entry.item];

  test("shows the entries the last deleted first, as the pages get them", () {
    expect(shown(), ["", "Call", "Shop"]);
    expect(changes, 1);
  });

  test(
    "shows the entries as they were when they can't be read in again",
    () async {
      table.failReads = true;
      await bin.reload();
      expect(shown(), ["", "Call", "Shop"]);
    },
  );

  test(
    "puts back the first deleted first, then reads the entries in again",
    () async {
      final order = <String>[];
      final (:back, :all) = await bin.putBackAll((entry) async {
        order.add(entry.item);
        table.rows.removeWhere((row) => row.id == entry.id);
        // One that was put back already, from a toast's Undo, say.
        return entry.item != "Call";
      });
      expect(order, ["Shop", "Call", "secret"]);
      expect((back, all), (2, true));
      expect(bin.entries, isEmpty);
      expect(
        (bin.restoredAll(back, all: all) as Success).message,
        "2 Tasks Restored",
      );
    },
  );

  test("puts back the rest when one can't go back, and says so", () async {
    final (:back, :all) = await bin.putBackAll((entry) async {
      if (entry.item == "Call") throw StateError("Disk full");
      return true;
    });
    expect((back, all), (2, false));
    expect(
      (bin.restoredAll(back, all: all) as Failure).message,
      "Couldn't restore every task",
    );
    expect(
      (bin.restoredAll(0, all: false) as Failure).message,
      "Couldn't restore the tasks",
    );
    expect((bin.restoredAll(1, all: true) as Success).message, "Task Restored");
  });

  test(
    "deletes an entry for good only once what it takes lets it, given all it "
    "holds",
    () async {
      Trashed<String>? asked;
      final denied = await bin.deleteForever(
        bin.entries.first,
        permit: (entry) async {
          asked = entry;
          return const Failure("Authentication failed");
        },
      );
      expect((denied as Failure).message, "Authentication failed");
      expect(asked!.item, "secret");
      expect(table.titles, ["Shop", "Call", "secret"]);

      final deleted = await bin.deleteForever(
        bin.entries.first,
        permit: (entry) async => null,
      );
      expect((deleted as Info).message, "Task Deleted Forever");
      expect(shown(), ["Call", "Shop"]);
    },
  );

  test("says so of an entry that's gone from it already", () async {
    final shop = bin.entries.last;
    await bin.deleteForever(shop);
    expect(
      (await bin.deleteForever(shop) as Info).message,
      "That task isn't in the Trash anymore",
    );
  });

  test(
    "empties what the user saw, once what it takes lets them all go",
    () async {
      // Put in since the trash was read in, so not seen.
      table.add(4, "Later");
      List<String>? asked;
      final denied = await bin.empty(
        permit: (entries) async {
          asked = [for (final entry in entries) entry.item];
          return const Failure("Authentication failed");
        },
      );
      expect(denied, isA<Failure>());
      expect(asked, ["secret", "Call", "Shop"]);
      expect(table.rows, hasLength(4));

      final emptied = await bin.empty();
      expect((emptied as Info).message, "3 Tasks Deleted Forever");
      expect(table.titles, ["Later"]);
      expect(shown(), ["Later"]);
    },
  );

  test("says so when it can't delete, and keeps the entries", () async {
    table.failDeletes = true;
    expect((await bin.empty() as Failure).message, "Couldn't delete the tasks");
    expect(
      (await bin.deleteForever(bin.entries.first) as Failure).message,
      "Couldn't delete the task",
    );
    expect(shown(), ["", "Call", "Shop"]);
  });
}
