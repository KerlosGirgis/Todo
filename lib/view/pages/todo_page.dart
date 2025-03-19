import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:todo/models/todo_item.dart';
import 'package:todo/view/pages/notes_page.dart';
import 'package:todo/provider/tasks_provider.dart';
import 'package:todo/provider/user_provider.dart';
import 'package:todo/view/pages/profile_page.dart';
import 'package:todo/view/widgets/add_task_dialog.dart';
import '../widgets/appbar_avatar.dart';
import '../widgets/expandable_menu.dart';
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
                  showGeneralDialog(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: MaterialLocalizations.of(context)
                        .modalBarrierDismissLabel,
                    pageBuilder: (BuildContext context,
                        Animation<double> animation,
                        Animation<double> secondaryAnimation) {
                      return AddTaskDialog();
                    },
                    transitionBuilder:
                        (context, animation, secondaryAnimation, child) {
                      var fadeAnimation = CurvedAnimation(
                          parent: animation, curve: Curves.easeInOutSine);
                      var scaleAnimation = Tween<double>(begin: 0.95, end: 1.0)
                          .animate(fadeAnimation); // Subtle grow
                      var slideAnimation = Tween<Offset>(
                              begin: Offset(0, 0.05), end: Offset.zero)
                          .animate(fadeAnimation); // Gentle rise

                      return FadeTransition(
                        opacity: fadeAnimation,
                        child: ScaleTransition(
                          scale: scaleAnimation,
                          child: SlideTransition(
                            position: slideAnimation,
                            child: child,
                          ),
                        ),
                      );
                    },
                  );
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
          body: SafeArea(
            child: Consumer<TasksProvider>(
              builder: (context, tasks, child) {
                return tasks.items.isEmpty
                    ? Center(
                        child: Image.asset(
                          "assets/empty_list.png",
                          scale: 2,
                        ),
                      )
                    : Theme(
                        data: ThemeData(
                            canvasColor: Colors.transparent,
                            useMaterial3: true,
                            colorScheme: ColorScheme.fromSeed(
                                seedColor: Colors.blue.shade300)),
                        child: ReorderableListView.builder(
                          itemCount: tasks.items.length,
                          itemBuilder: (context, index) {
                            final taskKey = tasks.items[index].id.toString();
                            return AnimationLimiter(
                              key: Key(taskKey),
                              child: AnimationConfiguration.staggeredList(
                                duration: const Duration(milliseconds: 400),
                                position: index,
                                child: SlideAnimation(
                                  verticalOffset: 300,
                                  child: FadeInAnimation(
                                    child: Dismissible(
                                      onDismissed: (direction) async {
                                        await Provider.of<TasksProvider>(
                                                context,
                                                listen: false)
                                            .dismissTask(
                                                index, tasks.items[index].id!)
                                            .then((value) {
                                          Fluttertoast.showToast(
                                              msg: "Task Deleted",
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.BOTTOM,
                                              backgroundColor:
                                                  const Color(0xff1E1E1E),
                                              textColor: Colors.white,
                                              fontSize: 19.0);
                                        });
                                      },
                                      key: Key(taskKey),
                                      child: Card(
                                        elevation: 3,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(25),
                                        ),
                                        color:
                                            user.colorProvider.cardBackground,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: GestureDetector(
                                                      child: AutoSizeText(
                                                        tasks
                                                            .items[index].title,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        minFontSize: 18,
                                                        style: tasks
                                                                    .items[
                                                                        index]
                                                                    .status ==
                                                                0
                                                            ? TextStyle(
                                                                fontSize: 26,
                                                                color: user
                                                                    .colorProvider
                                                                    .taskTitle,
                                                              )
                                                            : const TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                                fontSize: 26,
                                                                decoration:
                                                                    TextDecoration
                                                                        .lineThrough,
                                                                decorationThickness:
                                                                    3,
                                                              ),
                                                      ),
                                                      onLongPress: () {
                                                        showGeneralDialog(
                                                          context: context,
                                                          barrierDismissible: true,
                                                          barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                                                          pageBuilder: (BuildContext
                                                                  context,
                                                              Animation<double>
                                                                  animation,
                                                              Animation<double>
                                                                  secondaryAnimation) {
                                                            return UpdateTaskDialog(
                                                                index: index);
                                                          },
                                                          transitionBuilder:
                                                              (context, animation, secondaryAnimation, child) {
                                                            var fadeAnimation = CurvedAnimation(
                                                                parent: animation, curve: Curves.easeInOutSine);
                                                            var scaleAnimation =
                                                            Tween<double>(begin: 0.2, end: 1).animate(fadeAnimation);
                                                            return FadeTransition(
                                                              opacity: fadeAnimation,
                                                              child: ScaleTransition(
                                                                scale: scaleAnimation,
                                                                child: child,
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      },
                                                      onTap: () async {
                                                        if (tasks.items[index]
                                                                .status ==
                                                            0) {
                                                          if (tasks.items[index]
                                                                  .notification ==
                                                              1) {
                                                            tasks
                                                                .cancelNotification(
                                                                    index);
                                                            if (context
                                                                .mounted) {
                                                              Provider.of<TasksProvider>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .updateTask(
                                                                TodoItem(
                                                                  title: tasks
                                                                      .items[
                                                                          index]
                                                                      .title,
                                                                  desc: tasks
                                                                      .items[
                                                                          index]
                                                                      .desc,
                                                                  id: tasks
                                                                      .items[
                                                                          index]
                                                                      .id,
                                                                  status: 1,
                                                                  date: tasks
                                                                      .items[
                                                                          index]
                                                                      .date,
                                                                  time: tasks
                                                                      .items[
                                                                          index]
                                                                      .time,
                                                                  uuid: tasks
                                                                      .items[
                                                                          index]
                                                                      .uuid,
                                                                  notification:
                                                                      0,
                                                                ),
                                                              )
                                                                  .then(
                                                                      (value) {
                                                                user.increaseFinished();
                                                                Fluttertoast
                                                                    .showToast(
                                                                  msg:
                                                                      "Task done",
                                                                  toastLength: Toast
                                                                      .LENGTH_SHORT,
                                                                  gravity:
                                                                      ToastGravity
                                                                          .BOTTOM,
                                                                  backgroundColor:
                                                                      Colors
                                                                          .green,
                                                                  textColor:
                                                                      Colors
                                                                          .white,
                                                                  fontSize:
                                                                      19.0,
                                                                );
                                                              });
                                                            }
                                                          } else {
                                                            Provider.of<TasksProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .updateTask(
                                                              TodoItem(
                                                                title: tasks
                                                                    .items[
                                                                        index]
                                                                    .title,
                                                                desc: tasks
                                                                    .items[
                                                                        index]
                                                                    .desc,
                                                                id: tasks
                                                                    .items[
                                                                        index]
                                                                    .id,
                                                                status: 1,
                                                                date: tasks
                                                                    .items[
                                                                        index]
                                                                    .date,
                                                                time: tasks
                                                                    .items[
                                                                        index]
                                                                    .time,
                                                                uuid: tasks
                                                                    .items[
                                                                        index]
                                                                    .uuid,
                                                                notification: tasks
                                                                    .items[
                                                                        index]
                                                                    .notification,
                                                              ),
                                                            )
                                                                .then((value) {
                                                              user.increaseFinished();
                                                              Fluttertoast
                                                                  .showToast(
                                                                msg:
                                                                    "Task done",
                                                                toastLength: Toast
                                                                    .LENGTH_SHORT,
                                                                gravity:
                                                                    ToastGravity
                                                                        .BOTTOM,
                                                                backgroundColor:
                                                                    Colors
                                                                        .green,
                                                                textColor:
                                                                    Colors
                                                                        .white,
                                                                fontSize: 19.0,
                                                              );
                                                            });
                                                          }
                                                        } else {
                                                          Provider.of<TasksProvider>(
                                                                  context,
                                                                  listen: false)
                                                              .updateTask(
                                                            TodoItem(
                                                              title: tasks
                                                                  .items[index]
                                                                  .title,
                                                              desc: tasks
                                                                  .items[index]
                                                                  .desc,
                                                              id: tasks
                                                                  .items[index]
                                                                  .id,
                                                              status: 0,
                                                              date: tasks
                                                                  .items[index]
                                                                  .date,
                                                              time: tasks
                                                                  .items[index]
                                                                  .time,
                                                              uuid: tasks
                                                                  .items[index]
                                                                  .uuid,
                                                              notification: tasks
                                                                  .items[index]
                                                                  .notification,
                                                            ),
                                                          )
                                                              .then((value) {
                                                            user.decreaseFinished();
                                                            Fluttertoast
                                                                .showToast(
                                                              msg:
                                                                  "Task undone",
                                                              toastLength: Toast
                                                                  .LENGTH_SHORT,
                                                              gravity:
                                                                  ToastGravity
                                                                      .BOTTOM,
                                                              backgroundColor:
                                                                  const Color(
                                                                      0xff1E1E1E),
                                                              textColor:
                                                                  Colors.white,
                                                              fontSize: 19.0,
                                                            );
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  const Padding(
                                                      padding: EdgeInsets.only(
                                                          right: 10)),
                                                  tasks.items[index].status == 0
                                                      ? tasks.items[index]
                                                                  .notification ==
                                                              1
                                                          ? IconButton(
                                                              icon: const Icon(
                                                                Icons
                                                                    .notifications,
                                                                color:
                                                                    Colors.blue,
                                                              ),
                                                              onPressed: () {
                                                                tasks
                                                                    .changeNotification(
                                                                        index);
                                                              },
                                                            )
                                                          : IconButton(
                                                              icon: const Icon(
                                                                Icons
                                                                    .notifications,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                              onPressed: () {
                                                                tasks
                                                                    .changeNotification(
                                                                        index);
                                                              },
                                                            )
                                                      : const SizedBox.shrink(),
                                                  const Padding(
                                                      padding: EdgeInsets.only(
                                                          right: 10)),
                                                  tasks.items[index].status == 1
                                                      ? const Icon(
                                                          Icons.check,
                                                          color: Colors.green,
                                                        )
                                                      : const Icon(
                                                          Icons.check_outlined,
                                                          color: Colors.grey,
                                                        ),
                                                ],
                                              ),
                                              tasks.items[index].desc.isNotEmpty
                                                  ? Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 2.0),
                                                      child: ReadMoreText(
                                                        moreStyle: TextStyle(
                                                            color: user
                                                                .colorProvider
                                                                .moreLess),
                                                        trimExpandedText:
                                                            " Show Less",
                                                        trimCollapsedText:
                                                            "Show More",
                                                        lessStyle: TextStyle(
                                                            color: user
                                                                .colorProvider
                                                                .moreLess),
                                                        trimLines: 2,
                                                        trimMode: TrimMode.Line,
                                                        tasks.items[index].desc,
                                                        style: TextStyle(
                                                          fontSize: 20,
                                                          color: tasks
                                                                      .items[
                                                                          index]
                                                                      .status ==
                                                                  0
                                                              ? user
                                                                  .colorProvider
                                                                  .subtitle
                                                              : Colors.grey,
                                                        ),
                                                      ),
                                                    )
                                                  : const SizedBox.shrink(),
                                              tasks.items[index].date
                                                          .isNotEmpty ||
                                                      tasks.items[index].time
                                                          .isNotEmpty
                                                  ? Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 7.0),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.date_range,
                                                            color: tasks
                                                                        .items[
                                                                            index]
                                                                        .status ==
                                                                    0
                                                                ? user
                                                                    .colorProvider
                                                                    .appTitle
                                                                : Colors.grey,
                                                          ),
                                                          Flexible(
                                                            child: Text(
                                                              " ${tasks.items[index].date} ",
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                color: tasks
                                                                            .items[
                                                                                index]
                                                                            .status ==
                                                                        0
                                                                    ? user
                                                                        .colorProvider
                                                                        .date
                                                                    : Colors
                                                                        .grey,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                          ),
                                                          tasks
                                                                  .items[index]
                                                                  .time
                                                                  .isNotEmpty
                                                              ? Icon(
                                                                  Icons
                                                                      .access_time_filled_sharp,
                                                                  color: tasks
                                                                              .items[
                                                                                  index]
                                                                              .status ==
                                                                          0
                                                                      ? user
                                                                          .colorProvider
                                                                          .appTitle
                                                                      : Colors
                                                                          .grey,
                                                                )
                                                              : const SizedBox
                                                                  .shrink(),
                                                          Flexible(
                                                            child: Text(
                                                              " ${tasks.items[index].time}",
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                color: tasks
                                                                            .items[
                                                                                index]
                                                                            .status ==
                                                                        0
                                                                    ? user
                                                                        .colorProvider
                                                                        .date
                                                                    : Colors
                                                                        .grey,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  : const SizedBox.shrink(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          onReorder: (int oldIndex, int newIndex) async {
                            await Provider.of<TasksProvider>(context,
                                    listen: false)
                                .syncAfterReorder(oldIndex, newIndex);
                          },
                        ),
                      );
              },
            ),
          ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: user.colorProvider.pageBackground,
            surfaceTintColor: Colors.transparent,
            title: Text(
              "ToDo",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 30,
                color: user.colorProvider.appTitle,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              ExpandableMenu(
                iconColor: user.colorProvider.appBarIcons,
                animationSpeed: 500,
                width: MediaQuery.orientationOf(context) == Orientation.portrait
                    ? MediaQuery.sizeOf(context).width / 14
                    : MediaQuery.sizeOf(context).width / 30,
                height: 45,
                items: [
                  IconButton(
                      onPressed: () async {
                        Provider.of<TasksProvider>(context, listen: false)
                            .restore();
                      },
                      icon: Icon(
                        Icons.settings_backup_restore,
                        color: user.colorProvider.appBarIcons,
                      )),
                  IconButton(
                      onPressed: () async {
                        Provider.of<TasksProvider>(context, listen: false)
                            .backup();
                      },
                      icon: Icon(
                        Icons.backup,
                        color: user.colorProvider.appBarIcons,
                      )),
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
                      icon: Icon(
                        Icons.settings,
                        color: user.colorProvider.appBarIcons,
                      )),
                ],
              ),
              Flexible(child: const AppbarAvatar()),
              const Padding(padding: EdgeInsets.only(right: 18))
            ],
          ),
        );
      },
    );
  }
}
