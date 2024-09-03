class UserProfile{
  String firstName;
  String lastName;
  String pic;
  int theme;
  int? id;
  int auth;

  UserProfile({required this.firstName, required this.lastName, required this.pic,required this.theme, this.id,required this.auth});
  factory UserProfile.fromMap(Map<String, dynamic> map)
  {
    return UserProfile(id : map['id'],firstName : map['firstName'], lastName: map['lastName'], pic: map['pic'], theme: map['theme'],auth: map['auth']);
  }
  toMap() {
    return {'firstName': firstName, 'lastName': lastName, 'pic' : pic,'theme': theme,'auth':auth};
  }
}