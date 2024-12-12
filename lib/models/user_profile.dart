class UserProfile {
  String firstName;
  String lastName;
  String pic;
  int theme;
  int? id;
  int autoSave;

  UserProfile(
      {required this.firstName,
      required this.lastName,
      required this.pic,
      required this.theme,
      this.id,
      required this.autoSave});
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
        id: map['id'],
        firstName: map['firstName'],
        lastName: map['lastName'],
        pic: map['pic'],
        theme: map['theme'],
        autoSave: map['autoSave']);
  }
  toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'pic': pic,
      'theme': theme,
      'autoSave': autoSave
    };
  }
}
