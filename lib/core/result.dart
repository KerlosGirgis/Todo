sealed class Result {
  const Result();

  void when({
    required void Function(String message) onSuccess,
    required void Function(String message) onFailure,
    required void Function(String message) onInfo,
  });
}

class Success extends Result {
  final String message;

  const Success(this.message);

  @override
  void when({
    required void Function(String message) onSuccess,
    required void Function(String message) onFailure,
    required void Function(String message) onInfo,
  }) {
    onSuccess(message);
  }
}

/// A [Success] that changed more than was asked of it, as marking a task
/// done marks its subtasks done too, so it comes with a way to take it all
/// back.
class Undoable extends Success {
  const Undoable(super.message, {required this.undo});

  /// Puts things back as they were, and says how that went.
  final Future<Result> Function() undo;
}

class Failure extends Result {
  final String message;

  const Failure(this.message);

  @override
  void when({
    required void Function(String message) onSuccess,
    required void Function(String message) onFailure,
    required void Function(String message) onInfo,
  }) {
    onFailure(message);
  }
}

class Info extends Result {
  final String message;

  const Info(this.message);

  @override
  void when({
    required void Function(String message) onSuccess,
    required void Function(String message) onFailure,
    required void Function(String message) onInfo,
  }) {
    onInfo(message);
  }
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
