sealed class Result {
  const Result();
}

class Success extends Result {
  final String message;

  const Success(this.message);
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

class Failure extends Result {
  final String message;

  const Failure(this.message);
}

/// A [Failure] that left everything as it was, so it can be asked again just
/// as it was: the form it came from stays open, with what was put in it.
class Unsaved extends Failure {
  const Unsaved(super.message);
}

class Info extends Result {
  final String message;

  const Info(this.message);
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
