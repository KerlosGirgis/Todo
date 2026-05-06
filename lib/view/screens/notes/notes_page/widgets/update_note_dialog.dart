import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/notes_view_model.dart';
import 'package:todo/view_model/user_view_model.dart';

import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/note.dart';
import '../../../../widgets/button.dart';

class UpdateNoteDialog extends StatefulWidget {
  const UpdateNoteDialog({super.key, required this.note});
  final Note note;
  @override
  State<UpdateNoteDialog> createState() => _UpdateNoteDialogState();
}

class _UpdateNoteDialogState extends State<UpdateNoteDialog> {
  TextEditingController titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesViewModel>().setTempNote(widget.note);
      titleController.text=widget.note.title;
      titleController.addListener(() {
        context.read<NotesViewModel>()
            .setTempNoteTitle(titleController.text);
      });
    });
  }

  @override
  void dispose() {
    context.read<NotesViewModel>().clearTempNote();
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserViewModel, NotesViewModel>(
      builder: (context, user, notes, child) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: user.colorManager.pageBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          elevation: 2,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: user.colorManager.dialogIconContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_note,
                    color: user.colorManager.dialogIcon,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  "Edit Note",
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      color: user.colorManager.wB),
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.close,
                      color: user.colorManager.dialogExitIcon),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: user.colorManager.dialogExitContainer,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ),
              )
            ],
          ),
          content: Column(
            spacing: MediaQuery.sizeOf(context).height / 50,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 22, color: user.colorManager.wB),
                decoration: InputDecoration(
                  labelText: "Title",
                  labelStyle: TextStyle(
                      fontSize: 30, color: user.colorManager.wB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: user.colorManager.cardBackground,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ColorPicker(
                    onColorChanged: (Color color) {
                      notes.setTempNoteTitleColor(color.hex);
                    },
                  ).showPickerDialog(context);
                },
                onLongPress: () {
                  notes.setTempNoteTitleColor("FFFFFF");
                  FeedbackToast.info("Title Color Cleared");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: user.colorManager.cardBackground,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  elevation: 1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Icon(Icons.format_color_text_rounded,
                        color: user.colorManager.wB, size: 24),
                    Spacer(
                      flex: 1,
                    ),
                    Flexible(
                      flex: 4,
                      child: Text(
                        overflow: TextOverflow.ellipsis,
                        "Title ",
                        style: TextStyle(
                            fontSize: 24,
                            color: user.colorManager.wB),
                      ),
                    ),
                    Flexible(
                      flex: 8,
                      child: Container(
                          alignment: Alignment.center,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 14),
                          decoration: BoxDecoration(
                              color: notes.tempNote.titleColor.toColor,
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withAlpha(50),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: const Offset(0, 0),
                                ),
                              ])),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ColorPicker(
                    onColorChanged: (Color color) {
                      notes.setTempNoteCoverColor(color.hex);
                    },
                  ).showPickerDialog(context);
                },
                onLongPress: () {
                  notes.setTempNoteCoverColor("1E1E1E");
                  FeedbackToast.info("Cover Color Cleared");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: user.colorManager.cardBackground,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  elevation: 1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Icon(Icons.color_lens_rounded,
                        color: user.colorManager.wB, size: 24),
                    Spacer(
                      flex: 1,
                    ),
                    Flexible(
                      flex: 4,
                      child: Text(
                        "Cover ",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 24,
                            color: user.colorManager.wB),
                      ),
                    ),
                    Flexible(
                      flex: 8,
                      child: Container(
                          alignment: Alignment.center,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 14),
                          decoration: BoxDecoration(
                              color: notes.tempNote.coverColor.toColor,
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withAlpha(50),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: const Offset(0, 0),
                                ),
                              ])),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    Result status = await notes.toggleTempNoteProtection();
                    if (status is Failure) {
                      FeedbackToast.error(status.message);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: user.colorManager.cardBackground,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    elevation: 1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Icon(Icons.fingerprint_rounded,
                          color: user.colorManager.wB, size: 24),
                      Spacer(
                        flex: 1,
                      ),
                      Flexible(
                        flex: 7,
                        fit: FlexFit.tight,
                        child: Text(
                          "Fingerprint",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 24,
                              color: user.colorManager.wB),
                        ),
                      ),
                      Spacer(
                        flex: 1,
                      ),
                      Flexible(
                        child: Switch(
                            value: notes.tempNote.protected == 1,
                            activeThumbColor: Color(0xff3D5AFE),
                            onChanged: (_) async {
                              Result status =
                              await notes.toggleTempNoteProtection();
                              if (status is Failure) {
                                FeedbackToast.error(status.message);
                              }
                            }),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Row(
              spacing: MediaQuery.of(context).size.width / 25,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Button(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    label: 'Cancel',
                    status: false,
                    fontSize: 18,
                    size: 1,
                  ),
                ),
                Expanded(
                  child: Button(
                    onPressed: () async {
                      if (notes.tempNote.title.isEmpty) {
                        FeedbackToast.error("Title can't be empty");
                        return;
                      }
                      await context.read<NotesViewModel>().updateNote(notes.tempNote);
                      FeedbackToast.info("Note Updated");
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    label: 'Update',
                    status: true,
                    fontSize: 18,
                    size: 1,
                  ),
                ),
              ],
            )
          ],
        );
      },
    );
  }
}

