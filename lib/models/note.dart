class Note{
  String title;
  String body;
  int? id;


  Note({required this.title, required this.body,this.id});
  factory Note.fromMap(Map<String, dynamic> map)
  {
    return Note(id : map['id'], title: map['title'], body: map['body']);
  }
  toMap() {
    return {'title': title, 'body': body};
  }
}