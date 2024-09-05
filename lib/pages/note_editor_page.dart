import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:todo/services/color_provider.dart';
import 'package:todo/services/database_service.dart';

import '../models/note.dart';
import '../services/authentication_service.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage(
      {super.key, required this.colorProvider, required this.note});

  final ColorProvider colorProvider;
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.colorProvider.pageBackground,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
              heroTag: 2,
              backgroundColor:
                  widget.colorProvider.floatingActionButtonBackground,
              foregroundColor:
                  widget.colorProvider.floatingActionButtonForeground,
              onPressed: () async {
                if (widget.note.protected == 1) {
                  bool isAuthenticated = await authService.authenticate();
                  if (isAuthenticated) {
                    await DatabaseService().deleteNote(widget.note.id!);
                    Navigator.pop(context);
                  }
                } else {
                  await DatabaseService().deleteNote(widget.note.id!);
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
            widget.colorProvider.floatingActionButtonBackground,
            foregroundColor:
            widget.colorProvider.floatingActionButtonForeground,
            onPressed: () {
              if(widget.note.body.isNotEmpty){
                updateAndroidWidget(widget.note.body);
              }
            },
            child: const Icon(Icons.sticky_note_2_sharp),
          ),
          const Padding(padding: EdgeInsets.only(bottom: 20)),
          FloatingActionButton(
            heroTag: 3,
            backgroundColor:
                widget.colorProvider.floatingActionButtonBackground,
            foregroundColor:
                widget.colorProvider.floatingActionButtonForeground,
            onPressed: () async {
              try {
                await DatabaseService().updateNote(Note(
                    id: widget.note.id,
                    title: titleController.text,
                    body: bodyController.text,
                    titleColor: widget.note.titleColor,
                    coverColor: widget.note.coverColor,
                    protected: widget.note.protected)).then((onValue){
                      widget.note.body=bodyController.text;
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
        backgroundColor: widget.colorProvider.pageBackground,
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: widget.colorProvider.noteEditorBackButton,
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
                        color: widget.colorProvider.noteEditorText,
                        fontSize: 30),
                    controller: titleController,
                    maxLines: 1,
                    maxLength: 50,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                        hintText: "Title",
                        hintStyle: TextStyle(
                            color: widget.colorProvider.noteEditorText)),
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
                        color: widget.colorProvider.noteEditorText,
                        fontSize: 30),
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                        hintStyle: TextStyle(
                            color: widget.colorProvider.noteEditorText)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
