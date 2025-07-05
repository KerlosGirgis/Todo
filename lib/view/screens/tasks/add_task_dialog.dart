import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:uuid/v4.dart';
import '../../../models/todo_item.dart';
import '../../../view_model/tasks_view_model.dart';
import '../../widgets/button.dart';

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
    return Consumer<UserViewModel>(
      builder: (context, user, child) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              scrollable: true,
              backgroundColor: user.colorManager.pageBackground,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
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
                        Icons.add_task,
                        color: user.colorManager.dialogIcon,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      "Add Task",
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                          color: user.colorManager.homePageText),
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
                    decoration: InputDecoration(
                      labelText: "Title",
                      labelStyle: TextStyle(
                          fontSize: 30, color: user.colorManager.homePageText),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none
                      ),
                      filled: true,
                      fillColor: user.colorManager.cardBackground,
                    ),
                    style: TextStyle(
                      fontSize: 22,
                      color: user.colorManager.homePageText,
                    ),
                  ),
                  Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.sizeOf(context).height / 50)),
                  TextField(
                    controller: descController,
                    keyboardType: TextInputType.multiline,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: "Description",
                      labelStyle: TextStyle(
                          fontSize: 30, color: user.colorManager.homePageText),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none
                      ),
                      filled: true,
                      fillColor: user.colorManager.cardBackground,
                    ),
                    style: TextStyle(
                      fontSize: 20,
                      color: user.colorManager.homePageText,
                    ),
                  ),
                  Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.sizeOf(context).height / 50)),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
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
                            Icon(Icons.calendar_month,
                              color: user.colorManager.homePageText,
                            ),
                            Spacer(
                              flex: 1,
                            ),
                            Flexible(
                              flex: 5,
                              fit: FlexFit.tight,
                              child: Text(
                                date,
                                style: TextStyle(
                                    fontSize: 18,
                                    color: user.colorManager.homePageText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (date.isNotEmpty)
                              Flexible(
                                flex: 1,
                                fit: FlexFit.tight,
                                child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        date = "";
                                        time = "";
                                      });
                                    },
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.red.shade500,
                                    )),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                            Icon(Icons.access_time_filled_sharp,
                              color: user.colorManager.homePageText,),
                            Spacer(flex: 1,),
                            Flexible(
                              flex: 5,
                              fit: FlexFit.tight,
                              child: Text(
                                time,
                                style: TextStyle(fontSize: 18,
                                  color: user.colorManager.homePageText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (time.isNotEmpty)
                              Flexible(
                                flex: 1,
                                fit: FlexFit.tight,
                                child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        time = "";
                                      });
                                    },
                                    icon: Icon(Icons.clear,color: Colors.red.shade500,)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Button(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        label: 'Cancel',
                        status: false,
                        fontSize: 18,
                        size: 1,
                      ),
                    ),
                    Padding(
                        padding: EdgeInsets.only(
                            right: MediaQuery.of(context).size.width / 25)),
                    Expanded(
                      child: Button(
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
                          Provider.of<TasksViewModel>(context, listen: false)
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
                                backgroundColor: const Color(0xff1E1E1E),
                                textColor: Colors.white,
                                fontSize: 19.0);
                          });
                        },
                        label: 'Save',
                        status: true,
                        fontSize: 18,
                        size: 1,
                      ),
                    ),
                  ],
                )
              ],
            );
          },
        );
      },
    );
  }
}
