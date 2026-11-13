import 'dart:convert';

/// What the trash holds: deleted tasks, or deleted notes.
enum TrashKind { task, note }

/// A task or note in the trash: deleted, but kept as it was until it's put
/// back or deleted for good.
class Trashed<T> {
  const Trashed({
    required this.id,
    required this.item,
    required this.deletedAt,
  });

  /// Which of the trash's entries it is, which putting it back or deleting
  /// it for good goes by.
  final int id;

  /// The task or note as it was deleted, with the id it had then, so it can
  /// go back where it was.
  final T item;

  /// When it was deleted.
  final DateTime deletedAt;

  /// The same entry, holding [item] instead, such as a locked note without
  /// its text.
  Trashed<T> withItem(T item) =>
      Trashed(id: id, item: item, deletedAt: deletedAt);

  /// An entry as the trash keeps it: [item] as backups keep it, in JSON,
  /// beside the id it had on its list, [itemId].
  static Map<String, Object?> toRow({
    required TrashKind kind,
    required int? itemId,
    required Map<String, Object?> item,
    required DateTime deletedAt,
  }) =>
      {
        'kind': kind.name,
        'itemId': itemId,
        'item': jsonEncode(item),
        'deletedAt': deletedAt.toIso8601String(),
      };

  /// An entry the trash keeps, its item read by [fromMap] as from a backup,
  /// or null for one that can't be read.
  static Trashed<T>? fromRow<T>(
      Map<String, Object?> row, T Function(Map<String, dynamic> map) fromMap) {
    try {
      final item = jsonDecode(row['item'] as String) as Map<String, dynamic>;
      return Trashed(
        id: row['id'] as int,
        item: fromMap({...item, 'id': row['itemId']}),
        deletedAt: DateTime.parse(row['deletedAt'] as String),
      );
    } catch (e) {
      return null;
    }
  }
}
