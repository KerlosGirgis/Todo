/// How something the user asked for went, and what's said of it: a
/// [Success], said in green; an [Info], in grey; or a [Failure], in red.
sealed class Result {
  const Result(this.message);

  /// What's said of it, as its toast says it.
  final String message;
}

/// What the user asked for was done, which a confirmation says, in Title
/// Case: "Task Added", "Lock Disabled".
class Success extends Result {
  const Success(super.message);
}

/// A [Success] that changed more than was asked of it, as marking a task
/// done marks its subtasks done too, so it comes with a way to take it all
/// back.
class Undoable extends Success {
  const Undoable(super.message, {required this.undo});

  /// Puts things back as they were, and says how that went.
  final Future<Result> Function() undo;
}

/// An [Undoable] that moved something to the trash, which [undo] puts back
/// where it was.
class Deleted extends Undoable {
  const Deleted(super.message, {required super.undo});
}

/// Something went wrong, so what was asked couldn't be done: "Couldn't
/// save the task".
class Failure extends Result {
  const Failure(super.message);
}

/// A [Failure] that left everything as it was, so it can be asked again just
/// as it was: the form it came from stays open, with what was put in it.
class Unsaved extends Failure {
  const Unsaved(super.message);
}

/// Nothing was done, and why, or what it still needs, as a sentence: "Give
/// the task a title", "A reminder needs a time".
class Info extends Result {
  const Info(super.message);
}

/// What came of asking for something behind a lock: the thing, once the lock
/// let the user through, or why it didn't.
sealed class Access<T> {
  const Access();
}

class Granted<T> extends Access<T> {
  final T value;

  const Granted(this.value);
}

class Denied<T> extends Access<T> {
  final String message;

  const Denied(this.message);
}
