import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:todo/core/result.dart';
import 'package:todo/view/screens/notes/note_editor_page/screen/note_editor_page.dart';
import 'package:todo/view/screens/notes/notes_page/widgets/notes_overwrite_dialog.dart';
import 'package:todo/view/screens/tasks/todo_page/screen/todo_page.dart';
import 'package:todo/view_model/notes_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:todo/view/screens/profile/profile_page/screen/profile_page.dart';
import 'package:todo/view/screens/notes/notes_page/widgets/add_note_dialog.dart';
import 'package:todo/view/widgets/expandable_menu.dart';
import 'package:todo/view/screens/notes/notes_page/widgets/reorder_notes_dialog.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../widgets/appbar_avatar.dart';
import '../widgets/update_note_dialog.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotesViewModel>(context, listen: false).get();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Consumer<UserViewModel>(
      builder: (context, user, child) {
        return Scaffold(
          backgroundColor: user.colorManager.pageBackground,
          appBar: AppBar(
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            backgroundColor: user.colorManager.pageBackground,
            title: Text(
              "Notes",
              style: TextStyle(
                fontSize: 30,
                overflow: TextOverflow.ellipsis,
                color: user.colorManager.wB,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              ExpandableMenu(
                  iconColor: user.colorManager.appBarIcons,
                  animationSpeed: 500,
                  width:
                      MediaQuery.orientationOf(context) == Orientation.portrait
                          ? MediaQuery.sizeOf(context).width / 14
                          : MediaQuery.sizeOf(context).width / 22,
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
                              return ReorderNotesDialog();
                            },
                            transitionBuilder: (context, animation,
                                secondaryAnimation, child) {
                              var fadeAnimation = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOutSine);
                              var scaleAnimation =
                                  Tween<double>(begin: 0.95, end: 1.0)
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
                        icon: Icon(
                          Icons.reorder,
                          color: user.colorManager.appBarIcons,
                        )),
                    IconButton(
                        onPressed: () {
                          showGeneralDialog(
                            context: context,
                            barrierDismissible: true,
                            barrierLabel: MaterialLocalizations.of(context)
                                .modalBarrierDismissLabel,
                            pageBuilder: (BuildContext context,
                                Animation<double> animation,
                                Animation<double> secondaryAnimation) {
                              return NotesOverwriteDialog();
                            },
                            transitionBuilder: (context, animation,
                                secondaryAnimation, child) {
                              var fadeAnimation = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOutSine);
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
                          color: user.colorManager.appBarIcons,
                        )),
                    IconButton(
                        onPressed: () async {
                          Provider.of<NotesViewModel>(context, listen: false)
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
                          color: user.colorManager.appBarIcons,
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
                          color: user.colorManager.appBarIcons,
                        )),
                  ]),
              Flexible(child: const AppbarAvatar()),
              const Padding(padding: EdgeInsets.only(right: 18)),
            ],
          ),
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                  heroTag: 0,
                  backgroundColor:
                      user.colorManager.floatingActionButtonBackground,
                  foregroundColor:
                      user.colorManager.floatingActionButtonForeground,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const TodoPage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(1.0, 0.0);
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
                  child: const Icon(Icons.checklist_sharp)),
              const Padding(padding: EdgeInsets.only(bottom: 20)),
              FloatingActionButton(
                heroTag: 1,
                backgroundColor:
                    user.colorManager.floatingActionButtonBackground,
                foregroundColor:
                    user.colorManager.floatingActionButtonForeground,
                onPressed: () {
                  showGeneralDialog(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: MaterialLocalizations.of(context)
                        .modalBarrierDismissLabel,
                    pageBuilder: (BuildContext context,
                        Animation<double> animation,
                        Animation<double> secondaryAnimation) {
                      return AddNoteDialog();
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
            child: Consumer<NotesViewModel>(
              builder: (context, notes, child) {
                return notes.notes.isEmpty
                    ? Center(
                        child: Image.asset(
                          "assets/empty_notes.png",
                          scale: 2,
                        ),
                      )
                    : GridView.builder(
                        itemCount: notes.notes.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                MediaQuery.of(context).orientation ==
                                        Orientation.portrait
                                    ? 2
                                    : 4,
                            childAspectRatio: 0.7),
                        itemBuilder: (context, index) {
                          return AnimationLimiter(
                            child: AnimationConfiguration.staggeredGrid(
                              duration: const Duration(milliseconds: 600),
                              position: index,
                              columnCount: MediaQuery.of(context).orientation ==
                                      Orientation.portrait
                                  ? 2
                                  : 4,
                              child: SlideAnimation(
                                verticalOffset: 400,
                                child: FadeInAnimation(
                                  child: GestureDetector(
                                    child: Container(
                                      margin: const EdgeInsets.all(16),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final cardWidth =
                                              screenSize.width * 0.8;
                                          const aspectRatio = 16 / 9;
                                          return AspectRatio(
                                            aspectRatio: aspectRatio,
                                            child: Container(
                                                width: cardWidth,
                                                decoration: BoxDecoration(
                                                  color: notes.notes[index]
                                                      .coverColor.toColor,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.8),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Stack(
                                                  children: [
                                                    Center(
                                                      child: Text(
                                                        maxLines: 4,
                                                        textAlign:
                                                            TextAlign.center,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        notes
                                                            .notes[index].title,
                                                        style: TextStyle(
                                                            color: notes
                                                                .notes[index]
                                                                .titleColor
                                                                .toColor,
                                                            fontSize: 24 *
                                                                user.user
                                                                    .notesTitleSize,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                    ),
                                                    notes.notes[index]
                                                                .protected ==
                                                            1
                                                        ? Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .end,
                                                            children: [
                                                              Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .end,
                                                                children: [
                                                                  Flexible(
                                                                    child:
                                                                        Padding(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .all(
                                                                              7),
                                                                      child: Image
                                                                          .asset(
                                                                        "assets/lock.png",
                                                                        scale:
                                                                            4,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          )
                                                        : const SizedBox
                                                            .shrink(),
                                                  ],
                                                )),
                                          );
                                        },
                                      ),
                                    ),
                                    onTap: () async {
                                      Result status = await notes
                                          .authenticate(notes.notes[index]);
                                      if (status is Success) {
                                        if (context.mounted) {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (context, animation,
                                                      secondaryAnimation) =>
                                                  NoteEditorPage(
                                                note: notes.notes[index],
                                              ),
                                              transitionsBuilder: (context,
                                                  animation,
                                                  secondaryAnimation,
                                                  child) {
                                                const begin = Offset(1.0, 0.0);
                                                const end = Offset.zero;
                                                const curve = Curves.ease;
                                                var tween = Tween(
                                                        begin: begin, end: end)
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
                                        }
                                      } else if (status is Failure) {
                                        FeedbackToast.error(status.message);
                                      }
                                    },
                                    onLongPress: () async {
                                      Result status = await notes
                                          .authenticate(notes.notes[index]);
                                      if (status is Success) {
                                        if (context.mounted) {
                                          showGeneralDialog(
                                            context: context,
                                            barrierDismissible: true,
                                            barrierLabel:
                                                MaterialLocalizations.of(
                                                        context)
                                                    .modalBarrierDismissLabel,
                                            pageBuilder: (BuildContext context,
                                                Animation<double> animation,
                                                Animation<double>
                                                    secondaryAnimation) {
                                              return UpdateNoteDialog(
                                                  note: notes.notes[index]);
                                            },
                                            transitionBuilder: (context,
                                                animation,
                                                secondaryAnimation,
                                                child) {
                                              var fadeAnimation =
                                                  CurvedAnimation(
                                                      parent: animation,
                                                      curve:
                                                          Curves.easeInOutSine);
                                              var scaleAnimation =
                                                  Tween<double>(
                                                          begin: 0.8, end: 1)
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
                                        }
                                      } else if (status is Failure) {
                                        FeedbackToast.error(status.message);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        });
              },
            ),
          ),
        );
      },
    );
  }
}
