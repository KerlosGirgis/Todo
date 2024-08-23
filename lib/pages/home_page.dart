import 'dart:io';

import 'package:flutter/material.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/pages/profile_page.dart';
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
  bool isLoading = false;
  void getItems() async {
    setState(() {
      isLoading = true;
    });
    items = await DatabaseService().getItems();
    user = await DatabaseService().getUser();
    if (user.isEmpty) {
      await DatabaseService()
          .insertUser(UserProfile(firstName: "user", lastName: "", pic: "0"));
      user = await DatabaseService().getUser();
    }
    setState(() {
      isLoading = false;
    });
  }

  TextEditingController titleController = TextEditingController();
  TextEditingController descController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return isLoading==true? const Scaffold(body: Center(
      child: CircularProgressIndicator(),
    ),) : Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Add Task"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Title"),
                    ),
                    TextField(
                      controller: descController,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration:
                          const InputDecoration(labelText: "Description"),
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
                    return ListTile(
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
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: titleController,
                                            decoration: const InputDecoration(
                                                labelText: "Title"),
                                          ),
                                          TextField(
                                            controller: descController,
                                            keyboardType:
                                                TextInputType.multiline,
                                            maxLines: null,
                                            decoration: const InputDecoration(
                                                labelText: "Description"),
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
                                            if (titleController.text.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "Task title can't be empty"),
                                                duration: Durations.long4,
                                              ));
                                              return;
                                            }
                                            await DatabaseService()
                                                .updateItem(TodoItem(
                                                    title: titleController.text,
                                                    desc: descController.text,
                                                    id: items[index].id,
                                                    status:
                                                        items[index].status))
                                                .then((value) {
                                              getItems();
                                              titleController.clear();
                                              descController.clear();
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                content: Text("Task Updated"),
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
                    );
                  },
                ),
      appBar: AppBar(
        title: const Text(
          "ToDo",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Row(
            children: [
              GestureDetector(
                child: CircleAvatar(
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
                          backgroundColor: Colors.black.withOpacity(.5),
                          title: CircleAvatar(
                            radius: 130,
                            backgroundImage: user.first.pic.compareTo("0") == 0
                                ? const AssetImage("assets/avatar.png")
                                : FileImage(File(user.first.pic)),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "${user.first.firstName} ${user.first.lastName}",
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 42),
                                  )
                                ],
                              ),
                              const Padding(
                                  padding: EdgeInsets.only(bottom: 10)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                      onPressed: () {},
                                      child: const Icon(Icons.settings)),
                                  const Padding(
                                      padding: EdgeInsets.only(right: 30)),
                                  ElevatedButton(
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    ProfilePage(
                                                      user: user.first,
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
