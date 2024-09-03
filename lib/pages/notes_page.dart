import 'dart:io';
import 'package:flutter/material.dart';
import 'package:todo/pages/note_editor_page.dart';
import 'package:todo/pages/profile_page.dart';
import '../models/note.dart';
import '../models/user_profile.dart';
import '../services/color_provider.dart';
import '../services/database_service.dart';
import '../services/icon_provider.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  @override
  void initState() {
    getNotes();
    getUser();
    super.initState();
  }

  List<Note> notes = [];
  List<UserProfile> user = [];
  bool isUserLoading = false;
  bool isNotesLoading = false;
  late ColorProvider colorProvider;

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

  void getNotes() async {
    setState(() {
      isNotesLoading = true;
    });
    notes = await DatabaseService().getNotes();
    setState(() {
      isNotesLoading = false;
    });
  }

  TextEditingController titleController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return isUserLoading
        ? const SizedBox.shrink()
        : Scaffold(
            backgroundColor: colorProvider.pageBackground,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: colorProvider.pageBackground,
              title: Text(
                "Notes",
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
                                scrollable: true,
                                backgroundColor:
                                    colorProvider.profileAlertBackground,
                                title: CircleAvatar(
                                  radius: 130,
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
                                            child: Icon(user.first.theme == 1
                                                ? Icons.dark_mode_sharp
                                                : Icons.light_mode_sharp)),
                                        const Padding(
                                            padding:
                                                EdgeInsets.only(right: 30)),
                                        ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                PageRouteBuilder(
                                                  pageBuilder: (context,
                                                          animation,
                                                          secondaryAnimation) =>
                                                      ProfilePage(
                                                          user: user.first),
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
                                                        position:
                                                            offsetAnimation,
                                                        child: child);
                                                  },
                                                ),
                                              ).then((e) {
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
            floatingActionButton: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                    heroTag: 0,
                    backgroundColor:
                        colorProvider.floatingActionButtonBackground,
                    foregroundColor:
                        colorProvider.floatingActionButtonForeground,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.menu_sharp)),
                const Padding(padding: EdgeInsets.only(bottom: 20)),
                FloatingActionButton(
                  heroTag: 1,
                  backgroundColor: colorProvider.floatingActionButtonBackground,
                  foregroundColor: colorProvider.floatingActionButtonForeground,
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            scrollable: true,
                            backgroundColor:
                                colorProvider.addTaskAlertBackground,
                            title: const Text(
                              "Add Note",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 32),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: titleController,
                                  maxLines: 1,
                                  maxLength: 50,
                                  decoration: InputDecoration(
                                      labelText: "Title",
                                      labelStyle: TextStyle(
                                          fontSize: 30,
                                          color:
                                              colorProvider.addTaskAlertText)),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  titleController.clear();
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
                                  await DatabaseService()
                                      .insertNote(
                                    Note(
                                      title: titleController.text,
                                      body: '',
                                    ),
                                  )
                                      .then((value) {
                                    getNotes();
                                    titleController.clear();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text("Note Added")));
                                  });
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
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
                        });
                  },
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            body: notes.isEmpty
                ? Center(
                    child: Image.asset(
                      "assets/empty_notes.png",
                      scale: 2,
                    ),
                  )
                : GridView.builder(
                    itemCount: notes.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).orientation ==
                                Orientation.portrait
                            ? 2
                            : 4,
                        childAspectRatio: 0.7),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          // Use LayoutBuilder to adjust size based on parent constraints
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate the card width based on the screen width
                              final cardWidth = screenSize.width * 0.8;
                              // Maintain an aspect ratio for the card
                              const aspectRatio = 16 / 9;

                              return AspectRatio(
                                aspectRatio: aspectRatio,
                                child: Container(
                                  width: cardWidth,
                                  decoration: BoxDecoration(
                                    color: colorProvider.cardBackground,
                                    borderRadius: BorderRadius.circular(12.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      maxLines: 5,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      notes[index].title,
                                      style: TextStyle(
                                          color: colorProvider.taskTitle,
                                          fontSize: 20),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      NoteEditorPage(
                                colorProvider: colorProvider,
                                note: notes[index],
                              ),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
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
                          ).then((onValue) {
                            setState(() {
                              getNotes();
                            });
                          });
                        },
                      );
                    }),
          );
  }
}
