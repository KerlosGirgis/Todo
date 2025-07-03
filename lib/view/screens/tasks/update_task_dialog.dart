import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/tasks_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';

import '../../../core/utils/date_time_utils.dart';
import '../../../models/todo_item.dart';
import '../../../services/notification_service.dart';
import '../../widgets/button.dart';

class UpdateTaskDialog extends StatelessWidget {
  const UpdateTaskDialog({
    super.key,
    required this.index,
  });
  final int index;
  @override
  Widget build(BuildContext context) {
    return Consumer2<UserViewModel, TasksViewModel>(
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
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xffd8defb),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Color(0xff3D5AFE),
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: const Text(
                    "Edit Task",
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                  ),
                ),
                Expanded(
                  child: IconButton(
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
                  ),
                )
              ],
            ),
            backgroundColor: user.colorManager.addTaskAlertBackground,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  maxLines: 1,
                  decoration: InputDecoration(
                      labelText: "Title",
                      labelStyle: TextStyle(
                          fontSize: 30,
                          color: user.colorManager.addTaskAlertText),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15))),
                ),
                Padding(padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height/50)),
                TextField(
                  controller: descController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  decoration: InputDecoration(
                      labelText: "Description",
                      labelStyle: TextStyle(
                          fontSize: 30,
                          color: user.colorManager.addTaskAlertText),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15))),
                ),
                Padding(padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height/90)),
                tasks.items[index].notification!=2?
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: IconButton(
                          onPressed: () {
                            if(tasks.items[index].notification!=2){
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
                            }
                            else{
                              Fluttertoast.showToast(
                                  msg: "Daily Tasks Don't Need A Date",
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: const Color(0xff1E1E1E),
                                  textColor: Colors.white,
                                  fontSize: 19.0);
                            }
                          },
                          icon: const Icon(Icons.calendar_month)),
                    ),
                    Flexible(
                      flex: 4,
                      fit: FlexFit.loose,
                        child: Text(date,style: TextStyle(fontSize: 18),maxLines: 1,overflow: TextOverflow.ellipsis,)),
                    if (date.isNotEmpty)
                      Flexible(
                        child: IconButton(
                            onPressed: () {
                              setState(() {
                                date = "";
                                time = "";
                              });
                            },
                            icon: const Icon(Icons.clear)),
                      ),
                  ],
                ):SizedBox.shrink(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: IconButton(
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
                                  if (date.isEmpty&&tasks.items[index].notification!=2) {
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
                    ),
                    Flexible(
                        flex: 4,
                        fit: FlexFit.loose,
                        child: Text(time,style: TextStyle(fontSize: 18),maxLines: 1,overflow: TextOverflow.ellipsis,)),
                    if (time.isNotEmpty)
                      Flexible(
                        child: IconButton(
                            onPressed: () {
                              setState(() {
                                time = "";
                              });
                            },
                            icon: const Icon(Icons.clear)),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              Row(
                spacing: MediaQuery.of(context).size.width / 25,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Button(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      label: "Cancel",
                      status: false,
                      fontSize: 18,
                      size: 1,
                    ),
                  ),
                  Expanded(
                    child: Button(
                      onPressed: () {
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
                          if(time.isNotEmpty&&DateTimeUtils.stringToDateTime(date, time).isAfter(DateTime.now())){
                            NotificationService.scheduleNotification(
                              tasks.items[index].uuid.hashCode,
                              "Don't Forget Your Task!",
                              tasks.items[index].title,
                              DateTimeUtils.stringToDateTime(date, time),
                            );
                          }
                          else{
                            not=0;
                          }
                        }
                        else if(tasks.items[index].notification==2){
                          FlutterLocalNotificationsPlugin().cancel(tasks.items[index].uuid.hashCode);
                          if(time.isNotEmpty){
                            date = "";
                            try{
                              NotificationService.scheduleDailyNotification(
                                tasks.items[index].uuid.hashCode,
                                "Don't Forget Your Task!",
                                tasks.items[index].title,
                                DateTimeUtils.parseTime(time),
                              ).then((onValue){
                                not = 2;
                              });
                            }
                            catch(e){
                              not = 0;
                            }
                          }
                          else{
                            not = 0;
                          }
                        }

                        Provider.of<TasksViewModel>(context, listen: false)
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
                              backgroundColor: const Color(0xff1E1E1E),
                              textColor: Colors.white,
                              fontSize: 19.0);
                        });
                        Navigator.of(context).pop();
                      },
                      label: 'Update',
                      status: true,
                      fontSize: 18,
                      size: 1,
                    ),
                  ),
                ],
              )
            ],
          );
        });
      },
    );
  }
}
