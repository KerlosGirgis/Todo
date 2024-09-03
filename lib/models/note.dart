
class Note{
  String title;
  String body;
  int? id;
  int titleColor;
  int coverColor;
  int protected;


  Note({required this.title, required this.body,this.id, required this.titleColor, required this.coverColor,required this.protected});
  factory Note.fromMap(Map<String, dynamic> map)
  {
    return Note(id : map['id'], title: map['title'], body: map['body'],titleColor: map['titleColor'],coverColor: map['coverColor'],protected: map['protected']);
  }
  toMap() {
    return {'title': title, 'body': body,'titleColor':titleColor,'coverColor':coverColor,'protected':protected};
  }
}