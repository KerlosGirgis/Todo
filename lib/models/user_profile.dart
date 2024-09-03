class UserProfile{
  String firstName;
  String lastName;
  String pic;
  int theme;
  int? id;

  UserProfile({required this.firstName, required this.lastName, required this.pic,required this.theme, this.id});
  factory UserProfile.fromMap(Map<String, dynamic> map)
  {
    return UserProfile(id : map['id'],firstName : map['firstName'], lastName: map['lastName'], pic: map['pic'], theme: map['theme']);
  }
  toMap() {
    return {'firstName': firstName, 'lastName': lastName, 'pic' : pic,'theme': theme};
  }
}