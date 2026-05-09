import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../view_model/notes_view_model.dart';
import '../../../../widgets/button.dart';

class AddNoteDialog extends StatefulWidget {
  const AddNoteDialog({super.key});

  @override
  State<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<AddNoteDialog> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesViewModel>().newTempNote();
    });
  }

  @override
  void dispose() {
    context.read<NotesViewModel>().clearTempNote();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesViewModel>(
        builder: (context, note, child) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
        elevation: 2,
        scrollable: true,
        backgroundColor: context.colors.pageBackground,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.dialogIconContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.note_add,
                  color: context.colors.dialogIcon,
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Text(
                "Add Note",
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    color: context.colors.wB),
              ),
            ),
            Expanded(
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon:
                    Icon(Icons.close, color: context.colors.dialogExitIcon),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.dialogExitContainer,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            )
          ],
        ),
        content: Column(
          spacing: MediaQuery.of(context).size.height / 50,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              maxLines: 1,
              style: TextStyle(fontSize: 22, color: context.colors.wB),
              decoration: InputDecoration(
                labelText: "Title",
                labelStyle: TextStyle(
                  fontSize: 30,
                  color: context.colors.wB,
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: context.colors.cardBackground,
              ),
              onChanged: (v){
                note.setTempNoteTitle(v);
              },
            ),
            ElevatedButton(
              onPressed: () {
                ColorPicker(
                  onColorChanged: (Color color) {
                    note.setTempNoteTitleColor(color.hex);
                  },
                ).showPickerDialog(context);
              },
              onLongPress: () {
                note.setTempNoteTitleColor("FFFFFF");
                FeedbackToast.info("Title Color Cleared");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.cardBackground,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(Icons.format_color_text_rounded,
                      color: context.colors.wB, size: 24),
                  Spacer(
                    flex: 1,
                  ),
                  Flexible(
                    flex: 4,
                    child: Text(
                      "Title ",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 24, color: context.colors.wB),
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
                          color: note.tempNote.titleColor.toColor,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withAlpha(50),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 0),
                            ),
                          ]),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ColorPicker(
                  onColorChanged: (Color color) {
                    note.setTempNoteCoverColor(color.hex);
                  },
                ).showPickerDialog(context);
              },
              onLongPress: () {
                note.setTempNoteCoverColor("1E1E1E");
                FeedbackToast.info("Cover Color Cleared");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.cardBackground,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(Icons.color_lens_rounded,
                      color: context.colors.wB, size: 24),
                  Spacer(
                    flex: 1,
                  ),
                  Flexible(
                    flex: 4,
                    child: Text(
                      "Cover ",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 24, color: context.colors.wB),
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
                          color: note.tempNote.coverColor.toColor,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withAlpha(50),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 0),
                            ),
                          ]),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  Result status = await note.toggleTempNoteProtection();
                  if (status is Failure) {
                    FeedbackToast.error(status.message);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.cardBackground,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  elevation: 1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fingerprint_rounded,
                        color: context.colors.wB, size: 24),
                    Spacer(
                      flex: 1,
                    ),
                    Flexible(
                      flex: 7,
                      fit: FlexFit.tight,
                      child: Text(
                        "Fingerprint",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 24, color: context.colors.wB),
                      ),
                    ),
                    Spacer(
                      flex: 1,
                    ),
                    Flexible(
                      child: Switch(
                          value: note.tempNote.protected == 1,
                          activeThumbColor: Color(0xff3D5AFE),
                          onChanged: (_) async {
                            Result status =
                                await note.toggleTempNoteProtection();
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
            spacing: MediaQuery.sizeOf(context).width / 25,
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
                    if (note.tempNote.title.isEmpty) {
                      FeedbackToast.error("Title can't be empty");
                      return;
                    }
                    await context.read<NotesViewModel>().addNote(note.tempNote);
                    FeedbackToast.info("Note Added");
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  label: 'Save',
                  status: true,
                  fontSize: 18,
                  size: 1,
                ),
              ),
            ],
          )
        ],
      );
    });
  }
}
