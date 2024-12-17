import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/provider/user_provider.dart';
import 'button.dart';

class EditNameDialog extends StatelessWidget {
  const EditNameDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, user, child) {
        TextEditingController nameController = TextEditingController();
        nameController.text = user.user.name;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            scrollable: true,
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
                  "Edit Name",
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
            backgroundColor: user.colorProvider.addTaskAlertBackground,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  maxLines: 1,
                  maxLength: 20,
                  decoration: InputDecoration(
                      labelText: "Name",
                      labelStyle: TextStyle(
                          fontSize: 30,
                          color: user.colorProvider.addTaskAlertText),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15))),
                ),
              ],
            ),
            actions: [
              Button(
                onPressed: () {
                  Navigator.pop(context);
                },
                label: "Cancel",
                status: false,
                fontSize: 18,
                size: 1,
              ),
              Padding(
                  padding: EdgeInsets.only(
                      right: MediaQuery.of(context).size.width / 25)),
              Button(
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    Provider.of<UserProvider>(context, listen: false)
                        .editName(nameController.text)
                        .then((value) {
                      Fluttertoast.showToast(
                          msg: "Name Updated",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: user.colorProvider.cardBackground,
                          textColor: user.colorProvider.appTitle,
                          fontSize: 19.0);
                    });
                    Navigator.of(context).pop();
                  }
                  else{
                    Fluttertoast.showToast(
                        msg: "Name can't be empty",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                        fontSize: 19.0);
                  }
                },
                label: 'Update',
                status: true,
                fontSize: 18,
                size: 1,
              ),
            ],
          );
        });
      },
    );
  }
}
