class TodoItem{
  String title;
  String desc;
  int? id;
  int status;
  String date;
  String time;

  TodoItem({required this.title, required this.desc, required this.status, this.id,required this.date,required this.time});
  factory TodoItem.fromMap(Map<String, dynamic> map)
  {
    return TodoItem(id : map['id'], title: map['title'], desc: map['desc'], status: map['status'], date: map['date'], time: map['time']);
  }
  toMap() {
    return {'title': title, 'desc': desc, 'status' : status, 'date': date, 'time' : time};
  }

}