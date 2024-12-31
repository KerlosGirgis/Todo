import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/provider/user_provider.dart';
import 'package:uuid/v4.dart';
import '../../models/todo_item.dart';
import '../../provider/tasks_provider.dart';
import 'button.dart';

class AddTaskDialog extends StatelessWidget {
  const AddTaskDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    String date = "";
    String time = "";
    TextEditingController titleController = TextEditingController();
    TextEditingController descController = TextEditingController();
    return Consumer<UserProvider>(
      builder: (context, user, child) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              scrollable: true,
              backgroundColor: user.colorProvider.addTaskAlertBackground,
              title: Row(
                mainAxisSize: MainAxisSize.min,
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
                      Icons.add_task,
                      color: Color(0xff3D5AFE),
                      size: 20,
                    ),
                  ),
                  const Spacer(
                    flex: 10,
                  ),
                  const Text(
                    "Add Task",
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          onPressed: () {
                            showDatePicker(
                                    context: context,
                                    firstDate: DateTime(
                                        DateTime.now().year,
                                        DateTime.now().month,
                                        DateTime.now().day),
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
                        mainAxisSize: MainAxisSize.min,
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
                      ),
                      const Spacer(flex: 1,)
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                        mainAxisSize: MainAxisSize.min,
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
                      ),
                      const Spacer(flex: 1,)
                    ],
                  ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Button(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      label: 'Cancel',
                      status: false,
                      fontSize: 18,
                      size: 1,
                    ),
                    Padding(
                        padding: EdgeInsets.only(
                            right: MediaQuery.of(context).size.width / 25)),
                    Button(
                      onPressed: () {
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
                        Navigator.pop(context);
                        Provider.of<TasksProvider>(context, listen: false)
                            .addTask(TodoItem(
                          title: titleController.text,
                          desc: descController.text,
                          status: 0,
                          date: date,
                          time: time,
                          uuid: const UuidV4().generate(),
                          notification: 0,
                        ))
                            .then((value) async {
                          user.increaseUnFinished();
                          Fluttertoast.showToast(
                              msg: "Task Added",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor:
                                  user.colorProvider.cardBackground,
                              textColor: user.colorProvider.appTitle,
                              fontSize: 19.0);
                        });
                      },
                      label: 'Save',
                      status: true,
                      fontSize: 18,
                      size: 1,
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
