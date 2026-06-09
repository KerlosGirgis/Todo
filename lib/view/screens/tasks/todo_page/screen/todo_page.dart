import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:todo/core/result.dart';
import 'package:todo/view/screens/notes/notes_page/screen/notes_page.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/tasks_overwrite_dialog.dart';
import 'package:todo/view_model/tasks_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:todo/view/screens/profile/profile_page/screen/profile_page.dart';
import 'package:todo/view/screens/tasks/todo_page/widgets/add_task_dialog.dart';
import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/task_filters.dart';
import '../../../../widgets/appbar_avatar.dart';
import '../../../../widgets/expandable_menu.dart';
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
      Provider.of<TasksViewModel>(context, listen: false).get();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(
      builder: (context, user, child) {
        return Scaffold(
          backgroundColor: context.colors.pageBackground,
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                  heroTag: 0,
                  backgroundColor:
                      context.colors.floatingActionButtonBackground,
                  foregroundColor:
                      context.colors.floatingActionButtonForeground,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const NotesPage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(-1.0, 0.0);
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
                backgroundColor: context.colors.floatingActionButtonBackground,
                foregroundColor: context.colors.floatingActionButtonForeground,
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
            child: Consumer<TasksViewModel>(
              builder: (context, tasks, child) {
                return Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: Colors.transparent,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: Row(
                                spacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: Text("All"),
                                    selected:
                                        tasks.currentFilter.runtimeType ==
                                            AllTasksFilter().runtimeType,
                                    onSelected: (selected) {
                                      if (selected) {
                                        tasks.fetchTasks(
                                            filter: AllTasksFilter());
                                      }
                                    },
                                    selectedColor: context.colors
                                        .floatingActionButtonBackground,
                                    labelStyle: TextStyle(
                                      color: tasks.currentFilter
                                                  .runtimeType ==
                                              AllTasksFilter().runtimeType
                                          ? context.colors
                                              .floatingActionButtonForeground
                                          : context.colors.wB,
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: Text("Done"),
                                    selected:
                                        tasks.currentFilter.runtimeType ==
                                            DoneTasksFilter().runtimeType,
                                    onSelected: (selected) {
                                      if (selected) {
                                        tasks.fetchTasks(
                                            filter: DoneTasksFilter());
                                      }
                                    },
                                    selectedColor: context.colors
                                        .floatingActionButtonBackground,
                                    labelStyle: TextStyle(
                                      color: tasks.currentFilter
                                                  .runtimeType ==
                                              DoneTasksFilter().runtimeType
                                          ? context.colors
                                              .floatingActionButtonForeground
                                          : context.colors.wB,
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: Text("Undone"),
                                    selected:
                                        tasks.currentFilter.runtimeType ==
                                            UndoneTasksFilter().runtimeType,
                                    onSelected: (selected) {
                                      if (selected) {
                                        tasks.fetchTasks(
                                            filter: UndoneTasksFilter());
                                      }
                                    },
                                    selectedColor: context.colors
                                        .floatingActionButtonBackground,
                                    labelStyle: TextStyle(
                                      color: tasks.currentFilter
                                                  .runtimeType ==
                                              UndoneTasksFilter().runtimeType
                                          ? context.colors
                                              .floatingActionButtonForeground
                                          : context.colors.wB,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            tasks.items.isEmpty
                                ? Expanded(
                              child: Image.asset(
                                "assets/empty_list.png",
                                scale: 2,
                              ),
                            )
                                : Expanded(
                              child: ReorderableListView.builder(
                                itemCount: tasks.items.length,
                                itemBuilder: (context, index) {
                                  final taskKey =
                                      tasks.items[index].id.toString();
                                  return AnimationLimiter(
                                    key: Key(taskKey),
                                    child:
                                        AnimationConfiguration.staggeredList(
                                      duration:
                                          const Duration(milliseconds: 400),
                                      position: index,
                                      child: SlideAnimation(
                                        verticalOffset: 300,
                                        child: FadeInAnimation(
                                          child: Dismissible(
                                            onDismissed: (direction) async {
                                              await Provider.of<
                                                          TasksViewModel>(
                                                      context,
                                                      listen: false)
                                                  .dismissTask(index,
                                                      tasks.items[index].id!)
                                                  .then((value) {
                                                FeedbackToast.info(
                                                    "Task Deleted");
                                              });
                                            },
                                            key: Key(taskKey),
                                            child: Card(
                                              elevation: 3,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(25),
                                              ),
                                              color: context
                                                  .colors.cardBackground,
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                    16.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child:
                                                              GestureDetector(
                                                            child:
                                                                AutoSizeText(
                                                              tasks
                                                                  .items[
                                                                      index]
                                                                  .title,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              minFontSize: 18,
                                                              style: tasks.items[index]
                                                                          .status ==
                                                                      0
                                                                  ? TextStyle(
                                                                      fontSize:
                                                                          26 *
                                                                              user.user.tasksTitleSize,
                                                                      color: context
                                                                          .colors
                                                                          .wB,
                                                                    )
                                                                  : TextStyle(
                                                                      color: Colors
                                                                          .grey,
                                                                      fontSize:
                                                                          26 *
                                                                              user.user.tasksTitleSize,
                                                                      decoration:
                                                                          TextDecoration.lineThrough,
                                                                      decorationThickness:
                                                                          3,
                                                                    ),
                                                            ),
                                                            onLongPress: () {
                                                              showGeneralDialog(
                                                                context:
                                                                    context,
                                                                barrierDismissible:
                                                                    true,
                                                                barrierLabel:
                                                                    MaterialLocalizations.of(
                                                                            context)
                                                                        .modalBarrierDismissLabel,
                                                                pageBuilder: (BuildContext context,
                                                                    Animation<
                                                                            double>
                                                                        animation,
                                                                    Animation<
                                                                            double>
                                                                        secondaryAnimation) {
                                                                  return UpdateTaskDialog(
                                                                      index:
                                                                          index);
                                                                },
                                                                transitionBuilder: (context,
                                                                    animation,
                                                                    secondaryAnimation,
                                                                    child) {
                                                                  var fadeAnimation = CurvedAnimation(
                                                                      parent:
                                                                          animation,
                                                                      curve: Curves
                                                                          .easeInOutSine);
                                                                  var scaleAnimation = Tween<double>(
                                                                          begin:
                                                                              0.8,
                                                                          end:
                                                                              1)
                                                                      .animate(
                                                                          fadeAnimation);
                                                                  return FadeTransition(
                                                                    opacity:
                                                                        fadeAnimation,
                                                                    child:
                                                                        ScaleTransition(
                                                                      scale:
                                                                          scaleAnimation,
                                                                      child:
                                                                          child,
                                                                    ),
                                                                  );
                                                                },
                                                              );
                                                            },
                                                            onTap: () {
                                                              tasks
                                                                  .markAsDone(
                                                                      index,
                                                                      user)
                                                                  .then(
                                                                      (result) {
                                                                if (result
                                                                    is Success) {
                                                                  FeedbackToast
                                                                      .success(
                                                                          result.message);
                                                                } else if (result
                                                                    is Failure) {
                                                                  FeedbackToast
                                                                      .error(result
                                                                          .message);
                                                                } else if (result
                                                                    is Info) {
                                                                  FeedbackToast
                                                                      .info(result
                                                                          .message);
                                                                }
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                        const Padding(
                                                            padding: EdgeInsets
                                                                .only(
                                                                    right:
                                                                        10)),
                                                        tasks.items[index]
                                                                    .status ==
                                                                0
                                                            ? tasks.items[index].notification ==
                                                                        1 ||
                                                                    tasks.items[index].notification ==
                                                                        2
                                                                ? IconButton(
                                                                    icon:
                                                                        const Icon(
                                                                      Icons
                                                                          .notifications,
                                                                      color: Colors
                                                                          .blue,
                                                                    ),
                                                                    onPressed:
                                                                        () {
                                                                      tasks
                                                                          .cancelNotification(tasks.items[index])
                                                                          .then((result) {
                                                                        if (result
                                                                            is Success) {
                                                                          FeedbackToast.success(result.message);
                                                                        } else if (result
                                                                            is Failure) {
                                                                          FeedbackToast.error(result.message);
                                                                        } else if (result
                                                                            is Info) {
                                                                          FeedbackToast.info(result.message);
                                                                        }
                                                                      });
                                                                    },
                                                                  )
                                                                : IconButton(
                                                                    icon:
                                                                        const Icon(
                                                                      Icons
                                                                          .notifications,
                                                                      color: Colors
                                                                          .grey,
                                                                    ),
                                                                    onPressed:
                                                                        () {
                                                                      tasks
                                                                          .enableOneTimeNotification(tasks.items[index])
                                                                          .then((result) {
                                                                        if (result
                                                                            is Success) {
                                                                          FeedbackToast.success(result.message);
                                                                        } else if (result
                                                                            is Failure) {
                                                                          FeedbackToast.error(result.message);
                                                                        } else if (result
                                                                            is Info) {
                                                                          FeedbackToast.info(result.message);
                                                                        }
                                                                      });
                                                                    },
                                                                    onLongPress:
                                                                        () {
                                                                      tasks
                                                                          .enableDailyNotification(tasks.items[index])
                                                                          .then((result) {
                                                                        if (result
                                                                            is Success) {
                                                                          FeedbackToast.success(result.message);
                                                                        } else if (result
                                                                            is Failure) {
                                                                          FeedbackToast.error(result.message);
                                                                        } else if (result
                                                                            is Info) {
                                                                          FeedbackToast.info(result.message);
                                                                        }
                                                                      });
                                                                    },
                                                                  )
                                                            : const SizedBox
                                                                .shrink(),
                                                        const Padding(
                                                            padding: EdgeInsets
                                                                .only(
                                                                    right:
                                                                        10)),
                                                        tasks.items[index]
                                                                    .status ==
                                                                1
                                                            ? const Icon(
                                                                Icons.check,
                                                                color: Colors
                                                                    .green,
                                                              )
                                                            : const Icon(
                                                                Icons
                                                                    .check_outlined,
                                                                color: Colors
                                                                    .grey,
                                                              ),
                                                      ],
                                                    ),
                                                    tasks.items[index].desc
                                                            .isNotEmpty
                                                        ? Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 2.0),
                                                            child: user.user
                                                                        .descLines !=
                                                                    0
                                                                ? ReadMoreText(
                                                                    moreStyle: TextStyle(
                                                                        color: context
                                                                            .colors
                                                                            .moreLess),
                                                                    trimExpandedText:
                                                                        " Show Less",
                                                                    trimCollapsedText:
                                                                        "Show More",
                                                                    lessStyle: TextStyle(
                                                                        color: context
                                                                            .colors
                                                                            .moreLess),
                                                                    trimLines: user
                                                                        .user
                                                                        .descLines,
                                                                    trimMode:
                                                                        TrimMode
                                                                            .Line,
                                                                    tasks
                                                                        .items[
                                                                            index]
                                                                        .desc,
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          20 *
                                                                              user.user.tasksDescSize,
                                                                      color: tasks.items[index].status ==
                                                                              0
                                                                          ? context.colors.subtitle
                                                                          : Colors.grey,
                                                                    ),
                                                                  )
                                                                : Text(
                                                                    tasks
                                                                        .items[
                                                                            index]
                                                                        .desc,
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          20 *
                                                                              user.user.tasksDescSize,
                                                                      color: tasks.items[index].status ==
                                                                              0
                                                                          ? context.colors.subtitle
                                                                          : Colors.grey,
                                                                    ),
                                                                  ),
                                                          )
                                                        : const SizedBox
                                                            .shrink(),
                                                    tasks.items[index].date
                                                                .isNotEmpty ||
                                                            tasks
                                                                .items[index]
                                                                .time
                                                                .isNotEmpty
                                                        ? Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 7.0),
                                                            child: Row(
                                                              children: [
                                                                tasks
                                                                        .items[
                                                                            index]
                                                                        .date
                                                                        .isNotEmpty
                                                                    ? Icon(
                                                                        Icons
                                                                            .date_range,
                                                                        color: tasks.items[index].status == 0
                                                                            ? context.colors.wB
                                                                            : Colors.grey,
                                                                      )
                                                                    : SizedBox
                                                                        .shrink(),
                                                                tasks
                                                                        .items[
                                                                            index]
                                                                        .date
                                                                        .isNotEmpty
                                                                    ? Flexible(
                                                                        child:
                                                                            Text(
                                                                          " ${tasks.items[index].date} ",
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                          style:
                                                                              TextStyle(
                                                                            color: tasks.items[index].status == 0 ? context.colors.wB : Colors.grey,
                                                                            fontWeight: FontWeight.normal,
                                                                            fontSize: 16,
                                                                          ),
                                                                        ),
                                                                      )
                                                                    : SizedBox
                                                                        .shrink(),
                                                                tasks
                                                                        .items[
                                                                            index]
                                                                        .time
                                                                        .isNotEmpty
                                                                    ? Icon(
                                                                        Icons
                                                                            .access_time_filled_sharp,
                                                                        color: tasks.items[index].status == 0
                                                                            ? context.colors.wB
                                                                            : Colors.grey,
                                                                      )
                                                                    : const SizedBox
                                                                        .shrink(),
                                                                Flexible(
                                                                  child: Text(
                                                                    " ${tasks.items[index].time}",
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style:
                                                                        TextStyle(
                                                                      color: tasks.items[index].status ==
                                                                              0
                                                                          ? context.colors.wB
                                                                          : Colors.grey,
                                                                      fontWeight:
                                                                          FontWeight.normal,
                                                                      fontSize:
                                                                          16,
                                                                    ),
                                                                  ),
                                                                ),
                                                                tasks.items[index].notification ==
                                                                        2
                                                                    ? Flexible(
                                                                        child:
                                                                            Padding(
                                                                        padding:
                                                                            EdgeInsets.only(left: 20),
                                                                        child:
                                                                            Container(
                                                                          constraints:
                                                                              BoxConstraints(
                                                                            maxWidth: 100,
                                                                          ),
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            gradient: const LinearGradient(
                                                                              colors: [
                                                                                Color(0xFF0D47A1),
                                                                                Color(0xFF1976D2),
                                                                              ],
                                                                              begin: Alignment.topLeft,
                                                                              end: Alignment.bottomRight,
                                                                            ),
                                                                            borderRadius: BorderRadius.circular(16),
                                                                          ),
                                                                          child:
                                                                              const Center(
                                                                            child: Text(
                                                                              'Daily',
                                                                              textAlign: TextAlign.center,
                                                                              maxLines: 1,
                                                                              overflow: TextOverflow.fade,
                                                                              style: TextStyle(
                                                                                color: Colors.white,
                                                                                fontSize: 15,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ))
                                                                    : const SizedBox
                                                                        .shrink()
                                                              ],
                                                            ),
                                                          )
                                                        : const SizedBox
                                                            .shrink(),
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
                                onReorderItem:
                                    (int oldIndex, int newIndex) async {
                                  await Provider.of<TasksViewModel>(context,
                                          listen: false)
                                      .syncAfterReorder(oldIndex, newIndex);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
              },
            ),
          ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: context.colors.pageBackground,
            surfaceTintColor: Colors.transparent,
            title: Text(
              "ToDo",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 30,
                color: context.colors.wB,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              ExpandableMenu(
                iconColor: context.colors.appBarIcons,
                animationSpeed: 500,
                width: MediaQuery.orientationOf(context) == Orientation.portrait
                    ? MediaQuery.sizeOf(context).width / 14
                    : MediaQuery.sizeOf(context).width / 30,
                height: 45,
                items: [
                  IconButton(
                      onPressed: () async {
                        showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: MaterialLocalizations.of(context)
                              .modalBarrierDismissLabel,
                          pageBuilder: (BuildContext context,
                              Animation<double> animation,
                              Animation<double> secondaryAnimation) {
                            return TasksOverwriteDialog();
                          },
                          transitionBuilder:
                              (context, animation, secondaryAnimation, child) {
                            var fadeAnimation = CurvedAnimation(
                                parent: animation, curve: Curves.easeInOutSine);
                            var scaleAnimation =
                                Tween<double>(begin: 0.8, end: 1)
                                    .animate(fadeAnimation);
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
                      icon: Icon(
                        Icons.settings_backup_restore,
                        color: context.colors.appBarIcons,
                      )),
                  IconButton(
                      onPressed: () async {
                        Provider.of<TasksViewModel>(context, listen: false)
                            .backup()
                            .then((result) {
                          if (result is Success) {
                            FeedbackToast.success(result.message);
                          } else if (result is Failure) {
                            FeedbackToast.error(result.message);
                          } else if (result is Info) {
                            FeedbackToast.info(result.message);
                          }
                        });
                      },
                      icon: Icon(
                        Icons.backup,
                        color: context.colors.appBarIcons,
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
                        color: context.colors.appBarIcons,
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
