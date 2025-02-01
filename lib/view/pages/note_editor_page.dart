import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

  final AuthenticationService authService = AuthenticationService();
  TextEditingController bodyController = TextEditingController();
  @override
  void initState() {
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
                  user.user.count==1?
                  Text("${bodyController.text.length}",style: TextStyle(
                      fontSize: 22,
                      color: user.colorProvider.appTitle
                  ),):const SizedBox.shrink(),
                  Padding(padding: EdgeInsets.only(right: MediaQuery.sizeOf(context).width/50)),
                  IconButton(
                      onPressed: () {
                        try {
                          Provider.of<NotesProvider>(context, listen: false)
                              .updateNote(Note(
                                  id: widget.note.id,
                                  title: widget.note.title,
                                  body: bodyController.text,
                                  titleColor: widget.note.titleColor,
                                  coverColor: widget.note.coverColor,
                                  protected: widget.note.protected))
                              .then((onValue) {
                            widget.note.body = bodyController.text;
                            Fluttertoast.showToast(
                                msg: "Saved Successfully",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: const Color(0xff1E1E1E),
                                textColor: Colors.white,
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
                        color:
                            widget.note.body.compareTo(bodyController.text) == 0
                                ? user.colorProvider.noteEditorButtons
                                : Colors.lightBlue,
                      )),
                  IconButton(
                      onPressed: () {
                        if (widget.note.body.isNotEmpty) {
                          try {
                            notes.updateAndroidWidget(widget.note.body);
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
                              backgroundColor: const Color(0xff1E1E1E),
                              textColor: Colors.white,
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
                            notes.deleteNote(widget.note.id!);
                            if(context.mounted){
                              Navigator.pop(context);
                            }
                          } else {
                            Fluttertoast.showToast(
                                msg: "Authentication Failed",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                fontSize: 19.0);
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
                            onChanged: (value) {
                              if (user.user.autoSave == 1) {
                                try {
                                  Provider.of<NotesProvider>(context,
                                          listen: false)
                                      .updateNote(Note(
                                          id: widget.note.id,
                                          title: widget.note.title,
                                          body: bodyController.text,
                                          titleColor: widget.note.titleColor,
                                          coverColor: widget.note.coverColor,
                                          protected: widget.note.protected))
                                      .then((onValue) {
                                    widget.note.body = bodyController.text;
                                  });
                                } catch (e) {
                                  Fluttertoast.showToast(
                                      msg:
                                          "Sorry, Something went wrong,note not saved",
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
                                fontFamily:
                                    user.user.casual == 1 ? 'casual' : 'arial',
                                fontWeight: user.user.casual == 1
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: user.colorProvider.noteEditorText,
                                fontSize: 26,
                                decoration: TextDecoration.none,
                                decorationColor:
                                    user.colorProvider.noteEditorText),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
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
