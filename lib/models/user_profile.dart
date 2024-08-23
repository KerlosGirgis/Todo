class UserProfile{
  String firstName;
  String lastName;
  String pic;
  int? id;

  UserProfile({required this.firstName, required this.lastName, required this.pic, this.id});
  factory UserProfile.fromMap(Map<String, dynamic> map)
  {
    return UserProfile(id : map['id'],firstName : map['firstName'], lastName: map['lastName'], pic: map['pic']);
  }
  toMap() {
    return {'firstName': firstName, 'lastName': lastName, 'pic' : pic};
  }
}