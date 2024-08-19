class TodoItem{
  String title;
  String desc;
  int? id;
  int status;

  TodoItem({required this.title, required this.desc, required this.status, this.id});
  factory TodoItem.fromMap(Map<String, dynamic> map)
  {
    return TodoItem(id : map['id'], title: map['title'], desc: map['desc'], status: map['status']);
  }
  toMap() {
    return {'title': title, 'desc': desc, 'status' : status};
  }

}