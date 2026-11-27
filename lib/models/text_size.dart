/// The text sizes on offer, as multiples of the default ones: from a
/// quarter to twice the size, in eighths. The app's own text sizes go by
/// them, and so do the home screen widgets'.
abstract final class TextSizes {
  static const min = 0.25;
  static const max = 2.0;
  static const step = 0.125;

  /// Whether [size] is one of them: no smaller than [min], and no bigger
  /// than [max].
  static bool offers(double size) => size >= min && size <= max;
}

/// One of the text sizes the profile keeps, each a multiple of its default
/// one: a task's title or its description, or a note's title or its text.
enum TextSizeSetting { taskTitle, taskDescription, noteTitle, noteBody }
