import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/pages/profile_page.dart';
import 'package:todo/services/color_provider.dart';
import 'package:todo/services/database_service.dart';
import 'package:todo/services/icon_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    getItems();
    getUser();
    super.initState();
  }

  List<TodoItem> items = [];
  List<UserProfile> user = [];
  late ColorProvider colorProvider;
  bool isItemsLoading = false;
  bool isUserLoading = false;
  void getUser() async {
    setState(() {
      isUserLoading = true;
    });
    user = await DatabaseService().getUser();
    if (user.isEmpty) {
      await DatabaseService().insertUser(
          UserProfile(firstName: "user", lastName: "", pic: "000", theme: 1));
      user = await DatabaseService().getUser();
    }
    colorProvider = ColorProvider(user.first.theme);
    setState(() {
      isUserLoading = false;
    });
  }

  void getItems() async {
    setState(() {
      isItemsLoading = true;
    });
    items = await DatabaseService().getItems();
    setState(() {
      isItemsLoading = false;
    });
  }

  DateTime stringToDateTime(String date, String time12Hour) {
    // Create a DateFormat instance for parsing the 12-hour format

    DateFormat format12Hour =
        DateFormat('h:mm a'); // 'h:mm a' for 12-hour format with AM/PM

    // Parse the 12-hour time string into a DateTime object
    DateTime dateTime = format12Hour.parse(time12Hour);

    // Create a DateFormat instance for the 24-hour format
    DateFormat format24Hour =
        DateFormat('HH:mm:ss'); // 'HH:mm' for 24-hour format

    // Convert the DateTime object to a 24-hour formatted string
    String time24Hour = format24Hour.format(dateTime);

    if (kDebugMode) {
      print(time24Hour);
    }
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
    return isUserLoading == true
        ? const SizedBox.shrink()
        : Scaffold(
            backgroundColor: colorProvider.homePageBackground,
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    //add task
                    return AlertDialog(
                      scrollable: true,
                      backgroundColor: colorProvider.addTaskAlertBackground,
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
                                    color: colorProvider.addTaskAlertText)),
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
                                    color: colorProvider.addTaskAlertText)),
                          ),
                          const Padding(padding: EdgeInsets.only(bottom: 15)),
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
                                        if (kDebugMode) {
                                          print(selectedDate
                                              ?.toString()
                                              .split(" ")
                                              .first);
                                        }
                                        showTimePicker(
                                                context: context,
                                                initialTime: TimeOfDay(
                                                    hour: DateTime.now().hour,
                                                    minute:
                                                        DateTime.now().minute))
                                            .then((timeValue) {
                                          if (timeValue != null) {
                                            selectedTime = timeValue;
                                            time =
                                                selectedTime!.format(context);
                                            if (kDebugMode) {
                                              print(selectedTime);
                                            }
                                          }
                                        });
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.calendar_month))
                            ],
                          )
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            titleController.clear();
                            descController.clear();
                            Navigator.pop(context);
                          },
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (titleController.text.isEmpty) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text("Task title can't be empty"),
                                duration: Durations.long4,
                              ));
                              return;
                            }
                            await DatabaseService()
                                .insertItem(
                              TodoItem(
                                title: titleController.text,
                                desc: descController.text,
                                status: 0,
                                date: date,
                                time: time,
                              ),
                            )
                                .then((value) {
                              getItems();
                              titleController.clear();
                              descController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Task Added")));
                            });
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: const Text("Save"),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Icon(Icons.add),
            ),
            body: items.isEmpty
                ? Center(
                    child: Image.asset(
                      "assets/empty_list.png",
                      scale: 2,
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final taskKey=items[index].title;
                      return Dismissible(
                        onDismissed: (direction) async {
                          await DatabaseService()
                              .deleteItem(items[index].id!)
                              .then((value) async {
                            getItems();
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text("Task Deleted"),
                              duration: Durations.long4,
                            ));
                          });
                        },
                        key: Key(taskKey),
                        child: Card(
                          elevation: 1,
                          color: colorProvider.cardBackground,
                          child: ListTile(
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    titleController.text = items[index].title;
                                    descController.text = items[index].desc;
                                    showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            scrollable: true,
                                            title: const Text(
                                              "Edit Task",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 32),
                                            ),
                                            backgroundColor: colorProvider
                                                .editTaskAlertBackground,
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
                                                          color: colorProvider
                                                              .addTaskAlertText)),
                                                ),
                                                TextField(
                                                  controller: descController,
                                                  keyboardType:
                                                      TextInputType.multiline,
                                                  maxLines: 4,
                                                  maxLength: 250,
                                                  decoration: InputDecoration(
                                                      labelText: "Description",
                                                      labelStyle: TextStyle(
                                                          fontSize: 30,
                                                          color: colorProvider
                                                              .addTaskAlertText)),
                                                ),
                                                Row(
                                                  children: [
                                                    IconButton(
                                                        onPressed: () {
                                                          DateTime? selectedDate;
                                                          TimeOfDay? selectedTime;
                                                          showDatePicker(
                                                                  context:
                                                                      context,
                                                                  firstDate: DateTime(
                                                                      DateTime.now()
                                                                          .year,
                                                                      DateTime.now()
                                                                          .month,
                                                                      DateTime.now()
                                                                          .day),
                                                                  lastDate: DateTime(
                                                                      DateTime.now()
                                                                              .year +
                                                                          1))
                                                              .then((dateValue) {
                                                            if (dateValue !=
                                                                null) {
                                                              selectedDate =
                                                                  dateValue;
                                                              date = selectedDate!
                                                                  .toString()
                                                                  .split(" ")
                                                                  .first;
                                                              if (kDebugMode) {
                                                                print(selectedDate
                                                                    ?.toString()
                                                                    .split(" ")
                                                                    .first);
                                                              }
                                                              showTimePicker(
                                                                      context:
                                                                          context,
                                                                      initialTime: TimeOfDay(
                                                                          hour: DateTime.now()
                                                                              .hour,
                                                                          minute: DateTime.now()
                                                                              .minute))
                                                                  .then(
                                                                      (timeValue) {
                                                                if (timeValue !=
                                                                    null) {
                                                                  selectedTime =
                                                                      timeValue;
                                                                  time = selectedTime!
                                                                      .format(
                                                                          context);
                                                                  if (kDebugMode) {
                                                                    print(selectedTime
                                                                        ?.format(
                                                                            context));
                                                                  }
                                                                }
                                                              });
                                                            }
                                                          });
                                                        },
                                                        icon: const Icon(Icons
                                                            .calendar_month)),
                                                    Text(
                                                        "${items[index].date}  ${items[index].time}")
                                                  ],
                                                )
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  titleController.clear();
                                                  descController.clear();
                                                  Navigator.pop(context);
                                                },
                                                child: const Text("Cancel"),
                                              ),
                                              TextButton(
                                                onPressed: () async {
                                                  if (titleController
                                                      .text.isEmpty) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                            const SnackBar(
                                                      content: Text(
                                                          "Task title can't be empty"),
                                                      duration: Durations.long4,
                                                    ));
                                                    return;
                                                  }
                                                  await DatabaseService()
                                                      .updateItem(TodoItem(
                                                          title: titleController
                                                              .text,
                                                          desc:
                                                              descController.text,
                                                          id: items[index].id,
                                                          status:
                                                              items[index].status,
                                                          date: date.isEmpty
                                                              ? items[index].date
                                                              : date,
                                                          time: time.isEmpty
                                                              ? items[index].time
                                                              : time))
                                                      .then((value) {
                                                    getItems();
                                                    titleController.clear();
                                                    descController.clear();
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                            const SnackBar(
                                                      content:
                                                          Text("Task Updated"),
                                                      duration: Durations.long4,
                                                    ));
                                                  });
                                                  if (context.mounted) {
                                                    Navigator.of(context).pop();
                                                  }
                                                },
                                                child: const Text("Update"),
                                              ),
                                            ],
                                          );
                                        });
                                  },
                                  icon: const Icon(Icons.edit),
                                  color: Colors.blue,
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await DatabaseService()
                                        .deleteItem(items[index].id!)
                                        .then((value) async {
                                      getItems();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text("Task Deleted"),
                                        duration: Durations.long4,
                                      ));
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            title: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        child: AutoSizeText(items[index].title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            minFontSize: 18,
                                            style: items[index].status == 0
                                                ? const TextStyle(fontSize: 22)
                                                : const TextStyle(
                                                    fontSize: 22,
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    decorationThickness: 3)),
                                        onTap: () async {
                                          if (items[index].status == 0) {
                                            await DatabaseService()
                                                .updateItem(TodoItem(
                                                    title: items[index].title,
                                                    desc: items[index].desc,
                                                    id: items[index].id,
                                                    status: 1,
                                                    date: items[index].date,
                                                    time: items[index].time))
                                                .then((value) {
                                              getItems();
                                              titleController.clear();
                                              descController.clear();
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                content: Text("Task done"),
                                                duration: Durations.long4,
                                              ));
                                            });
                                          } else {
                                            await DatabaseService()
                                                .updateItem(TodoItem(
                                                    title: items[index].title,
                                                    desc: items[index].desc,
                                                    id: items[index].id,
                                                    status: 0,
                                                    date: items[index].date,
                                                    time: items[index].time))
                                                .then((value) {
                                              getItems();
                                              titleController.clear();
                                              descController.clear();
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                content: Text("Task undone"),
                                                duration: Durations.long4,
                                              ));
                                            });
                                          }
                                        },
                                      ),
                                    ),

                                    const Padding(
                                        padding: EdgeInsets.only(right: 10)),
                                    //Text(DateTime.now().isAfter(stringToDateTime(items[index].date, items[index].time)).toString())
                                    items[index].status != 1 &&
                                            items[index].date.isNotEmpty &&
                                            items[index].time.isNotEmpty &&
                                            DateTime.now().isAfter(
                                                stringToDateTime(
                                                    items[index].date,
                                                    items[index].time))
                                        ? const Icon(
                                            Icons.dangerous_outlined,
                                            color: Colors.red,
                                          )
                                        : items[index].status != 1 &&
                                                items[index].date.isNotEmpty &&
                                                items[index].time.isEmpty &&
                                                DateTime.now().isAfter(
                                                    DateTime.parse(
                                                        items[index].date))
                                            ? const Icon(
                                                Icons.dangerous_outlined,
                                                color: Colors.red,
                                              )
                                            : items[index].status != 1
                                                ? const Icon(Icons.check_outlined)
                                                : const Icon(
                                                    Icons.check,
                                                    color: Colors.green,
                                                  )
                                  ],
                                ),
                                items[index].date.isNotEmpty ||
                                        items[index].time.isNotEmpty
                                    ? Row(
                                        children: [
                                          Text(
                                            "${items[index].date}  ${items[index].time}",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.normal,
                                                fontSize: 16),
                                          )
                                        ],
                                      )
                                    : const Row()
                              ],
                            ),
                            subtitle: items[index].desc.isNotEmpty
                                ? Text(items[index].desc)
                                : null,
                            isThreeLine: false,
                          ),
                        ),
                      );
                    },
                  ),
            appBar: AppBar(
              backgroundColor: colorProvider.appBarBackground,
              title: Text(
                "ToDo",
                style: TextStyle(
                  fontSize: 30,
                  color: colorProvider.appTitle,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                Row(
                  children: [
                    GestureDetector(
                      child: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        backgroundImage: user.first.pic
                                    .substring(0, 1)
                                    .compareTo("0") ==
                                0
                            ? AssetImage(IconProvider.getAvatar(user.first.pic))
                            : FileImage(File(user.first.pic)),
                        radius: 18,
                      ),
                      onTap: () {
                        showDialog(
                            useRootNavigator: true,
                            context: context,
                            builder: (e) {
                              return AlertDialog(
                                backgroundColor:
                                    colorProvider.profileAlertBackground,
                                title: CircleAvatar(
                                  radius:
                                      MediaQuery.of(context).size.height > 700
                                          ? 130
                                          : 40,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: user.first.pic
                                              .substring(0, 1)
                                              .compareTo("0") ==
                                          0
                                      ? AssetImage(IconProvider.getAvatar(
                                          user.first.pic))
                                      : FileImage(File(user.first.pic)),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Expanded(
                                            child: Text(
                                          "${user.first.firstName} ${user.first.lastName}",
                                          maxLines: 2,
                                          overflow: TextOverflow.clip,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 42),
                                        ))
                                      ],
                                    ),
                                    const Padding(
                                        padding: EdgeInsets.only(bottom: 10)),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  user.first.theme == 0
                                                      ? Colors.white
                                                      : Colors.black12,
                                            ),
                                            onPressed: () {
                                              if (user.first.theme == 0) {
                                                user.first.theme = 1;
                                                DatabaseService()
                                                    .updateUser(user.first)
                                                    .then((onValue) {
                                                  getUser();
                                                });
                                              } else {
                                                user.first.theme = 0;
                                                DatabaseService()
                                                    .updateUser(user.first)
                                                    .then((onValue) {
                                                  getUser();
                                                });
                                              }
                                              Navigator.pop(context);
                                            },
                                            child: Icon(
                                              user.first.theme==1?
                                                Icons.dark_mode_sharp:Icons.light_mode_sharp)),
                                        const Padding(
                                            padding:
                                                EdgeInsets.only(right: 30)),
                                        ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                PageRouteBuilder(
                                                  pageBuilder: (context, animation, secondaryAnimation) => ProfilePage(user: user.first),
                                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                    const begin = Offset(0.0, 1.0);
                                                    const end = Offset.zero;
                                                    const curve = Curves.ease;
                                                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                                    var offsetAnimation = animation.drive(tween);
                                                    return SlideTransition(position: offsetAnimation, child: child);
                                                  },
                                                ),
                                              ).then((e){
                                                setState(() {
                                                  getUser();
                                                });
                                              });
                                            },
                                            child: const Icon(Icons.edit))
                                      ],
                                    )
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
  }
}
