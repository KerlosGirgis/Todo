import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/tasks_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';

import '../../../../../core/utils/date_time_utils.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../services/notification_service.dart';
import '../../../../widgets/button.dart';

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            backgroundColor: user.colorManager.pageBackground,
            scrollable: true,
            elevation: 2,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: user.colorManager.dialogIconContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit,
                      color: user.colorManager.dialogIcon,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    "Edit Task",
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                        color: user.colorManager.wB),
                  ),
                ),
                Expanded(
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      Icons.close,
                      color: user.colorManager.dialogExitIcon,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: user.colorManager.dialogExitContainer,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                  ),
                )
              ],
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 22, color: user.colorManager.wB),
                  decoration: InputDecoration(
                    labelText: "Title",
                    labelStyle: TextStyle(
                        fontSize: 30, color: user.colorManager.wB),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none),
                    filled: true,
                    fillColor: user.colorManager.cardBackground,
                  ),
                ),
                Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.sizeOf(context).height / 50)),
                TextField(
                  controller: descController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  style: TextStyle(
                      fontSize: 20, color: user.colorManager.wB),
                  decoration: InputDecoration(
                    labelText: "Description",
                    labelStyle: TextStyle(
                        fontSize: 30, color: user.colorManager.wB),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none),
                    filled: true,
                    fillColor: user.colorManager.cardBackground,
                  ),
                ),
                Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.sizeOf(context).height / 50)),
                tasks.items[index].notification != 2
                    ? SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (tasks.items[index].notification != 2) {
                              showDatePicker(
                                      context: context,
                                      firstDate: DateTime(
                                          DateTime.now().year,
                                          DateTime.now().month,
                                          DateTime.now().day),
                                      lastDate:
                                          DateTime(DateTime.now().year + 5))
                                  .then((dateValue) {
                                if (dateValue != null) {
                                  setState(() {
                                    date =
                                        dateValue.toString().split(" ").first;
                                  });
                                }
                              });
                            } else {
                              Fluttertoast.showToast(
                                  msg: "Daily Tasks Don't Need A Date",
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: const Color(0xff1E1E1E),
                                  textColor: Colors.white,
                                  fontSize: 19.0);
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              date = "";
                              time = "";
                            });
                            Fluttertoast.showToast(
                                msg: "Date Cleared",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: const Color(0xff1E1E1E),
                                textColor: Colors.white,
                                fontSize: 19.0
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: user.colorManager.cardBackground,
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(50)),
                            ),
                            elevation: 0,
                          ),
                          child: ClipRect(
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  color: user.colorManager.wB,
                                ),
                                Spacer(
                                  flex: 1,
                                ),
                                Flexible(
                                    flex: 8,
                                    fit: FlexFit.tight,
                                    child: Text(
                                      date,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: user.colorManager.wB,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SizedBox.shrink(),
                Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.sizeOf(context).height / 80)),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
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
                            if (date.isEmpty &&
                                tasks.items[index].notification != 2) {
                              date = DateTime.now().toString().split(" ").first;
                            }
                          });
                        }
                      });
                    },
                    onLongPress: () {
                      setState(() {
                        time = "";
                      });
                      Fluttertoast.showToast(
                          msg: "Time Cleared",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: const Color(0xff1E1E1E),
                          textColor: Colors.white,
                          fontSize: 19.0
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: user.colorManager.cardBackground,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                      elevation: 0,
                    ),
                    child: ClipRect(
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Icon(
                            Icons.access_time_filled_sharp,
                            color: user.colorManager.wB,
                          ),
                          Spacer(
                            flex: 1,
                          ),
                          Flexible(
                              flex: 8,
                              fit: FlexFit.tight,
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: user.colorManager.wB,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )),
                        ],
                      ),
                    ),
                  ),
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
                        if (tasks.items[index].notification == 1) {
                          FlutterLocalNotificationsPlugin()
                              .cancel(id:tasks.items[index].uuid.hashCode);
                          if (time.isNotEmpty &&
                              DateTimeUtils.stringToDateTime(date, time)
                                  .isAfter(DateTime.now())) {
                            NotificationService.scheduleNotification(
                              tasks.items[index].uuid.hashCode,
                              "Don't Forget Your Task!",
                              tasks.items[index].title,
                              DateTimeUtils.stringToDateTime(date, time),
                            );
                          } else {
                            not = 0;
                          }
                        } else if (tasks.items[index].notification == 2) {
                          FlutterLocalNotificationsPlugin()
                              .cancel(id:tasks.items[index].uuid.hashCode);
                          if (time.isNotEmpty) {
                            date = "";
                            try {
                              NotificationService.scheduleDailyNotification(
                                tasks.items[index].uuid.hashCode,
                                "Don't Forget Your Task!",
                                tasks.items[index].title,
                                DateTimeUtils.parseTime(time),
                              ).then((onValue) {
                                not = 2;
                              });
                            } catch (e) {
                              not = 0;
                            }
                          } else {
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
