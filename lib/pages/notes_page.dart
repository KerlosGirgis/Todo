import 'dart:io';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:todo/pages/note_editor_page.dart';
import 'package:todo/pages/profile_page.dart';
import 'package:todo/provider/notes_provider.dart';
import 'package:todo/provider/user_provider.dart';
import '../models/note.dart';
import '../services/icon_provider.dart';
import 'package:todo/services/authentication_service.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final AuthenticationService authService = AuthenticationService();
  final LocalAuthentication localAuthentication = LocalAuthentication();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotesProvider>(context, listen: false).get();
    });
    super.initState();
  }


  TextEditingController titleController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Consumer<UserProvider>(
      builder: (context, user, child) {
        return Scaffold(
          backgroundColor: user.colorProvider.pageBackground,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: user.colorProvider.pageBackground,
            title: Text(
              "Notes",
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
                                    ? AssetImage(IconProvider.getAvatar(
                                    user.user.pic))
                                    : FileImage(File(user.user.pic)),
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
                                            "${user.user.firstName} ${user.user.lastName}",
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
                                            user.user.theme == 0
                                                ? Colors.white
                                                : Colors.black12,
                                          ),
                                          onPressed: () {
                                            Provider.of<UserProvider>(context, listen: false).changeTheme();
                                                Navigator.pop(context);
                                          },
                                          child: Icon(user.user.theme == 1
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
                                                      position:
                                                      offsetAnimation,
                                                      child: child);
                                                },
                                              ),
                                            );
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
                  user.colorProvider.floatingActionButtonBackground,
                  foregroundColor:
                  user.colorProvider.floatingActionButtonForeground,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.checklist_sharp)),
              const Padding(padding: EdgeInsets.only(bottom: 20)),
              FloatingActionButton(
                heroTag: 1,
                backgroundColor: user.colorProvider.floatingActionButtonBackground,
                foregroundColor: user.colorProvider.floatingActionButtonForeground,
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        int isProtected = 0;
                        int titleColor = Colors.white.value;
                        int coverColor = Colors.grey.shade700.value;
                        return StatefulBuilder(
                          builder: (BuildContext context, setState) {
                            return AlertDialog(
                              scrollable: true,
                              backgroundColor:
                              user.colorProvider.addTaskAlertBackground,
                              title: const Text(
                                "Add Note",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 32),
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
                                            color: user.colorProvider
                                                .addTaskAlertText)),
                                  ),
                                  const Padding(
                                      padding: EdgeInsets.only(bottom: 15)),
                                  Row(
                                    children: [
                                      const Text(
                                        "Title : ",
                                        style: TextStyle(fontSize: 24),
                                      ),
                                      GestureDetector(
                                        child: CircleAvatar(
                                          backgroundColor: Color(titleColor),
                                        ),
                                        onTap: () {
                                          ColorPicker(
                                            onColorChanged: (Color color) {
                                              setState(() {
                                                titleColor = color.value;
                                              });
                                            },
                                          ).showPickerDialog(context);
                                        },
                                      ),
                                      IconButton(
                                          onPressed: () {
                                            setState(() {
                                              titleColor = Colors.white.value;
                                            });
                                          },
                                          icon: const Icon(Icons.undo_sharp))
                                    ],
                                  ),
                                  const Padding(
                                      padding: EdgeInsets.only(bottom: 15)),
                                  Row(
                                    children: [
                                      const Text(
                                        "Cover : ",
                                        style: TextStyle(fontSize: 24),
                                      ),
                                      GestureDetector(
                                        child: CircleAvatar(
                                          backgroundColor: Color(coverColor),
                                        ),
                                        onTap: () {
                                          ColorPicker(
                                            onColorChanged: (Color color) {
                                              setState(() {
                                                coverColor = color.value;
                                              });
                                            },
                                          ).showPickerDialog(context);
                                        },
                                      ),
                                      IconButton(
                                          onPressed: () {
                                            setState(() {
                                              coverColor =
                                                  Colors.grey.shade700.value;
                                            });
                                          },
                                          icon: const Icon(Icons.undo_sharp))
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                          onPressed: () async {
                                            if (isProtected == 0) {
                                              bool isBioAvailable =
                                              await localAuthentication
                                                  .canCheckBiometrics;
                                              if (isBioAvailable) {
                                                setState(() {
                                                  isProtected = 1;
                                                });
                                              } else {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        "Couldn't read your fingerprint data")));
                                              }
                                            } else if (isProtected == 1) {
                                              setState(() {
                                                isProtected = 0;
                                              });
                                            }
                                          },
                                          icon: Icon(
                                            Icons.fingerprint_sharp,
                                            color: isProtected == 0
                                                ? Colors.black
                                                : Colors.green,
                                          ))
                                    ],
                                  )
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

                                /*
                                Note(
                                        title: titleController.text,
                                        body: '',
                                        titleColor: titleColor,
                                        coverColor: coverColor,
                                        protected: isProtected,
                                      )
                                 */
                                TextButton(
                                  onPressed: () async {
                                    Provider.of<NotesProvider>(context, listen: false).addNote(Note(
                                      title: titleController.text,
                                      body: '',
                                      titleColor: titleColor,
                                      coverColor: coverColor,
                                      protected: isProtected,
                                    ))
                                        .then((value) {
                                      titleController.clear();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
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
                          },
                        );
                      });
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
          /*

           */

          body: Consumer<NotesProvider>(
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
                                    color: Color(notes.notes[index].coverColor),
                                    borderRadius: BorderRadius.circular(12.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        maxLines: 5,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        notes.notes[index].title,
                                        style: TextStyle(
                                            color: Color(
                                                notes.notes[index].titleColor),
                                            fontSize: 20),
                                      ),
                                      notes.notes[index].protected==1?
                                      const Icon(
                                        Icons.lock_sharp,
                                        color: Colors.amber,
                                      )
                                          :const Row(),
                                    ],
                                  )
                              ),
                            );
                          },
                        ),
                      ),
                      onTap: () async {
                        if (notes.notes[index].protected == 1) {
                          bool isAuthenticated =
                          await authService.authenticate();
                          if (isAuthenticated) {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation,
                                    secondaryAnimation) =>
                                    NoteEditorPage(
                                      noteIndex: index,
                                    ),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.ease;
                                  var tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  var offsetAnimation =
                                  animation.drive(tween);
                                  return SlideTransition(
                                      position: offsetAnimation,
                                      child: child);
                                },
                              ),
                            );
                          }
                        } else {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                  NoteEditorPage(
                                    noteIndex: index,
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
                          );
                        }
                      },
                      onLongPress: () async {
                        if (notes.notes[index].protected == 1) {
                          bool isAuthenticated =
                          await authService.authenticate();
                          if (isAuthenticated) {
                            titleController.text = notes.notes[index].title;
                            showDialog(
                                context: context,
                                builder: (context) {
                                  int isProtected = notes.notes[index].protected;
                                  int titleColor = notes.notes[index].titleColor;
                                  int coverColor = notes.notes[index].coverColor;
                                  return StatefulBuilder(
                                    builder:
                                        (BuildContext context, setState) {
                                      return AlertDialog(
                                        scrollable: true,
                                        backgroundColor: user.colorProvider
                                            .addTaskAlertBackground,
                                        title: const Text(
                                          "Edit Note",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 32),
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
                                                      color: user.colorProvider
                                                          .addTaskAlertText)),
                                            ),
                                            const Padding(
                                                padding: EdgeInsets.only(
                                                    bottom: 15)),
                                            Row(
                                              children: [
                                                const Text(
                                                  "Title : ",
                                                  style:
                                                  TextStyle(fontSize: 24),
                                                ),
                                                GestureDetector(
                                                  child: CircleAvatar(
                                                    backgroundColor:
                                                    Color(titleColor),
                                                  ),
                                                  onTap: () {
                                                    ColorPicker(
                                                      onColorChanged:
                                                          (Color color) {
                                                        setState(() {
                                                          titleColor =
                                                              color.value;
                                                        });
                                                      },
                                                    ).showPickerDialog(
                                                        context);
                                                  },
                                                ),
                                                IconButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        titleColor = Colors
                                                            .white.value;
                                                      });
                                                    },
                                                    icon: const Icon(
                                                        Icons.undo_sharp))
                                              ],
                                            ),
                                            const Padding(
                                                padding: EdgeInsets.only(
                                                    bottom: 15)),
                                            Row(
                                              children: [
                                                const Text(
                                                  "Cover : ",
                                                  style:
                                                  TextStyle(fontSize: 24),
                                                ),
                                                GestureDetector(
                                                  child: CircleAvatar(
                                                    backgroundColor:
                                                    Color(coverColor),
                                                  ),
                                                  onTap: () {
                                                    ColorPicker(
                                                      onColorChanged:
                                                          (Color color) {
                                                        setState(() {
                                                          coverColor =
                                                              color.value;
                                                        });
                                                      },
                                                    ).showPickerDialog(
                                                        context);
                                                  },
                                                ),
                                                IconButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        coverColor = Colors
                                                            .grey
                                                            .shade700
                                                            .value;
                                                      });
                                                    },
                                                    icon: const Icon(
                                                        Icons.undo_sharp))
                                              ],
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                IconButton(
                                                    onPressed: () async {
                                                      if (isProtected == 0) {
                                                        bool isBioAvailable =
                                                        await localAuthentication
                                                            .canCheckBiometrics;
                                                        if (isBioAvailable) {
                                                          setState(() {
                                                            isProtected = 1;
                                                          });
                                                        } else {
                                                          ScaffoldMessenger.of(context)
                                                              .showSnackBar(const SnackBar(
                                                              content: Text(
                                                                  "Couldn't read your fingerprint data")));
                                                        }
                                                      } else if (isProtected == 1) {
                                                        setState(() {
                                                          isProtected = 0;
                                                        });
                                                      }
                                                    },
                                                    icon: Icon(
                                                      Icons.fingerprint_sharp,
                                                      color: isProtected == 0
                                                          ? Colors.black
                                                          : Colors.green,
                                                    ))
                                              ],
                                            )
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
                                                  color:
                                                  Colors.blueAccent[900],
                                                  fontSize: 18),
                                            ),
                                          ),
                                          /*
                                          Note(
                                                    id: notes.notes[index].id,
                                                    title:
                                                    titleController.text,
                                                    body: notes.notes[index].body,
                                                    titleColor: titleColor,
                                                    coverColor: coverColor,
                                                    protected: isProtected)
                                           */
                                          TextButton(
                                            onPressed: () async {
                                              Provider.of<NotesProvider>(context, listen: false).updateNote(Note(
                                                  id: notes.notes[index].id,
                                                  title:
                                                  titleController.text,
                                                  body: notes.notes[index].body,
                                                  titleColor: titleColor,
                                                  coverColor: coverColor,
                                                  protected: isProtected))
                                                  .then((value) {
                                                titleController.clear();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        "Note Edited")));
                                              });
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                              }
                                            },
                                            child: Text(
                                              "Save",
                                              style: TextStyle(
                                                  color:
                                                  Colors.blueAccent[900],
                                                  fontSize: 18),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                });
                          }
                        } else {
                          titleController.text = notes.notes[index].title;
                          showDialog(
                              context: context,
                              builder: (context) {
                                int isProtected = notes.notes[index].protected;
                                int titleColor = notes.notes[index].titleColor;
                                int coverColor = notes.notes[index].coverColor;
                                return StatefulBuilder(
                                  builder: (BuildContext context, setState) {
                                    return AlertDialog(
                                      scrollable: true,
                                      backgroundColor: user.colorProvider
                                          .addTaskAlertBackground,
                                      title: const Text(
                                        "Edit Note",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 32),
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
                                                    color: user.colorProvider
                                                        .addTaskAlertText)),
                                          ),
                                          const Padding(
                                              padding: EdgeInsets.only(
                                                  bottom: 15)),
                                          Row(
                                            children: [
                                              const Text(
                                                "Title : ",
                                                style:
                                                TextStyle(fontSize: 24),
                                              ),
                                              GestureDetector(
                                                child: CircleAvatar(
                                                  backgroundColor:
                                                  Color(titleColor),
                                                ),
                                                onTap: () {
                                                  ColorPicker(
                                                    onColorChanged:
                                                        (Color color) {
                                                      setState(() {
                                                        titleColor =
                                                            color.value;
                                                      });
                                                    },
                                                  ).showPickerDialog(context);
                                                },
                                              ),
                                              IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      titleColor =
                                                          Colors.white.value;
                                                    });
                                                  },
                                                  icon: const Icon(
                                                      Icons.undo_sharp))
                                            ],
                                          ),
                                          const Padding(
                                              padding: EdgeInsets.only(
                                                  bottom: 15)),
                                          Row(
                                            children: [
                                              const Text(
                                                "Cover : ",
                                                style:
                                                TextStyle(fontSize: 24),
                                              ),
                                              GestureDetector(
                                                child: CircleAvatar(
                                                  backgroundColor:
                                                  Color(coverColor),
                                                ),
                                                onTap: () {
                                                  ColorPicker(
                                                    onColorChanged:
                                                        (Color color) {
                                                      setState(() {
                                                        coverColor =
                                                            color.value;
                                                      });
                                                    },
                                                  ).showPickerDialog(context);
                                                },
                                              ),
                                              IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      coverColor = Colors.grey
                                                          .shade700.value;
                                                    });
                                                  },
                                                  icon: const Icon(
                                                      Icons.undo_sharp))
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                  onPressed: () async {
                                                    if (isProtected == 0) {
                                                      bool isBioAvailable =
                                                      await localAuthentication
                                                          .canCheckBiometrics;
                                                      if (isBioAvailable) {
                                                        setState(() {
                                                          isProtected = 1;
                                                        });
                                                      } else {
                                                        ScaffoldMessenger.of(context)
                                                            .showSnackBar(const SnackBar(
                                                            content: Text(
                                                                "Couldn't read your fingerprint data")));
                                                      }
                                                    } else if (isProtected == 1) {
                                                      setState(() {
                                                        isProtected = 0;
                                                      });
                                                    }
                                                  },
                                                  icon: Icon(
                                                    Icons.fingerprint_sharp,
                                                    color: isProtected == 0
                                                        ? Colors.black
                                                        : Colors.green,
                                                  ))
                                            ],
                                          )
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
                                        /*
                                        Note(
                                                  id: notes.notes[index].id,
                                                  title: titleController.text,
                                                  body: notes.notes[index].body,
                                                  titleColor: titleColor,
                                                  coverColor: coverColor,
                                                  protected: isProtected)
                                         */
                                        TextButton(
                                          onPressed: () async {
                                            Provider.of<NotesProvider>(context, listen: false).updateNote(Note(
                                                id: notes.notes[index].id,
                                                title: titleController.text,
                                                body: notes.notes[index].body,
                                                titleColor: titleColor,
                                                coverColor: coverColor,
                                                protected: isProtected))
                                                .then((value) {
                                              titleController.clear();
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      "Note Edited")));
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
                                  },
                                );
                              });
                        }
                      },
                    );
                  });
            },
          ),
        );
      },
    );
  }
}
