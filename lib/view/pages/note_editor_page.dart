import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:todo/provider/notes_provider.dart';
import 'package:todo/provider/user_provider.dart';
import '../../models/note.dart';
import '../../services/authentication_service.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.note});

  final Note note;
  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  void updateAndroidWidget(String note) {
    HomeWidget.saveWidgetData("note", note);
    HomeWidget.updateWidget(
      androidName: "Note",
    );
  }

  final AuthenticationService authService = AuthenticationService();
  TextEditingController titleController = TextEditingController();
  TextEditingController bodyController = TextEditingController();
  @override
  void initState() {
    titleController.text = widget.note.title;
    bodyController.text = widget.note.body;
    super.initState();
  }
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, user, child) {
        return Consumer<NotesProvider>(
          builder: (context, notes, child) {
            return Scaffold(
              backgroundColor: user.colorProvider.pageBackground,
              appBar: AppBar(
                surfaceTintColor: Colors.transparent,
                title: Text(
                  widget.note.title,
                  style: TextStyle(
                    fontSize: 30,
                    color: user.colorProvider.appTitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: user.colorProvider.pageBackground,
                leading: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: user.colorProvider.noteEditorBackButton,
                    )),
                actions: [
                  IconButton(
                      onPressed: () {
                        try {
                          Provider.of<NotesProvider>(context, listen: false)
                              .updateNote(Note(
                                  id: widget.note.id,
                                  title: titleController.text,
                                  body: bodyController.text,
                                  titleColor: widget.note.titleColor,
                                  coverColor: widget.note.coverColor,
                                  protected: widget.note.protected))
                              .then((onValue) {
                            widget.note.body = bodyController.text;
                            widget.note.title = titleController.text;
                            Fluttertoast.showToast(
                                msg: "Saved Successfully",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor:
                                    user.colorProvider.cardBackground,
                                textColor: user.colorProvider.appTitle,
                                fontSize: 19.0);
                          });
                        } catch (e) {
                          Fluttertoast.showToast(
                              msg: "Sorry, Something went wrong,note not saved",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                              fontSize: 19.0);
                        }
                      },
                      icon: Icon(
                        Icons.save_sharp,
                        color: user.colorProvider.noteEditorButtons,
                      )),
                  IconButton(
                      onPressed: () {
                        if (widget.note.body.isNotEmpty) {
                          try {
                            updateAndroidWidget(widget.note.body);
                          } catch (e) {
                            Fluttertoast.showToast(
                                msg: "Sorry, Something went wrong",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                fontSize: 19.0);
                            return;
                          }
                          Fluttertoast.showToast(
                              msg: "Note has been added to the widget",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor:
                                  user.colorProvider.cardBackground,
                              textColor: user.colorProvider.appTitle,
                              fontSize: 19.0);
                        }
                      },
                      icon: Icon(
                        Icons.sticky_note_2_sharp,
                        color: user.colorProvider.noteEditorButtons,
                      )),
                  IconButton(
                      onPressed: () async {
                        if (widget.note.protected == 1) {
                          bool isAuthenticated =
                              await authService.authenticate();
                          if (isAuthenticated) {
                            Provider.of<NotesProvider>(context, listen: false)
                                .deleteNote(widget.note.id!);
                            Navigator.pop(context);
                          }
                        } else {
                          Provider.of<NotesProvider>(context, listen: false)
                              .deleteNote(widget.note.id!);
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(
                        Icons.delete_sharp,
                        color: Colors.red,
                      )),
                ],
              ),
              body: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 1.1,
                          child: TextField(
                            onChanged: (value){
                              if(user.user.autoSave==1) {
                                try {
                                  Provider.of<NotesProvider>(
                                      context, listen: false)
                                      .updateNote(Note(
                                      id: widget.note.id,
                                      title: titleController.text,
                                      body: bodyController.text,
                                      titleColor: widget.note.titleColor,
                                      coverColor: widget.note.coverColor,
                                      protected: widget.note.protected));
                                } catch (e) {
                                  Fluttertoast.showToast(
                                      msg: "Sorry, Something went wrong,note not saved",
                                      toastLength: Toast.LENGTH_SHORT,
                                      gravity: ToastGravity.BOTTOM,
                                      backgroundColor: Colors.red,
                                      textColor: Colors.white,
                                      fontSize: 19.0);
                                }
                              }
                            },
                            controller: bodyController,
                            maxLines: null,
                            style: TextStyle(
                                color: user.colorProvider.noteEditorText,
                                fontSize: 30),
                            decoration: InputDecoration(
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                    color: user.colorProvider.noteEditorText)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
