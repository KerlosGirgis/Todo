class UserProfile {
  String name;
  String pic;
  int theme;
  int? id;
  int autoSave;
  int casual;

  UserProfile(
      {required this.name,
      required this.pic,
      required this.theme,
      this.id,
      required this.autoSave,
      required this.casual
      });
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
        id: map['id'],
        name: map['name'],
        pic: map['pic'],
        theme: map['theme'],
        autoSave: map['autoSave'], casual: map['casual']);
  }
  toMap() {
    return {
      'name': name,
      'pic': pic,
      'theme': theme,
      'autoSave': autoSave,
      'casual': casual
    };
  }
}
