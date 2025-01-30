import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/provider/user_provider.dart';
import '../../models/note.dart';
import '../../provider/notes_provider.dart';
import '../../services/authentication_service.dart';
import 'button.dart';

class AddNoteDialog extends StatelessWidget {
  const AddNoteDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final AuthenticationService authService = AuthenticationService();
    TextEditingController titleController = TextEditingController();
    return Consumer<UserProvider>(
      builder: (context, user, child) {
        int isProtected = 0;
        String titleColor = Colors.white.hex;
        String coverColor = const Color(0xff1E1E1E).hex;
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
              scrollable: true,
              backgroundColor: user.colorProvider.addTaskAlertBackground,
              title: Row(
                mainAxisSize: MainAxisSize.min,
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
                    ),
                  ),
                  const Spacer(
                    flex: 10,
                  ),
                  const Text(
                    "Add Note",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                  ),
                  const Spacer(
                    flex: 10,
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                  )
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    maxLines: 1,
                    decoration: InputDecoration(
                        labelText: "Title",
                        labelStyle: TextStyle(
                            fontSize: 30,
                            color: user.colorProvider.addTaskAlertText),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15))),
                  ),
                  const Padding(padding: EdgeInsets.only(bottom: 15)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Title : ",
                        style: TextStyle(fontSize: 24),
                      ),
                      GestureDetector(
                        child: CircleAvatar(
                          backgroundColor: titleColor.toColor,
                        ),
                        onTap: () {
                          ColorPicker(
                            onColorChanged: (Color color) {
                              setState(() {
                                titleColor = color.hex;
                              });
                            },
                          ).showPickerDialog(context);
                        },
                      ),
                      IconButton(
                          onPressed: () {
                            setState(() {
                              titleColor = Colors.white.hex;
                            });
                          },
                          icon: const Icon(Icons.undo_sharp)),
                      const Spacer(
                        flex: 1,
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.only(bottom: 15)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Cover : ",
                        style: TextStyle(fontSize: 24),
                      ),
                      GestureDetector(
                        child: CircleAvatar(
                          backgroundColor: coverColor.toColor,
                        ),
                        onTap: () {
                          ColorPicker(
                            onColorChanged: (Color color) {
                              setState(() {
                                coverColor = color.hex;
                              });
                            },
                          ).showPickerDialog(context);
                        },
                      ),
                      IconButton(
                          onPressed: () {
                            setState(() {
                              coverColor = const Color(0xff1E1E1E).hex;
                            });
                          },
                          icon: const Icon(Icons.undo_sharp)),
                      const Spacer(
                        flex: 1,
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.only(bottom: 15)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Fingerprint",
                        style: TextStyle(fontSize: 24),
                      ),
                      const Spacer(
                        flex: 1,
                      ),
                      Switch(
                          value: isProtected == 0 ? false : true,
                          activeColor: Color(0xff3D5AFE),
                          onChanged: (v) async {
                            if (isProtected == 0) {
                              bool isBioAvailable =
                                  await authService.authenticate();
                              if (isBioAvailable) {
                                setState(() {
                                  isProtected = 1;
                                });
                              } else {
                                Fluttertoast.showToast(
                                    msg: "Authentication Failed",
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                    backgroundColor: Colors.red,
                                    textColor: Colors.white,
                                    fontSize: 19.0);
                              }
                            } else if (isProtected == 1) {
                              setState(() {
                                isProtected = 0;
                              });
                            }
                          })
                    ],
                  ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Button(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      label: 'Cancel',
                      status: false,
                      fontSize: 18,
                      size: 1,
                    ),
                    Padding(
                        padding: EdgeInsets.only(
                            right: MediaQuery.of(context).size.width / 25)),
                    Button(
                      onPressed: () {
                        if (titleController.text.isEmpty) {
                          Fluttertoast.showToast(
                              msg: "Title can't be empty",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                              fontSize: 19.0);
                          return;
                        }
                        Navigator.pop(context);
                        Provider.of<NotesProvider>(context, listen: false)
                            .addNote(Note(
                          title: titleController.text,
                          body: '',
                          titleColor: titleColor,
                          coverColor: coverColor,
                          protected: isProtected,
                        ))
                            .then((value) {
                          Fluttertoast.showToast(
                              msg: "Note Added",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: const Color(0xff1E1E1E),
                              textColor: Colors.white,
                              fontSize: 19.0);
                        });
                      },
                      label: 'Save',
                      status: true,
                      fontSize: 18,
                      size: 1,
                    ),
                  ],
                )
              ],
            );
          },
        );
      },
    );
  }
}
