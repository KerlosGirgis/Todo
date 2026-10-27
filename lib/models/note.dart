class Note {
  const Note({
    this.id,
    required this.title,
    this.body = "",
    this.delta,
    this.titleColor = defaultTitleColor,
    this.coverColor = defaultCoverColor,
    this.locked = false,
  });

  /// A new note's colours, as 0xAARRGGBB: a white title on graphite.
  static const defaultTitleColor = 0xFFFFFFFF;
  static const defaultCoverColor = 0xFF1E1E1E;

  final int? id;
  final String title;

  /// The note's text without its formatting, which its card previews, a
  /// search looks through and the home screen's widget shows.
  final String body;

  /// The note's text with its formatting, as a Quill delta in JSON, or null
  /// for a note that hasn't been written in since notes had formatting,
  /// whose [body] is all there is.
  final String? delta;

  /// The colours of its title and cover, as 0xAARRGGBB.
  final int titleColor;
  final int coverColor;

  /// Whether the note only opens with the user's fingerprint.
  final bool locked;

  /// The note with nothing of its text, as the notes page holds a locked one.
  Note withoutText() => Note(
        id: id,
        title: title,
        titleColor: titleColor,
        coverColor: coverColor,
        locked: locked,
      );

  Note copyWith({
    String? title,
    String? body,
    String? delta,
    int? titleColor,
    int? coverColor,
    bool? locked,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      delta: delta ?? this.delta,
      titleColor: titleColor ?? this.titleColor,
      coverColor: coverColor ?? this.coverColor,
      locked: locked ?? this.locked,
    );
  }

  /// A note as the database and backups keep it, colours and all.
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String? ?? "",
      body: map['body'] as String? ?? "",
      delta: map['delta'] as String?,
      titleColor: _readColor(map['titleColor'], defaultTitleColor),
      coverColor: _readColor(map['coverColor'], defaultCoverColor),
      locked: map['protected'] == 1,
    );
  }

  /// The colours as "RRGGBB", as the colour picker has always written them.
  Map<String, Object?> toMap() {
    return {
      'title': title,
      'body': body,
      'delta': delta,
      'titleColor': _writeColor(titleColor),
      'coverColor': _writeColor(coverColor),
      'protected': locked ? 1 : 0,
    };
  }

  /// A colour as notes have kept it: a hex string such as "1E1E1E",
  /// "#1E1E1E" or "FF1E1E1E", read as the colour picker reads one, which
  /// takes anything it can't read as black; or, in notes from before
  /// colours were strings, an int. [fallback] when there's none.
  static int _readColor(Object? color, int fallback) {
    if (color is int) return color;
    if (color is! String) return fallback;
    var hex = color.replaceAll('#', '').replaceAll(' ', '').replaceAll('0x', '');
    if (hex.isEmpty || color.length > 200) return 0xFF000000;
    if (hex.length == 3) hex = hex[0] * 2 + hex[1] * 2 + hex[2] * 2;
    hex = hex.padLeft(6, '0').padLeft(8, 'F');
    return int.tryParse('0x${hex.substring(hex.length - 8)}') ?? 0xFF000000;
  }

  static String _writeColor(int color) =>
      (color & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');
}
