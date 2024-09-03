
class Note{
  String title;
  String body;
  int? id;
  int titleColor;
  int coverColor;


  Note({required this.title, required this.body,this.id, required this.titleColor, required this.coverColor});
  factory Note.fromMap(Map<String, dynamic> map)
  {
    return Note(id : map['id'], title: map['title'], body: map['body'],titleColor: map['titleColor'],coverColor: map['coverColor']);
  }
  toMap() {
    return {'title': title, 'body': body,'titleColor':titleColor,'coverColor':coverColor};
  }
}