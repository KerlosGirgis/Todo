import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/pages/notes_page.dart';
import 'package:todo/pages/profile_page.dart';
import 'package:todo/provider/tasks_provider.dart';
import 'package:todo/provider/user_provider.dart';
import 'package:todo/services/icon_provider.dart';


class TodoPage extends StatefulWidget {
  const TodoPage({
    super.key,
  });
  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TasksProvider>(context, listen: false).get();
    });
    super.initState();
  }

  DateTime stringToDateTime(String date, String time12Hour) {
    DateFormat format12Hour = DateFormat('h:mm a');
    DateTime dateTime = format12Hour.parse(time12Hour);
    DateFormat format24Hour = DateFormat('HH:mm:ss');
    String time24Hour = format24Hour.format(dateTime);
    return DateTime.parse("$date $time24Hour");
  }

  TextEditingController titleController = TextEditingController();
  TextEditingController descController = TextEditingController();
  TextEditingController dateController = TextEditingController();
  TextEditingController timeController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    String date = "";
    String time = "";
    return Consumer<UserProvider>(
      builder: (context, user, child) {
        return Scaffold(
          backgroundColor: user.colorProvider.pageBackground,
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                  heroTag: 0,
                  backgroundColor:
                      user.colorProvider.floatingActionButtonBackground,
                  foregroundColor:
                      user.colorProvider.floatingActionButtonForeground,
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const NotesPage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(0.0, 1.0);
                          const end = Offset.zero;
                          const curve = Curves.ease;
                          var tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));
                          var offsetAnimation = animation.drive(tween);
                          return SlideTransition(
                              position: offsetAnimation, child: child);
                        },
                      ),
                    );
                  },
                  child: const Icon(Icons.edit_note_sharp)),
              const Padding(padding: EdgeInsets.only(bottom: 20)),
              FloatingActionButton(
                heroTag: 1,
                backgroundColor:
                    user.colorProvider.floatingActionButtonBackground,
                foregroundColor:
                    user.colorProvider.floatingActionButtonForeground,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      String dateText = "";
                      String timeText = "";
                      return StatefulBuilder(
                        builder: (context, setState) {
                          return AlertDialog(
                            scrollable: true,
                            backgroundColor:
                                user.colorProvider.addTaskAlertBackground,
                            title: const Text(
                              "Add Task",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 32),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: titleController,
                                  maxLines: 1,
                                  maxLength: 25,
                                  decoration: InputDecoration(
                                      labelText: "Title",
                                      labelStyle: TextStyle(
                                          fontSize: 30,
                                          color: user
                                              .colorProvider.addTaskAlertText)),
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
                                          color: user
                                              .colorProvider.addTaskAlertText)),
                                ),
                                const Padding(
                                    padding: EdgeInsets.only(bottom: 15)),
                                Row(
                                  children: [
                                    IconButton(
                                        onPressed: () {
                                          DateTime? selectedDate;
                                          TimeOfDay? selectedTime;
                                          showDatePicker(
                                                  context: context,
                                                  firstDate: DateTime(
                                                      DateTime.now().year,
                                                      DateTime.now().month,
                                                      DateTime.now().day),
                                                  lastDate: DateTime(
                                                      DateTime.now().year + 1))
                                              .then((dateValue) {
                                            if (dateValue != null) {
                                              selectedDate = dateValue;
                                              date = selectedDate!
                                                  .toString()
                                                  .split(" ")
                                                  .first;
                                              setState(() {
                                                dateText = date;
                                              });
                                              if (kDebugMode) {
                                                print(selectedDate
                                                    ?.toString()
                                                    .split(" ")
                                                    .first);
                                              }
                                              showTimePicker(
                                                      context: context,
                                                      initialTime: TimeOfDay(
                                                          hour: DateTime.now()
                                                              .hour,
                                                          minute: DateTime.now()
                                                              .minute))
                                                  .then((timeValue) {
                                                if (timeValue != null) {
                                                  selectedTime = timeValue;
                                                  time = selectedTime!
                                                      .format(context);
                                                  setState(() {
                                                    timeText = time;
                                                  });
                                                  if (kDebugMode) {
                                                    print(selectedTime);
                                                  }
                                                }
                                              });
                                            }
                                          });
                                        },
                                        icon: const Icon(Icons.calendar_month)),
                                    Text("$dateText $timeText")
                                  ],
                                )
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  titleController.clear();
                                  descController.clear();
                                  date="";
                                  time="";
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                      color: Colors.blueAccent[900],
                                      fontSize: 18),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  if (titleController.text.isEmpty) {
                                    Fluttertoast.showToast(
                                        msg: "Task title can't be empty",
                                        toastLength: Toast.LENGTH_SHORT,
                                        gravity: ToastGravity.BOTTOM,
                                        backgroundColor: Colors.red,
                                        textColor: Colors.white,
                                        fontSize: 19.0
                                    );
                                    return;
                                  }
                                  Provider.of<TasksProvider>(context,
                                          listen: false)
                                      .addTask(TodoItem(
                                    title: titleController.text,
                                    desc: descController.text,
                                    status: 0,
                                    date: date,
                                    time: time,
                                  ))
                                      .then((value) {
                                    titleController.clear();
                                    descController.clear();
                                    date="";
                                    time="";
                                    Fluttertoast.showToast(
                                        msg: "Task Added",
                                        toastLength: Toast.LENGTH_SHORT,
                                        gravity: ToastGravity.BOTTOM,
                                        backgroundColor: user.colorProvider.cardBackground,
                                        textColor: user.colorProvider.appTitle,
                                        fontSize: 19.0
                                    );
                                  });
                                  Navigator.pop(context);

                                },
                                child: Text(
                                  "Save",
                                  style: TextStyle(
                                      color: Colors.blueAccent[900],
                                      fontSize: 18),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
          body: Consumer<TasksProvider>(
            builder: (context, tasks, child) {
              return tasks.items.isEmpty
                  ? Center(
                      child: Image.asset(
                        "assets/empty_list.png",
                        scale: 2,
                      ),
                    )
                  : Theme(
                      data: ThemeData(canvasColor: Colors.transparent),
                      child: ReorderableListView.builder(
                        itemCount: tasks.items.length,
                        itemBuilder: (context, index) {
                          final taskKey = tasks.items[index].id.toString();
                          return Dismissible(
                            onDismissed: (direction) async {
                              Provider.of<TasksProvider>(context, listen: false)
                                  .dismissTask(index, tasks.items[index].id!)
                                  .then((value) async {
                                Fluttertoast.showToast(
                                    msg: "Task Deleted",
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                    backgroundColor: user.colorProvider.cardBackground,
                                    textColor: user.colorProvider.appTitle,
                                    fontSize: 19.0
                                );
                              });
                            },
                            key: Key(taskKey),
                            child: Card(
                              elevation: 1,
                              color: user.colorProvider.cardBackground,
                              child: ListTile(
                                title: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            child: AutoSizeText(
                                                tasks.items[index].title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                minFontSize: 18,
                                                style: tasks.items[index].status == 0
                                                    ? TextStyle(
                                                        fontSize: 26,
                                                        color: user
                                                            .colorProvider
                                                            .taskTitle)
                                                    : const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 26,
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough,
                                                        decorationThickness:
                                                            3)),
                                            onLongPress: () {
                                              titleController.text =
                                                  tasks.items[index].title;
                                              descController.text =
                                                  tasks.items[index].desc;
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    String editedDateText = "";
                                                    String editedTimeText = "";
                                                    return StatefulBuilder(
                                                        builder: (context,
                                                            setState) {
                                                      return AlertDialog(
                                                        scrollable: true,
                                                        title: const Text(
                                                          "Edit Task",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 32),
                                                        ),
                                                        backgroundColor: user
                                                            .colorProvider
                                                            .editTaskAlertBackground,
                                                        content: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            TextField(
                                                              controller:
                                                                  titleController,
                                                              maxLines: 1,
                                                              maxLength: 25,
                                                              decoration: InputDecoration(
                                                                  labelText:
                                                                      "Title",
                                                                  labelStyle: TextStyle(
                                                                      fontSize:
                                                                          30,
                                                                      color: user
                                                                          .colorProvider
                                                                          .addTaskAlertText)),
                                                            ),
                                                            TextField(
                                                              controller:
                                                                  descController,
                                                              keyboardType:
                                                                  TextInputType
                                                                      .multiline,
                                                              maxLines: 4,
                                                              maxLength: 250,
                                                              decoration: InputDecoration(
                                                                  labelText:
                                                                      "Description",
                                                                  labelStyle: TextStyle(
                                                                      fontSize:
                                                                          30,
                                                                      color: user
                                                                          .colorProvider
                                                                          .addTaskAlertText)),
                                                            ),
                                                            Row(
                                                              children: [
                                                                IconButton(
                                                                    onPressed:
                                                                        () {
                                                                      DateTime?
                                                                          selectedDate;
                                                                      TimeOfDay?
                                                                          selectedTime;
                                                                      showDatePicker(
                                                                              context: context,
                                                                              firstDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
                                                                              lastDate: DateTime(DateTime.now().year + 1))
                                                                          .then((dateValue) {
                                                                        if (dateValue !=
                                                                            null) {
                                                                          selectedDate =
                                                                              dateValue;
                                                                          date = selectedDate!
                                                                              .toString()
                                                                              .split(" ")
                                                                              .first;
                                                                          setState(
                                                                              () {
                                                                            editedDateText =
                                                                                date;
                                                                          });
                                                                          if (kDebugMode) {
                                                                            print(selectedDate?.toString().split(" ").first);
                                                                          }
                                                                          showTimePicker(context: context, initialTime: TimeOfDay(hour: DateTime.now().hour, minute: DateTime.now().minute))
                                                                              .then((timeValue) {
                                                                            if (timeValue !=
                                                                                null) {
                                                                              selectedTime = timeValue;
                                                                              time = selectedTime!.format(context);
                                                                              setState(() {
                                                                                editedTimeText = time;
                                                                              });
                                                                              if (kDebugMode) {
                                                                                print(selectedTime?.format(context));
                                                                              }
                                                                            } else {
                                                                              time = "";
                                                                              setState(() {
                                                                                editedTimeText = time;
                                                                              });
                                                                            }
                                                                          });
                                                                        }
                                                                      });
                                                                    },
                                                                    icon: const Icon(
                                                                        Icons
                                                                            .calendar_month)),
                                                                Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .start,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Row(
                                                                      children: [
                                                                        Text(
                                                                            "Current: ${tasks.items[index].date}  ${tasks.items[index].time}"),
                                                                      ],
                                                                    ),
                                                                    Row(
                                                                      children: [
                                                                        Text(
                                                                            "New: $editedDateText $editedTimeText")
                                                                      ],
                                                                    )
                                                                  ],
                                                                )
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () {
                                                              titleController
                                                                  .clear();
                                                              descController
                                                                  .clear();
                                                              date = "";
                                                              time = "";
                                                              Navigator.pop(
                                                                  context);
                                                            },
                                                            child: const Text(
                                                                "Cancel"),
                                                          ),
                                                          TextButton(
                                                            onPressed:
                                                                () async {
                                                              if (titleController
                                                                  .text
                                                                  .isEmpty) {
                                                                Fluttertoast.showToast(
                                                                    msg: "Task title can't be empty",
                                                                    toastLength: Toast.LENGTH_SHORT,
                                                                    gravity: ToastGravity.BOTTOM,
                                                                    backgroundColor: Colors.red,
                                                                    textColor: Colors.white,
                                                                    fontSize: 19.0
                                                                );
                                                                return;
                                                              }
                                                              /*

                                                           */
                                                              Provider.of<TasksProvider>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .updateTask(TodoItem(
                                                                      title: titleController
                                                                          .text,
                                                                      desc: descController
                                                                          .text,
                                                                      id: tasks
                                                                          .items[
                                                                              index]
                                                                          .id,
                                                                      status: tasks
                                                                          .items[
                                                                              index]
                                                                          .status,
                                                                      date: date
                                                                              .isEmpty
                                                                          ? tasks
                                                                              .items[
                                                                                  index]
                                                                              .date
                                                                          : date,
                                                                      time:
                                                                          time))
                                                                  .then(
                                                                      (value) {
                                                                titleController
                                                                    .clear();
                                                                descController
                                                                    .clear();
                                                                date = "";
                                                                time = "";
                                                                Fluttertoast.showToast(
                                                                    msg: "Task Updated",
                                                                    toastLength: Toast.LENGTH_SHORT,
                                                                    gravity: ToastGravity.BOTTOM,
                                                                    backgroundColor: user.colorProvider.cardBackground,
                                                                    textColor: user.colorProvider.appTitle,
                                                                    fontSize: 19.0
                                                                );
                                                              });
                                                              if (context
                                                                  .mounted) {
                                                                Navigator.of(
                                                                        context)
                                                                    .pop();
                                                              }
                                                            },
                                                            child: const Text(
                                                                "Update"),
                                                          ),
                                                        ],
                                                      );
                                                    });
                                                  });
                                            },
                                            /*
                                    TodoItem(
                                            title: tasks.items[index]
                                                .title,
                                            desc: tasks.items[index]
                                                .desc,
                                            id: tasks.items[index].id,
                                            status: 1,
                                            date: tasks.items[index]
                                                .date,
                                            time: tasks.items[index]
                                                .time)
                                    */
                                            onTap: () async {
                                              if (tasks.items[index].status ==
                                                  0) {
                                                Provider.of<TasksProvider>(
                                                        context,
                                                        listen: false)
                                                    .updateTask(TodoItem(
                                                        title: tasks
                                                            .items[index].title,
                                                        desc: tasks
                                                            .items[index].desc,
                                                        id: tasks
                                                            .items[index].id,
                                                        status: 1,
                                                        date: tasks
                                                            .items[index].date,
                                                        time: tasks
                                                            .items[index].time))
                                                    .then((value) {
                                                  titleController.clear();
                                                  descController.clear();
                                                  Fluttertoast.showToast(
                                                      msg: "Task done",
                                                      toastLength: Toast.LENGTH_SHORT,
                                                      gravity: ToastGravity.BOTTOM,
                                                      backgroundColor: Colors.green,
                                                      textColor: Colors.white,
                                                      fontSize: 19.0
                                                  );
                                                });
                                              } else {
                                                Provider.of<TasksProvider>(
                                                        context,
                                                        listen: false)
                                                    .updateTask(TodoItem(
                                                        title: tasks
                                                            .items[index].title,
                                                        desc: tasks
                                                            .items[index].desc,
                                                        id: tasks
                                                            .items[index].id,
                                                        status: 0,
                                                        date: tasks
                                                            .items[index].date,
                                                        time: tasks
                                                            .items[index].time))
                                                    .then((value) {
                                                  titleController.clear();
                                                  descController.clear();
                                                  Fluttertoast.showToast(
                                                      msg: "Task undone",
                                                      toastLength: Toast.LENGTH_SHORT,
                                                      gravity: ToastGravity.BOTTOM,
                                                      backgroundColor: user.colorProvider.cardBackground,
                                                      textColor: user.colorProvider.appTitle,
                                                      fontSize: 19.0
                                                  );
                                                });
                                              }
                                            },
                                          ),
                                        ),

                                        const Padding(
                                            padding:
                                                EdgeInsets.only(right: 10)),
                                        //Text(DateTime.now().isAfter(stringToDateTime(items[index].date, items[index].time)).toString())
                                        tasks.items[index].status != 1 &&
                                                tasks.items[index].date
                                                    .isNotEmpty &&
                                                tasks.items[index].time
                                                    .isNotEmpty &&
                                                DateTime.now().isAfter(
                                                    stringToDateTime(
                                                        tasks.items[index].date,
                                                        tasks
                                                            .items[index].time))
                                            ? const Icon(
                                                Icons.dangerous_outlined,
                                                color: Colors.red,
                                              )
                                            : tasks.items[index].status != 1 &&
                                                    tasks.items[index].date
                                                        .isNotEmpty &&
                                                    tasks.items[index].time
                                                        .isEmpty &&
                                                    DateTime.now().isAfter(
                                                        DateTime.parse(tasks
                                                            .items[index].date))
                                                ? const Icon(
                                                    Icons.dangerous_outlined,
                                                    color: Colors.red,
                                                  )
                                                : tasks.items[index].status != 1
                                                    ? const Icon(
                                                        Icons.check_outlined)
                                                    : const Icon(
                                                        Icons.check,
                                                        color: Colors.green,
                                                      )
                                      ],
                                    ),
                                    tasks.items[index].date.isNotEmpty ||
                                            tasks.items[index].time.isNotEmpty
                                        ? Row(
                                            children: [
                                              Text(
                                                "${tasks.items[index].date}  ${tasks.items[index].time}",
                                                style: TextStyle(
                                                    color:
                                                        user.colorProvider.date,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontSize: 16),
                                              )
                                            ],
                                          )
                                        : const Row()
                                  ],
                                ),
                                subtitle: tasks.items[index].desc.isNotEmpty
                                    ? Text(
                                        tasks.items[index].desc,
                                        style: TextStyle(
                                            color: user.colorProvider.subtitle),
                                      )
                                    : null,
                                isThreeLine: false,
                              ),
                            ),
                          );
                        },
                        onReorder: (int oldIndex, int newIndex) async {
                          Provider.of<TasksProvider>(context, listen: false)
                              .syncAfterReorder(oldIndex, newIndex);
                        },
                      ),
                    );
            },
          ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: user.colorProvider.pageBackground,
            title: Text(
              "ToDo",
              style: TextStyle(
                fontSize: 30,
                color: user.colorProvider.appTitle,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              Row(
                children: [
                  GestureDetector(
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: user.user.pic
                                  .substring(0, 1)
                                  .compareTo("0") ==
                              0
                          ? AssetImage(IconProvider.getAvatar(user.user.pic))
                          : FileImage(File(user.user.pic)),
                      radius: 18,
                    ),
                    onTap: () {
                      showDialog(
                          useRootNavigator: true,
                          context: context,
                          builder: (e) {
                            return AlertDialog(
                              scrollable: true,
                              backgroundColor:
                                  user.colorProvider.profileAlertBackground,
                              title: CircleAvatar(
                                radius: 130,
                                backgroundColor: Colors.transparent,
                                backgroundImage: user.user.pic
                                            .substring(0, 1)
                                            .compareTo("0") ==
                                        0
                                    ? AssetImage(
                                        IconProvider.getAvatar(user.user.pic))
                                    : FileImage(File(user.user.pic)),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                          child: Text(
                                        "${user.user.firstName} ${user.user.lastName}",
                                        maxLines: 2,
                                        overflow: TextOverflow.clip,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 42),
                                      ))
                                    ],
                                  ),
                                  const Padding(
                                      padding: EdgeInsets.only(bottom: 10)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                user.user.theme == 0
                                                    ? Colors.white
                                                    : Colors.black12,
                                          ),
                                          onPressed: () {
                                            Provider.of<UserProvider>(context,
                                                    listen: false)
                                                .changeTheme();
                                            Navigator.pop(context);
                                          },
                                          child: Icon(user.user.theme == 1
                                              ? Icons.dark_mode_sharp
                                              : Icons.light_mode_sharp)),
                                      const Padding(
                                          padding: EdgeInsets.only(right: 30)),
                                      ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                pageBuilder: (context,
                                                        animation,
                                                        secondaryAnimation) =>
                                                    const ProfilePage(),
                                                transitionsBuilder: (context,
                                                    animation,
                                                    secondaryAnimation,
                                                    child) {
                                                  const begin =
                                                      Offset(0.0, 1.0);
                                                  const end = Offset.zero;
                                                  const curve = Curves.ease;
                                                  var tween = Tween(
                                                          begin: begin,
                                                          end: end)
                                                      .chain(CurveTween(
                                                          curve: curve));
                                                  var offsetAnimation =
                                                      animation.drive(tween);
                                                  return SlideTransition(
                                                      position: offsetAnimation,
                                                      child: child);
                                                },
                                              ),
                                            );
                                          },
                                          child: const Icon(Icons.edit))
                                    ],
                                  ),
                                ],
                              ),
                            );
                          });
                    },
                  ),
                  const Padding(padding: EdgeInsets.only(right: 18))
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
