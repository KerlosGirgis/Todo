import 'dart:io';
import 'package:flutter/material.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/pages/profile_page.dart';
import 'package:todo/services/color_provider.dart';
import 'package:todo/services/database_service.dart';

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
    super.initState();
  }

  List<TodoItem> items = [];
  List<UserProfile> user = [];
  late ColorProvider colorProvider;
  bool isLoading = false;
  void getItems() async {
    setState(() {
      isLoading = true;
    });
    items = await DatabaseService().getItems();
    user = await DatabaseService().getUser();
    if (user.isEmpty) {
      await DatabaseService().insertUser(
          UserProfile(firstName: "user", lastName: "", pic: "0", theme: 1));
      user = await DatabaseService().getUser();
    }
    colorProvider = ColorProvider(user.first.theme);
    setState(() {
      isLoading = false;
    });
  }

  TextEditingController titleController = TextEditingController();
  TextEditingController descController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return isLoading == true
        ? const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          )
        : Scaffold(
            backgroundColor: colorProvider.homePageBackground,
            //user.first.theme == 0 ? Colors.white : Colors.black12,
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    //add task
                    return AlertDialog(
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
                            decoration: InputDecoration(
                                labelText: "Title",
                                labelStyle: TextStyle(
                                    fontSize: 30,
                                    color: colorProvider.addTaskAlertText)),
                          ),
                          TextField(
                            controller: descController,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            decoration: InputDecoration(
                                labelText: "Description",
                                labelStyle: TextStyle(
                                    fontSize: 30,
                                    color: colorProvider.addTaskAlertText)),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
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
                                  status: 0),
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
                getItems();
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
                      return Card(
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
                                                maxLines: null,
                                                decoration: InputDecoration(
                                                    labelText: "Description",
                                                    labelStyle: TextStyle(
                                                        fontSize: 30,
                                                        color: colorProvider
                                                            .addTaskAlertText)),
                                              ),
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
                                                        status: items[index]
                                                            .status))
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
                                      .then((value) {
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
                          title: InkWell(
                            child: Text(items[index].title,
                                style: items[index].status == 0
                                    ? const TextStyle(fontSize: 22)
                                    : const TextStyle(
                                        fontSize: 22,
                                        decoration: TextDecoration.lineThrough,
                                        decorationThickness: 3)),
                            onTap: () async {
                              if (items[index].status == 0) {
                                await DatabaseService()
                                    .updateItem(TodoItem(
                                        title: items[index].title,
                                        desc: items[index].desc,
                                        id: items[index].id,
                                        status: 1))
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
                                        status: 0))
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
                          subtitle: items[index].desc.isNotEmpty
                              ? Text(items[index].desc)
                              : null,
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
                        backgroundImage: user.first.pic.compareTo("0") == 0
                            ? const AssetImage("assets/avatar.png")
                            : FileImage(File(user.first.pic)),
                        radius: 18,
                      ),
                      onTap: () {
                        showDialog(
                            useRootNavigator: true,
                            context: context,
                            builder: (e) {
                              return AlertDialog(
                                backgroundColor: Colors.grey.withOpacity(.3),
                                title: CircleAvatar(
                                  radius: 130,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: user.first.pic
                                              .compareTo("0") ==
                                          0
                                      ? const AssetImage("assets/avatar.png")
                                      : FileImage(File(user.first.pic)),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${user.first.firstName} ${user.first.lastName}",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 42),
                                        )
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
                                                  getItems();
                                                });
                                              } else {
                                                user.first.theme = 0;
                                                DatabaseService()
                                                    .updateUser(user.first)
                                                    .then((onValue) {
                                                  getItems();
                                                });
                                              }
                                              Navigator.pop(context);
                                            },
                                            child: const Icon(
                                                Icons.dark_mode_sharp)),
                                        const Padding(
                                            padding:
                                                EdgeInsets.only(right: 30)),
                                        ElevatedButton(
                                            onPressed: () {
                                              Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          ProfilePage(
                                                            user: user.first,
                                                            colorProvider:
                                                                colorProvider,
                                                          ))).then((e) {
                                                setState(() {
                                                  getItems();
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
