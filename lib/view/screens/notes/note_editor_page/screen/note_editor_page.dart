import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:todo/core/ui/feedback_toast.dart';
import 'package:todo/view/widgets/expandable_menu.dart';
import 'package:todo/view_model/notes_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';
import '../../../../../models/note.dart';
import '../../../../../services/authentication_service.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.note});

  final Note note;
  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final AuthenticationService authService = AuthenticationService();
  final UndoHistoryController _undoHistoryController = UndoHistoryController();
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
    return Consumer<UserViewModel>(
      builder: (context, user, child) {
        return Consumer<NotesViewModel>(
          builder: (context, notes, child) {
            return Scaffold(
              backgroundColor: user.colorManager.pageBackground,
              appBar: AppBar(
                surfaceTintColor: Colors.transparent,
                title: Text(
                  widget.note.title,
                  style: TextStyle(
                    fontSize: 30,
                    color: user.colorManager.wB,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: user.colorManager.pageBackground,
                leading: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: user.colorManager.wB,
                    )),
                actions: [
                  user.user.count == 1
                      ? Text(
                          "${bodyController.text.replaceAll("\n", "").replaceAll(" ", "").length}",
                          style: TextStyle(
                              fontSize: 20, color: user.colorManager.wB),
                        )
                      : const SizedBox.shrink(),
                  ExpandableMenu(
                      iconColor: user.colorManager.appBarIcons,
                      animationSpeed: 500,
                      width: MediaQuery.orientationOf(context) ==
                              Orientation.portrait
                          ? MediaQuery.sizeOf(context).width / 14
                          : MediaQuery.sizeOf(context).width / 22,
                      height: 45,
                      items: [
                        IconButton(
                            onPressed: () {
                              _undoHistoryController.undo();
                            },
                            icon: Icon(
                              Icons.undo,
                              color: user.colorManager.wB,
                            )),
                        IconButton(
                            onPressed: () {
                              _undoHistoryController.redo();
                            },
                            icon: Icon(
                              Icons.redo,
                              color: user.colorManager.wB,
                            )),
                        IconButton(
                            onPressed: () {
                              try {
                                Provider.of<NotesViewModel>(context,
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
                                  FeedbackToast.info("Saved Successfully");
                                });
                              } catch (e) {
                                FeedbackToast.error("Sorry, Something went wrong,note not saved");
                              }
                            },
                            icon: Icon(
                              Icons.save_sharp,
                              color: widget.note.body
                                          .compareTo(bodyController.text) ==
                                      0
                                  ? user.colorManager.wB
                                  : Colors.lightBlue,
                            )),
                        IconButton(
                            onPressed: () {
                              if (widget.note.body.isNotEmpty) {
                                try {
                                  notes.updateAndroidWidget(widget.note.body);
                                } catch (e) {
                                  FeedbackToast.error("Sorry, Something went wrong");
                                  return;
                                }
                                FeedbackToast.info("Note has been added to the widget");
                              }
                            },
                            icon: Icon(
                              Icons.sticky_note_2_sharp,
                              color: user.colorManager.wB,
                            )),
                        IconButton(
                            onPressed: () async {
                              if (widget.note.protected == 1) {
                                bool isAuthenticated =
                                    await authService.authenticate();
                                if (isAuthenticated) {
                                  notes.deleteNote(widget.note.id!);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } else {
                                  FeedbackToast.error("Authentication Failed");
                                }
                              } else {
                                Provider.of<NotesViewModel>(context,
                                        listen: false)
                                    .deleteNote(widget.note.id!);
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(
                              Icons.delete_sharp,
                              color: Colors.red,
                            )),
                      ])
                ],
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width / 1.1,
                            child: TextField(
                              undoController: _undoHistoryController,
                              onChanged: (value) {
                                if (user.user.autoSave == 1) {
                                  try {
                                    Provider.of<NotesViewModel>(context,
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
                                    FeedbackToast.error("Sorry, Something went wrong,note not saved");
                                  }
                                }
                              },
                              controller: bodyController,
                              maxLines: null,
                              textDirection: intl.Bidi.detectRtlDirectionality(
                                      bodyController.text)
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              style: TextStyle(
                                  fontFamily: user.user.casual == 1
                                      ? 'casual'
                                      : 'arial',
                                  fontWeight: user.user.casual == 1
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: user.colorManager.wB,
                                  fontSize: (26 * user.user.notesTextSize),
                                  decoration: TextDecoration.none,
                                  decorationColor:
                                      user.colorManager.wB),
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
              ),
            );
          },
        );
      },
    );
  }
}
