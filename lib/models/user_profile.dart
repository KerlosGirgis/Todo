class UserProfile {
  String name;
  String pic;
  int theme;
  int? id;
  int autoSave;
  int casual;
  int verse;
  int count;
  int finished;
  int unFinished;
  double notesTextSize;
  int startPage;
  int descLines;

  UserProfile(
      {required this.name,
      required this.pic,
      required this.theme,
      this.id,
      required this.autoSave,
      required this.casual,
      required this.verse,
      required this.count,
      required this.finished,
      required this.unFinished,
      required this.notesTextSize,
      required this.startPage,
      required this.descLines});

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
        id: map['id'],
        name: map['name'],
        pic: map['pic'],
        theme: map['theme'],
        autoSave: map['autoSave'],
        casual: map['casual'],
        verse: map['verse'],
        count: map['count'],
        finished: map['finished'],
        unFinished: map['unFinished'],
        notesTextSize: map['notesTextSize'],
        startPage: map['startPage'],
        descLines: map['descLines']);
  }
  Map<String, Object> toMap() {
    return {
      'name': name,
      'pic': pic,
      'theme': theme,
      'autoSave': autoSave,
      'casual': casual,
      'verse': verse,
      'count': count,
      'finished': finished,
      'unFinished': unFinished,
      'notesTextSize': notesTextSize,
      'startPage': startPage,
      'descLines': descLines
    };
  }
}
