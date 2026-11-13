import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/models/clock_time.dart';
import 'package:todo/models/daily_progress.dart';
import 'package:todo/models/note.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/trashed.dart';

void main() {
  final deletedAt = DateTime(2026, 5, 13, 21, 30);

  test('keeps a task as backups keep it, with the id it had', () {
    final task = TodoItem(
      id: 7,
      uuid: "call",
      title: "Call",
      desc: "About the trip",
      time: const ClockTime(18, 0),
      reminder: Reminder.daily,
      progress: DailyProgress(
          since: DateTime(2026, 5, 10), doneDays: [DateTime(2026, 5, 12)]),
    );
    final row = Trashed.toRow(
        kind: TrashKind.task,
        itemId: task.id,
        item: task.toMap(),
        deletedAt: deletedAt);
    expect(row['kind'], "task");
    expect(row['itemId'], 7);
    expect(jsonDecode(row['item'] as String), task.toMap());
    expect(row['deletedAt'], "2026-05-13T21:30:00.000");

    final entry = Trashed.fromRow({...row, 'id': 3}, TodoItem.fromMap)!;
    expect(entry.id, 3);
    expect(entry.deletedAt, deletedAt);
    expect(entry.item.id, 7);
    expect(entry.item.toMap(), task.toMap());
  });

  test('keeps a note with all it says, lock and colours too', () {
    const note = Note(
      id: 2,
      title: "Diary",
      body: "secret",
      delta: '[{"insert":"secret\\n"}]',
      titleColor: 0xFF000000,
      coverColor: 0xFFFFCC00,
      locked: true,
    );
    final row = Trashed.toRow(
        kind: TrashKind.note,
        itemId: note.id,
        item: note.toMap(),
        deletedAt: deletedAt);
    final entry = Trashed.fromRow({...row, 'id': 1}, Note.fromMap)!;
    expect(row['kind'], "note");
    expect(entry.item.id, 2);
    expect(entry.item.toMap(), note.toMap());
    expect(entry.item.locked, isTrue);
  });

  test("leaves out an entry it can't read", () {
    expect(
      Trashed.fromRow({
        'id': 1,
        'kind': "task",
        'itemId': 1,
        'item': "{not json",
        'deletedAt': "2026-05-13T21:30:00.000",
      }, TodoItem.fromMap),
      isNull,
    );
  });
}
