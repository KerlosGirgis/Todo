import 'dart:collection';

import '../core/prompts.dart';
import '../core/result.dart';
import '../models/trashed.dart';

/// What the trash page asks of the tasks' or the notes' view model: the
/// entries in their trash, and putting them back or deleting them for good,
/// each saying how it went.
abstract interface class TrashOwner<T> {
  /// The entries, the last deleted first, as the trash page shows them,
  /// once [getTrash] has read them in.
  List<Trashed<T>> get trash;

  /// Reads in the entries.
  Future<void> getTrash();

  /// Puts back what [entry] holds, where it was when it can.
  Future<Result> restoreFromTrash(Trashed<T> entry);

  /// Puts back what every entry holds.
  Future<Result> restoreAllFromTrash();

  /// Deletes what [entry] holds for good, with [askForPassword] for the App
  /// Lock's password, should that be what it takes.
  Future<Result> deleteForever(
    Trashed<T> entry, {
    PasswordPrompt? askForPassword,
  });

  /// Deletes every entry for good, as [deleteForever] does.
  Future<Result> emptyTrash({PasswordPrompt? askForPassword});
}

/// A trash's entries, and the work of putting them back or deleting them
/// for good that the tasks' and the notes' view models share: reading them
/// in, the order they go back in, letting one be deleted only once what it
/// takes says so, and what's said of how it went. What an entry holds, how
/// it goes back, and what deleting it takes are the view model's.
class TrashBin<T> {
  /// [noun] is what the trash holds, "task" or "note", as what's said of it
  /// names it. `read` and `delete` are the trash table's, `changed` tells
  /// the pages the entries have changed, and `shown` gives an entry as the
  /// pages get it, when that's other than as it is.
  TrashBin({
    required this.noun,
    required this._read,
    required this._delete,
    required this._changed,
    Trashed<T> Function(Trashed<T> entry)? shown,
  }) : _shownOf = shown;

  final String noun;
  final Future<List<Trashed<T>>> Function() _read;
  final Future<void> Function(Iterable<int> ids) _delete;
  final void Function() _changed;
  final Trashed<T> Function(Trashed<T> entry)? _shownOf;

  /// The entries, with all they hold, the last deleted first.
  List<Trashed<T>> _entries = [];

  /// The entries as the pages get them.
  List<Trashed<T>> _shown = [];
  List<Trashed<T>> get entries => UnmodifiableListView(_shown);

  /// Reads in the entries.
  Future<void> load() async {
    _entries = await _read();
    final shownOf = _shownOf;
    _shown = shownOf == null
        ? _entries
        : [for (final entry in _entries) shownOf(entry)];
    _changed();
  }

  /// Reads in the entries again once they've changed. Should that fail,
  /// they're shown as they were, until they're next read in: the change has
  /// gone through, or the user has been told it hasn't, either way.
  Future<void> reload() async {
    try {
      await load();
    } catch (e) {
      // Shown as they were.
    }
  }

  /// [entry], one of [entries], with all it holds, or null when it isn't in
  /// the trash anymore.
  Future<Trashed<T>?> full(Trashed<T> entry) async {
    bool same(Trashed<T> each) => each.id == entry.id;
    return _entries.where(same).firstOrNull ??
        (await _read()).where(same).firstOrNull;
  }

  /// Puts back every entry with [putBack], which says whether it was still
  /// there to put back, the first deleted first, so that one deleted later
  /// can't take the place one deleted before it had. Then reads the entries
  /// in again. How many went back, and whether all of them did.
  Future<({int back, bool all})> putBackAll(
    Future<bool> Function(Trashed<T> entry) putBack,
  ) async {
    var back = 0;
    var all = true;
    try {
      for (final entry in (await _read()).reversed) {
        try {
          if (await putBack(entry)) back++;
        } catch (e) {
          all = false;
        }
      }
    } catch (e) {
      all = false;
    }
    await reload();
    return (back: back, all: all);
  }

  /// Deletes [entry] for good, once [permit] lets it, given the entry with
  /// all it holds: [permit] gives why it doesn't, or null.
  Future<Result> deleteForever(
    Trashed<T> entry, {
    Future<Result?> Function(Trashed<T> entry)? permit,
  }) async {
    final Trashed<T>? found;
    try {
      found = await full(entry);
    } catch (e) {
      return Failure("Couldn't delete the $noun");
    }
    if (found == null) return gone;
    if (await permit?.call(found) case final denied?) return denied;
    try {
      await _delete([found.id]);
    } catch (e) {
      return Failure("Couldn't delete the $noun");
    }
    await reload();
    return Info("$_title Deleted Forever");
  }

  /// Deletes every entry for good, as the user saw them, once [permit] lets
  /// them all go, given them with all they hold: [permit] gives why it
  /// doesn't, or null.
  Future<Result> empty({
    Future<Result?> Function(List<Trashed<T>> entries)? permit,
  }) async {
    final entries = List.of(_entries);
    if (await permit?.call(entries) case final denied?) return denied;
    try {
      await _delete([for (final entry in entries) entry.id]);
    } catch (e) {
      return Failure("Couldn't delete the ${noun}s");
    }
    await reload();
    final count = entries.length;
    return Info(
      count == 1
          ? "1 $_title Deleted Forever"
          : "$count ${_title}s Deleted Forever",
    );
  }

  /// What's said of an entry that couldn't be put back.
  Failure get unrestorable => Failure("Couldn't restore the $noun");

  /// What's said of an entry that's gone from the trash already: put back
  /// or deleted for good since.
  Info get gone => Info("That $noun isn't in the Trash anymore");

  /// What's said of an entry put back.
  Success get restored => Success("$_title Restored");

  /// What's said of putting back every entry: [count] went back, and [all]
  /// of them did, or not.
  Result restoredAll(int count, {required bool all}) {
    if (!all) {
      return Failure(
        count == 0
            ? "Couldn't restore the ${noun}s"
            : "Couldn't restore every $noun",
      );
    }
    return Success(
      count == 1 ? "$_title Restored" : "$count ${_title}s Restored",
    );
  }

  /// [noun] as a title names it: "Task".
  String get _title => "${noun[0].toUpperCase()}${noun.substring(1)}";
}
