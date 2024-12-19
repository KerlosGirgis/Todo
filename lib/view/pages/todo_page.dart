import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/view/pages/notes_page.dart';
import 'package:todo/provider/tasks_provider.dart';
import 'package:todo/provider/user_provider.dart';
import 'package:todo/view/pages/profile_page.dart';
import 'package:todo/view/widgets/add_task_dialog.dart';
import '../widgets/appbar_avatar.dart';
import '../widgets/update_task_dialog.dart';

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

  @override
  Widget build(BuildContext context) {
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
                      return const AddTaskDialog();
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
                  : AnimationLimiter(
                    child: Theme(
                        data: ThemeData(canvasColor: Colors.transparent),
                        child: ReorderableListView.builder(
                          itemCount: tasks.items.length,
                          itemBuilder: (context, index) {
                            final taskKey = tasks.items[index].id.toString();
                            return AnimationConfiguration.staggeredList(
                              key: Key(taskKey),
                              duration: const Duration(milliseconds: 750),
                              position: index,
                              child: SlideAnimation(
                                verticalOffset: 400,
                                child: FadeInAnimation(
                                  child: Dismissible(
                                    onDismissed: (direction) async {
                                      Provider.of<TasksProvider>(context, listen: false)
                                          .dismissTask(index, tasks.items[index].id!)
                                          .then((value) async {
                                        Fluttertoast.showToast(
                                            msg: "Task Deleted",
                                            toastLength: Toast.LENGTH_SHORT,
                                            gravity: ToastGravity.BOTTOM,
                                            backgroundColor:
                                                user.colorProvider.cardBackground,
                                            textColor: user.colorProvider.appTitle,
                                            fontSize: 19.0);
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
                                                        style: tasks.items[index]
                                                                    .status ==
                                                                0
                                                            ? TextStyle(
                                                                fontSize: 26,
                                                                color:
                                                                    user.colorProvider
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
                                                      showDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            return UpdateTaskDialog(index: index,);
                                                          });
                                                    },
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
                                                          Fluttertoast.showToast(
                                                              msg: "Task done",
                                                              toastLength:
                                                                  Toast.LENGTH_SHORT,
                                                              gravity:
                                                                  ToastGravity.BOTTOM,
                                                              backgroundColor:
                                                                  Colors.green,
                                                              textColor: Colors.white,
                                                              fontSize: 19.0);
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
                                                          Fluttertoast.showToast(
                                                              msg: "Task undone",
                                                              toastLength:
                                                                  Toast.LENGTH_SHORT,
                                                              gravity:
                                                                  ToastGravity.BOTTOM,
                                                              backgroundColor: user
                                                                  .colorProvider
                                                                  .cardBackground,
                                                              textColor: user
                                                                  .colorProvider
                                                                  .appTitle,
                                                              fontSize: 19.0);
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ),
                                                const Padding(
                                                    padding:
                                                        EdgeInsets.only(right: 10)),
                                                tasks.items[index].status == 1?
                                                const Icon(
                                                  Icons.check,
                                                  color: Colors.green,
                                                ):const Icon(
                                                  Icons.check_outlined,
                                                  color: Colors.grey,
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
                                                                tasks.items[index].status==0?user.colorProvider.date:Colors.grey,
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
                                                    color: tasks.items[index].status==0?user.colorProvider.subtitle:Colors.grey),
                                              )
                                            : null,
                                        isThreeLine: false,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          onReorder: (int oldIndex, int newIndex) async {
                            Provider.of<TasksProvider>(context, listen: false)
                                .syncAfterReorder(oldIndex, newIndex);
                          },
                        ),
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
                  IconButton(onPressed: () async {
                    Provider.of<TasksProvider>(context, listen: false).backup();
                  }, icon: const Icon(Icons.backup,color: Colors.grey,)),
                  IconButton(onPressed: () async {
                    Provider.of<TasksProvider>(context, listen: false).restore();
                  }, icon: const Icon(Icons.settings_backup_restore,color: Colors.grey,)),
                  IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const ProfilePage(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
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
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.grey,
                      )),
                  const AppbarAvatar(),
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


