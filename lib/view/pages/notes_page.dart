import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:todo/view/pages/note_editor_page.dart';
import 'package:todo/view/pages/profile_page.dart';
import 'package:todo/provider/notes_provider.dart';
import 'package:todo/provider/user_provider.dart';
import '../../models/note.dart';
import 'package:todo/services/authentication_service.dart';
import '../widgets/appbar_avatar.dart';
import '../widgets/button.dart';

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
                  IconButton(onPressed: (){
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
                              position: offsetAnimation,
                              child: child);
                        },
                      ),
                    );
                  }, icon: const Icon(Icons.settings,color: Colors.grey,)),
                  const AppbarAvatar(),
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
                backgroundColor:
                    user.colorProvider.floatingActionButtonBackground,
                foregroundColor:
                    user.colorProvider.floatingActionButtonForeground,
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        int isProtected = 0;
                        int titleColor = Colors.white.value;
                        int coverColor =
                            Colors.grey.shade800.withOpacity(.5).value;
                        return StatefulBuilder(
                          builder: (BuildContext context, setState) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 2,
                              scrollable: true,
                              backgroundColor:
                                  user.colorProvider.addTaskAlertBackground,
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  const Spacer(
                                    flex: 1,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffd8defb),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.add_task,
                                      color: Color(0xff3D5AFE),
                                      size: 20,
                                    ),
                                  ),
                                  const Spacer(
                                    flex: 10,
                                  ),
                                  const Text(
                                    "Add Note",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 32),
                                  ),
                                  const Spacer(
                                    flex: 10,
                                  ),
                                  IconButton(
                                      onPressed: () {
                                        titleController.clear();
                                        Navigator.pop(context);
                                      },
                                      icon: const Icon(Icons.close),style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(8)),
                                    ),
                                  ),)
                                ],
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
                                                .addTaskAlertText),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(15))),
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
                                              coverColor = Colors.grey.shade800
                                                  .withOpacity(.5)
                                                  .value;
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
                                                  await authService
                                                      .authenticate();
                                              if (isBioAvailable) {
                                                setState(() {
                                                  isProtected = 1;
                                                });
                                              } else {
                                                Fluttertoast.showToast(
                                                    msg:
                                                        "Couldn't read your fingerprint data",
                                                    toastLength:
                                                        Toast.LENGTH_SHORT,
                                                    gravity:
                                                        ToastGravity.BOTTOM,
                                                    backgroundColor: Colors.red,
                                                    textColor: Colors.white,
                                                    fontSize: 19.0);
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
                                Button(
                                  onPressed: () {
                                    titleController.clear();
                                    Navigator.pop(context);
                                  },
                                  label: 'Cancel',
                                  status: false,
                                  fontSize: 18,
                                  size: 1,
                                ),
                                Padding(padding: EdgeInsets.only(right: MediaQuery.of(context).size.width/25)),
                                Button(
                                  onPressed: () async {
                                    Provider.of<NotesProvider>(context,
                                            listen: false)
                                        .addNote(Note(
                                      title: titleController.text,
                                      body: '',
                                      titleColor: titleColor,
                                      coverColor: coverColor,
                                      protected: isProtected,
                                    ))
                                        .then((value) {
                                      titleController.clear();
                                      Fluttertoast.showToast(
                                          msg: "Note Added",
                                          toastLength: Toast.LENGTH_SHORT,
                                          gravity: ToastGravity.BOTTOM,
                                          backgroundColor:
                                              user.colorProvider.cardBackground,
                                          textColor:
                                              user.colorProvider.appTitle,
                                          fontSize: 19.0);
                                    });
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  label: 'Save',
                                  status: true,
                                  fontSize: 18,
                                  size: 1,
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
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final cardWidth = screenSize.width * 0.8;
                                const aspectRatio = 16 / 9;

                                return AspectRatio(
                                  aspectRatio: aspectRatio,
                                  child: Container(
                                      width: cardWidth,
                                      decoration: BoxDecoration(
                                        color: Color(
                                            notes.notes[index].coverColor),
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            maxLines: 5,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            notes.notes[index].title,
                                            style: TextStyle(
                                                color: Color(notes
                                                    .notes[index].titleColor),
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          notes.notes[index].protected == 1
                                              ? Image.asset(
                                                  "assets/lock.png",
                                                  scale: 1.4,
                                                )
                                              : const Row(),
                                        ],
                                      )),
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
                                      note: notes.notes[index],
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
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      NoteEditorPage(
                                    note: notes.notes[index],
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
                                      int isProtected =
                                          notes.notes[index].protected;
                                      int titleColor =
                                          notes.notes[index].titleColor;
                                      int coverColor =
                                          notes.notes[index].coverColor;
                                      return StatefulBuilder(
                                        builder:
                                            (BuildContext context, setState) {
                                          return AlertDialog(
                                            scrollable: true,
                                            backgroundColor: user.colorProvider
                                                .addTaskAlertBackground,
                                            title: Row(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              children: [
                                                const Spacer(
                                                  flex: 1,
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xffd8defb),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.edit,
                                                    color: Color(0xff3D5AFE),
                                                    size: 20,
                                                  ),
                                                ),
                                                const Spacer(
                                                  flex: 10,
                                                ),
                                                const Text(
                                                  "Edit Note",
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 32),
                                                ),
                                                const Spacer(
                                                  flex: 10,
                                                ),
                                                IconButton(
                                                  onPressed: () {
                                                    titleController.clear();
                                                    Navigator.pop(context);
                                                  },
                                                  icon: const Icon(Icons.close),style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.grey.shade300,
                                                  shape: const RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.all(Radius.circular(8)),
                                                  ),
                                                ),)
                                              ],
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
                                                          color: user
                                                              .colorProvider
                                                              .addTaskAlertText),
                                                      border:
                                                          OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          15))),
                                                ),
                                                const Padding(
                                                    padding: EdgeInsets.only(
                                                        bottom: 15)),
                                                Row(
                                                  children: [
                                                    const Text(
                                                      "Title : ",
                                                      style: TextStyle(
                                                          fontSize: 24),
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
                                                      style: TextStyle(
                                                          fontSize: 24),
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
                                                                .grey.shade800
                                                                .withOpacity(.5)
                                                                .value;
                                                          });
                                                        },
                                                        icon: const Icon(
                                                            Icons.undo_sharp))
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    IconButton(
                                                        onPressed: () async {
                                                          if (isProtected ==
                                                              0) {
                                                            bool
                                                                isBioAvailable =
                                                                await authService
                                                                    .authenticate();
                                                            if (isBioAvailable) {
                                                              setState(() {
                                                                isProtected = 1;
                                                              });
                                                            } else {
                                                              Fluttertoast.showToast(
                                                                  msg:
                                                                      "Couldn't read your fingerprint data",
                                                                  toastLength: Toast
                                                                      .LENGTH_SHORT,
                                                                  gravity:
                                                                      ToastGravity
                                                                          .BOTTOM,
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                  textColor:
                                                                      Colors
                                                                          .white,
                                                                  fontSize:
                                                                      19.0);
                                                            }
                                                          } else if (isProtected ==
                                                              1) {
                                                            setState(() {
                                                              isProtected = 0;
                                                            });
                                                          }
                                                        },
                                                        icon: Icon(
                                                          Icons
                                                              .fingerprint_sharp,
                                                          color: isProtected ==
                                                                  0
                                                              ? Colors.black
                                                              : Colors.green,
                                                        ))
                                                  ],
                                                )
                                              ],
                                            ),
                                            actions: [
                                              Button(
                                                onPressed: () {
                                                  titleController.clear();
                                                  Navigator.pop(context);
                                                },
                                                label: 'Cancel',
                                                status: false,
                                                fontSize: 18,
                                                size: 1,
                                              ),
                                              Padding(padding: EdgeInsets.only(right: MediaQuery.of(context).size.width/25)),
                                              Button(
                                                onPressed: () async {
                                                  Provider.of<NotesProvider>(
                                                          context,
                                                          listen: false)
                                                      .updateNote(Note(
                                                          id: notes
                                                              .notes[index].id,
                                                          title: titleController
                                                              .text,
                                                          body: notes
                                                              .notes[index]
                                                              .body,
                                                          titleColor:
                                                              titleColor,
                                                          coverColor:
                                                              coverColor,
                                                          protected:
                                                              isProtected))
                                                      .then((value) {
                                                    titleController.clear();
                                                    Fluttertoast.showToast(
                                                        msg: "Note Edited",
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
                                                  if (context.mounted) {
                                                    Navigator.of(context).pop();
                                                  }
                                                },
                                                label: 'Update',
                                                status: true,
                                                fontSize: 18,
                                                size: 1,
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
                                    int isProtected =
                                        notes.notes[index].protected;
                                    int titleColor =
                                        notes.notes[index].titleColor;
                                    int coverColor =
                                        notes.notes[index].coverColor;
                                    return StatefulBuilder(
                                      builder:
                                          (BuildContext context, setState) {
                                        return AlertDialog(
                                          scrollable: true,
                                          backgroundColor: user.colorProvider
                                              .addTaskAlertBackground,
                                          title: Row(
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            children: [
                                              const Spacer(
                                                flex: 1,
                                              ),
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xffd8defb),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.edit,
                                                  color: Color(0xff3D5AFE),
                                                  size: 20,
                                                ),
                                              ),
                                              const Spacer(
                                                flex: 10,
                                              ),
                                              const Text(
                                                "Edit Note",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 32),
                                              ),
                                              const Spacer(
                                                flex: 10,
                                              ),
                                              IconButton(
                                                onPressed: () {
                                                  titleController.clear();
                                                  Navigator.pop(context);
                                                },
                                                icon: const Icon(Icons.close),style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.grey.shade300,
                                                shape: const RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                                ),
                                              ),)
                                            ],
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
                                                        color: user
                                                            .colorProvider
                                                            .addTaskAlertText),
                                                    border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(15))),
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
                                                              .grey.shade800
                                                              .withOpacity(.5)
                                                              .value;
                                                        });
                                                      },
                                                      icon: const Icon(
                                                          Icons.undo_sharp))
                                                ],
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                      onPressed: () async {
                                                        if (isProtected == 0) {
                                                          bool isBioAvailable =
                                                              await authService
                                                                  .authenticate();
                                                          if (isBioAvailable) {
                                                            setState(() {
                                                              isProtected = 1;
                                                            });
                                                          } else {
                                                            Fluttertoast.showToast(
                                                                msg:
                                                                    "Couldn't read your fingerprint data",
                                                                toastLength: Toast
                                                                    .LENGTH_SHORT,
                                                                gravity:
                                                                    ToastGravity
                                                                        .BOTTOM,
                                                                backgroundColor:
                                                                    Colors.red,
                                                                textColor:
                                                                    Colors
                                                                        .white,
                                                                fontSize: 19.0);
                                                          }
                                                        } else if (isProtected ==
                                                            1) {
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
                                            Button(
                                              onPressed: () {
                                                titleController.clear();
                                                Navigator.pop(context);
                                              },
                                              label: 'Cancel',
                                              status: false,
                                              fontSize: 18,
                                              size: 1,
                                            ),
                                            Padding(padding: EdgeInsets.only(right: MediaQuery.of(context).size.width/25)),
                                            Button(
                                              onPressed: () async {
                                                Provider.of<NotesProvider>(
                                                        context,
                                                        listen: false)
                                                    .updateNote(Note(
                                                        id: notes
                                                            .notes[index].id,
                                                        title: titleController
                                                            .text,
                                                        body: notes
                                                            .notes[index].body,
                                                        titleColor: titleColor,
                                                        coverColor: coverColor,
                                                        protected: isProtected))
                                                    .then((value) {
                                                  titleController.clear();
                                                  Fluttertoast.showToast(
                                                      msg: "Note Edited",
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
                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                }
                                              },
                                              label: 'Update',
                                              status: true,
                                              fontSize: 18,
                                              size: 1,
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
