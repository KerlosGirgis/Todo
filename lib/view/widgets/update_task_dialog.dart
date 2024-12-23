import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/provider/tasks_provider.dart';
import 'package:todo/provider/user_provider.dart';

import '../../models/todo_item.dart';
import '../../services/notification.dart';
import 'button.dart';

class UpdateTaskDialog extends StatelessWidget {
  const UpdateTaskDialog({
    super.key,
    required this.index,
  });
  final int index;
  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, TasksProvider>(
      builder: (context, user, tasks, child) {
        String date = tasks.items[index].date;
        String time = tasks.items[index].time;
        TextEditingController titleController = TextEditingController();
        titleController.text = tasks.items[index].title;
        TextEditingController descController = TextEditingController();
        descController.text = tasks.items[index].desc;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            scrollable: true,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Spacer(
                  flex: 1,
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xffd8defb),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Color(0xff3D5AFE),
                    size: 20,
                  ),
                ),
                const Spacer(
                  flex: 10,
                ),
                const Text(
                  "Edit Task",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                ),
                const Spacer(
                  flex: 10,
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                )
              ],
            ),
            backgroundColor: user.colorProvider.addTaskAlertBackground,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  maxLines: 1,
                  maxLength: 40,
                  decoration: InputDecoration(
                      labelText: "Title",
                      labelStyle: TextStyle(
                          fontSize: 30,
                          color: user.colorProvider.addTaskAlertText),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15))),
                ),
                TextField(
                  controller: descController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  maxLength: 250,
                  decoration: InputDecoration(
                      labelText: "Description",
                      labelStyle: TextStyle(
                          fontSize: 30,
                          color: user.colorProvider.addTaskAlertText),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15))),
                ),
                Row(
                  children: [
                    IconButton(
                        onPressed: () {
                          showDatePicker(
                                  context: context,
                                  firstDate: DateTime(DateTime.now().year,
                                      DateTime.now().month, DateTime.now().day),
                                  lastDate: DateTime(DateTime.now().year + 5))
                              .then((dateValue) {
                            if (dateValue != null) {
                              setState(() {
                                date = dateValue.toString().split(" ").first;
                              });
                            }
                          });
                        },
                        icon: const Icon(Icons.calendar_month)),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(date),
                            if (date.isNotEmpty)
                              IconButton(
                                  onPressed: () {
                                    setState(() {
                                      date = "";
                                      time = "";
                                    });
                                  },
                                  icon: const Icon(Icons.clear))
                          ],
                        ),
                      ],
                    )
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                        onPressed: () {
                          showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                      hour: DateTime.now().hour,
                                      minute: DateTime.now().minute))
                              .then((timeValue) {
                            if (timeValue != null) {
                              setState(() {
                                time = timeValue.format(context);
                                if (date.isEmpty) {
                                  date = DateTime.now()
                                      .toString()
                                      .split(" ")
                                      .first;
                                }
                              });
                            }
                          });
                        },
                        icon: const Icon(Icons.access_time_filled_sharp)),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(time),
                            if (time.isNotEmpty)
                              IconButton(
                                  onPressed: () {
                                    setState(() {
                                      time = "";
                                    });
                                  },
                                  icon: const Icon(Icons.clear))
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
            actions: [
              Button(
                onPressed: () {
                  Navigator.pop(context);
                },
                label: "Cancel",
                status: false,
                fontSize: 18,
                size: 1,
              ),
              Padding(
                  padding: EdgeInsets.only(
                      right: MediaQuery.of(context).size.width / 25)),
              Button(
                onPressed: () async {
                  int not = tasks.items[index].notification;
                  if (titleController.text.isEmpty) {
                    Fluttertoast.showToast(
                        msg: "Task title can't be empty",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                        fontSize: 19.0);
                    return;
                  }
                  if(tasks.items[index].notification==1){
                    FlutterLocalNotificationsPlugin().cancel(tasks.items[index].uuid.hashCode);
                    if(time.isNotEmpty&&TasksProvider().stringToDateTime(date, time).isAfter(DateTime.now())){
                      NotificationService.scheduleNotification(
                        tasks.items[index].uuid.hashCode,
                        tasks.items[index].title,
                        tasks.items[index].desc,
                        TasksProvider().stringToDateTime(date, time),
                      );
                    }
                    else{
                      not=0;
                    }
                  }

                  Provider.of<TasksProvider>(context, listen: false)
                      .updateTask(TodoItem(
                          title: titleController.text,
                          desc: descController.text,
                          id: tasks.items[index].id,
                          status: tasks.items[index].status,
                          date: date,
                          time: time,
                          uuid: tasks.items[index].uuid,
                          notification: not))
                      .then((value) {
                    Fluttertoast.showToast(
                        msg: "Task Updated",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: user.colorProvider.cardBackground,
                        textColor: user.colorProvider.appTitle,
                        fontSize: 19.0);
                  });
                  Navigator.of(context).pop();
                },
                label: 'Update',
                status: true,
                fontSize: 18,
                size: 1,
              ),
            ],
          );
        });
      },
    );
  }
}
