import 'avatar.dart';

/// The page the app opens on. Kept as its index: 0 or 1.
enum StartPage { tasks, notes }

class UserProfile {
  const UserProfile({
    this.id,
    required this.name,
    required this.avatar,
    required this.darkTheme,
    required this.autoSave,
    required this.casualFont,
    required this.showVerse,
    required this.wordCount,
    required this.finished,
    required this.unfinished,
    required this.notesTextSize,
    required this.startPage,
    required this.descLines,
    required this.tasksTitleSize,
    required this.tasksDescSize,
    required this.notesTitleSize,
  });

  final int? id;
  final String name;
  final Avatar avatar;
  final bool darkTheme;

  /// Whether notes save as they're written, rather than with a button.
  final bool autoSave;

  /// Whether notes are in the handwritten font.
  final bool casualFont;

  /// Whether the avatar's dialog shows the day's Bible verse.
  final bool showVerse;

  /// Whether the note editor counts the words.
  final bool wordCount;
  final int finished;
  final int unfinished;

  /// Text sizes, as multiples of the default ones.
  final double notesTextSize;
  final double notesTitleSize;
  final double tasksTitleSize;
  final double tasksDescSize;
  final StartPage startPage;

  /// How many lines of a task's description show before "Show More"; 0 shows
  /// it all.
  final int descLines;

  UserProfile copyWith({
    String? name,
    Avatar? avatar,
    bool? darkTheme,
    bool? autoSave,
    bool? casualFont,
    bool? showVerse,
    bool? wordCount,
    int? finished,
    int? unfinished,
    double? notesTextSize,
    StartPage? startPage,
    int? descLines,
    double? tasksTitleSize,
    double? tasksDescSize,
    double? notesTitleSize,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      darkTheme: darkTheme ?? this.darkTheme,
      autoSave: autoSave ?? this.autoSave,
      casualFont: casualFont ?? this.casualFont,
      showVerse: showVerse ?? this.showVerse,
      wordCount: wordCount ?? this.wordCount,
      finished: finished ?? this.finished,
      unfinished: unfinished ?? this.unfinished,
      notesTextSize: notesTextSize ?? this.notesTextSize,
      startPage: startPage ?? this.startPage,
      descLines: descLines ?? this.descLines,
      tasksTitleSize: tasksTitleSize ?? this.tasksTitleSize,
      tasksDescSize: tasksDescSize ?? this.tasksDescSize,
      notesTitleSize: notesTitleSize ?? this.notesTitleSize,
    );
  }

  /// The profile as the database keeps it, with its switches as 1 or 0.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    double size(String key) => (map[key] as num?)?.toDouble() ?? 1;
    return UserProfile(
      id: map['id'] as int?,
      name: map['name'] as String? ?? "",
      avatar: Avatar.decode(map['pic'] as String? ?? "000"),
      darkTheme: map['theme'] == 1,
      autoSave: map['autoSave'] == 1,
      casualFont: map['casual'] == 1,
      showVerse: map['verse'] == 1,
      wordCount: map['count'] == 1,
      finished: map['finished'] as int? ?? 0,
      unfinished: map['unFinished'] as int? ?? 0,
      notesTextSize: size('notesTextSize'),
      startPage: (map['startPage'] as int? ?? 0) == 0
          ? StartPage.tasks
          : StartPage.notes,
      descLines: map['descLines'] as int? ?? 2,
      tasksTitleSize: size('tasksTitleSize'),
      tasksDescSize: size('tasksDescSize'),
      notesTitleSize: size('notesTitleSize'),
    );
  }

  Map<String, Object> toMap() {
    return {
      'name': name,
      'pic': avatar.encoded,
      'theme': darkTheme ? 1 : 0,
      'autoSave': autoSave ? 1 : 0,
      'casual': casualFont ? 1 : 0,
      'verse': showVerse ? 1 : 0,
      'count': wordCount ? 1 : 0,
      'finished': finished,
      'unFinished': unfinished,
      'notesTextSize': notesTextSize,
      'startPage': startPage.index,
      'descLines': descLines,
      'tasksTitleSize': tasksTitleSize,
      'tasksDescSize': tasksDescSize,
      'notesTitleSize': notesTitleSize,
    };
  }
}
