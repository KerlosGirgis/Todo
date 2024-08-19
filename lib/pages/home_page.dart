import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/services/database_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? imageFile;

  //final picker = ImagePicker();
  pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kDebugMode) {
        print("file returned");
      }
      return File(pickedFile.path);
    }
    return null;
  }

  saveImageToAppStorage(File image) async {
    final appDir = await getApplicationDocumentsDirectory();

    final fileName = image.path.split('/').last;

    final savedImage = await image.copy('${appDir.path}/$fileName');

    return savedImage;
  }

  _pickAndSaveImage() async {
    final image = await pickImage();
    if (image != null) {
      final savedImage = await saveImageToAppStorage(image);
      setState(() {
        imageFile = savedImage;
      });
    }
  }

  @override
  void initState() {
    getItems();
    super.initState();
  }

  List<TodoItem> items = [];
  bool isLoading = false;
  void getItems() async {
    isLoading = true;
    setState(() {});
    items = await DatabaseService().getItems();
    setState(() {
      isLoading = false;
    });
  }

  TextEditingController titleController = TextEditingController();
  TextEditingController descController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : items.isEmpty
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
                                                          "Task title can't be empty")));
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
                                                      content: Text(
                                                          "Task Updated")));
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("Task Deleted")));
                              });
                            },
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      leading: InkWell(
                        child: Text(
                          items[index].id.toString(),
                        ),
                      ),
                      title: InkWell(
                        child: Text(items[index].title,
                            style: items[index].status == 0
                                ? const TextStyle()
                                : const TextStyle(
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Task done")));
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Task undone")));
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
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Row(
            children: [
              CircleAvatar(
                child: IconButton(
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (e) {
                          return AlertDialog(
                            backgroundColor: Colors.black.withOpacity(.5),
                            title: imageFile != null
                                ? CircleAvatar(
                                    backgroundImage: FileImage(imageFile!),
                                    radius: 100,
                                  )
                                : Image.asset("assets/avatar.png"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Kerlos",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 42),
                                    )
                                  ],
                                ),
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
                                          _pickAndSaveImage();
                                        },
                                        child: const Icon(Icons.edit))
                                  ],
                                )
                              ],
                            ),
                          );
                        });
                  },
                  icon: Image.asset(
                    "assets/avatar.png",
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.only(right: 15))
            ],
          )
        ],
      ),
    );
  }
}
