import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/core/result.dart';
import 'package:uuid/v4.dart';
import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../widgets/button.dart';

class AddTaskDialog extends StatelessWidget {
  const AddTaskDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    String date = "";
    String time = "";
    int notification = 0;
    TextEditingController titleController = TextEditingController();
    TextEditingController descController = TextEditingController();
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: context.colors.pageBackground,
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
                    color: context.colors.dialogIconContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_task,
                    color: context.colors.dialogIcon,
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
                      color: context.colors.wB),
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.close,
                    color: context.colors.dialogExitIcon,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.dialogExitContainer,
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
                  labelStyle: TextStyle(fontSize: 30, color: context.colors.wB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: context.colors.cardBackground,
                ),
                style: TextStyle(
                  fontSize: 22,
                  color: context.colors.wB,
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
                  labelStyle: TextStyle(fontSize: 30, color: context.colors.wB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: context.colors.cardBackground,
                ),
                style: TextStyle(
                  fontSize: 20,
                  color: context.colors.wB,
                ),
              ),
              notification != 2
                  ? Padding(
                    padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height / 50),
                    child: SizedBox(
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
                          onLongPress: () {
                            setState(() {
                              date = "";
                              time = "";
                            });
                            FeedbackToast.info("Date Cleared");
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.cardBackground,
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
                                  Icons.calendar_month,
                                  color: context.colors.wB,
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
                                        fontSize: 18, color: context.colors.wB),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
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
                          if (date.isEmpty&&notification!=2) {
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
                    FeedbackToast.info("Time Cleared");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.cardBackground,
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
                          color: context.colors.wB,
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
                              color: context.colors.wB,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.sizeOf(context).height / 80)),
              DropdownMenu<int>(
                initialSelection: notification,
                expandedInsets: EdgeInsets.zero,
                leadingIcon: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Icon(
                    Icons.notifications_active,
                    color: context.colors.wB,
                  ),
                ),
                textStyle: TextStyle(
                  fontSize: 18,
                  color: context.colors.wB,
                ),
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    context.colors.cardBackground,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  isDense: true,
                  fillColor: context.colors.cardBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownMenuEntries: const [
                  DropdownMenuEntry(
                    value: 0,
                    label: "Off",
                  ),
                  DropdownMenuEntry(
                    value: 1,
                    label: "Once",
                  ),
                  DropdownMenuEntry(
                    value: 2,
                    label: "Daily",
                  ),
                ],
                onSelected: (value) {
                  if (value != null) {
                    setState(() {
                      notification = value;
                      if(value==2){
                        date="";
                      }
                    });
                  }
                },
              )
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
                    onPressed: () async {
                      if (titleController.text.isEmpty) {
                        FeedbackToast.error("Task title can't be empty");
                        return;
                      }
                      Navigator.pop(context);
                      Result status = await Provider.of<TasksViewModel>(context,
                              listen: false)
                          .addTask(
                              TodoItem(
                                title: titleController.text,
                                desc: descController.text,
                                status: 0,
                                date: date,
                                time: time,
                                uuid: const UuidV4().generate(),
                                notification: 0,
                              ),
                              notification);
                      if (status is Success) {
                        FeedbackToast.success(status.message);
                      } else if (status is Failure) {
                        FeedbackToast.error(status.message);
                      } else if (status is Info) {
                        FeedbackToast.info(status.message);
                      }
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
  }
}
