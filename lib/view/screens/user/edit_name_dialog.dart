import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/user_view_model.dart';
import '../../widgets/button.dart';

class EditNameDialog extends StatelessWidget {
  const EditNameDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(
      builder: (context, user, child) {
        TextEditingController nameController = TextEditingController();
        nameController.text = user.user.name;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: user.colorManager.pageBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            elevation: 2,
            scrollable: true,
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
                      Icons.edit,
                      color: user.colorManager.dialogIcon,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    "Edit Name",
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                        color: user.colorManager.homePageText),
                  ),
                ),
                Expanded(
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.close, color: user.colorManager.dialogExitIcon),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  maxLines: 1,
                  maxLength: 20,
                  style: TextStyle(
                      fontSize: 22, color: user.colorManager.homePageText),
                  decoration: InputDecoration(
                      labelText: "Name",
                      labelStyle: TextStyle(
                          fontSize: 30,
                          color: user.colorManager.homePageText),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: user.colorManager.cardBackground,
                  ),
                ),
              ],
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Button(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      label: "Cancel",
                      status: false,
                      fontSize: 18,
                      size: 1,
                    ),
                  ),
                  Padding(
                      padding: EdgeInsets.only(
                          right: MediaQuery.of(context).size.width / 25)),
                  Expanded(
                    child: Button(
                      onPressed: () async {
                        if (nameController.text.isNotEmpty) {
                          Provider.of<UserViewModel>(context, listen: false)
                              .editName(nameController.text)
                              .then((value) {
                            Fluttertoast.showToast(
                                msg: "Name Updated",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: const Color(0xff1E1E1E),
                                textColor: Colors.white,
                                fontSize: 19.0);
                          });
                          Navigator.of(context).pop();
                        } else {
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
                  ),
                ],
              ),
            ],
          );
        });
      },
    );
  }
}
