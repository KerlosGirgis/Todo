import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:todo/provider/notes_provider.dart';
import 'package:todo/provider/user_provider.dart';
import '../models/note.dart';
import '../services/authentication_service.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage(
      {super.key, required this.noteIndex});

  final int noteIndex;
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

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context,user,child) {
        return Consumer<NotesProvider>(
          builder: (context,notes,child) {
            titleController.text = notes.notes[widget.noteIndex].title;
            bodyController.text = notes.notes[widget.noteIndex].body;
            return Scaffold(
              backgroundColor: user.colorProvider.pageBackground,
              floatingActionButton: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                      heroTag: 2,
                      backgroundColor:
                      user.colorProvider.floatingActionButtonBackground,
                      foregroundColor:
                      user.colorProvider.floatingActionButtonForeground,
                      onPressed: () async {
                        if (notes.notes[widget.noteIndex].protected == 1) {
                          bool isAuthenticated = await authService.authenticate();
                          if (isAuthenticated) {
                            Provider.of<NotesProvider>(context, listen: false).deleteNote(notes.notes[widget.noteIndex].id!);
                            Navigator.pop(context);
                          }
                        } else {
                          Provider.of<NotesProvider>(context, listen: false).deleteNote(notes.notes[widget.noteIndex].id!);
                          Navigator.pop(context);
                        }
                      },
                      child: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      )),
                  const Padding(padding: EdgeInsets.only(bottom: 20)),
                  FloatingActionButton(
                    heroTag: 4,
                    backgroundColor:
                    user.colorProvider.floatingActionButtonBackground,
                    foregroundColor:
                    user.colorProvider.floatingActionButtonForeground,
                    onPressed: () {
                      if(notes.notes[widget.noteIndex].body.isNotEmpty){
                        updateAndroidWidget(notes.notes[widget.noteIndex].body);
                      }
                    },
                    child: const Icon(Icons.sticky_note_2_sharp),
                  ),
                  const Padding(padding: EdgeInsets.only(bottom: 20)),
                  FloatingActionButton(
                    heroTag: 3,
                    backgroundColor:
                    user.colorProvider.floatingActionButtonBackground,
                    foregroundColor:
                    user.colorProvider.floatingActionButtonForeground,
                    onPressed: () async {
                      try {
                        /*

                         */
                        Provider.of<NotesProvider>(context, listen: false).updateNote(Note(
                            id: notes.notes[widget.noteIndex].id,
                            title: titleController.text,
                            body: bodyController.text,
                            titleColor: notes.notes[widget.noteIndex].titleColor,
                            coverColor: notes.notes[widget.noteIndex].coverColor,
                            protected: notes.notes[widget.noteIndex].protected)).then((onValue){
                          notes.notes[widget.noteIndex].body=bodyController.text;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text("Saved Successfully"),
                            duration: Durations.long4,
                          ));
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Sorry, Something went wrong,note not saved"),
                          duration: Durations.long4,
                        ));
                      }
                    },
                    child: const Icon(Icons.save_sharp),
                  ),
                ],
              ),
              appBar: AppBar(
                backgroundColor: user.colorProvider.pageBackground,
                leading: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: user.colorProvider.noteEditorBackButton,
                    )),
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const Padding(padding: EdgeInsets.only(bottom: 10)),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: TextStyle(
                                color: user.colorProvider.noteEditorText,
                                fontSize: 30),
                            controller: titleController,
                            maxLines: 1,
                            maxLength: 50,
                            decoration: InputDecoration(
                                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                                hintText: "Title",
                                hintStyle: TextStyle(
                                    color: user.colorProvider.noteEditorText)),
                          ),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.only(bottom: 10)),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: bodyController,
                            maxLines: null,
                            style: TextStyle(
                                color: user.colorProvider.noteEditorText,
                                fontSize: 30),
                            decoration: InputDecoration(
                                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
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
