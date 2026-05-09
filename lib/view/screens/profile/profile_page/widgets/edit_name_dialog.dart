import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/core/ui/feedback_toast.dart';
import 'package:todo/view_model/user_view_model.dart';
import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../widgets/button.dart';

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
            backgroundColor: context.colors.pageBackground,
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
                      color: context.colors.dialogIconContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit,
                      color: context.colors.dialogIcon,
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
                        color: context.colors.wB),
                  ),
                ),
                Expanded(
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.close, color: context.colors.dialogExitIcon),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  maxLines: 1,
                  maxLength: 20,
                  style: TextStyle(
                      fontSize: 22, color: context.colors.wB),
                  decoration: InputDecoration(
                      labelText: "Name",
                      labelStyle: TextStyle(
                          fontSize: 30,
                          color: context.colors.wB),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: context.colors.cardBackground,
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
                            FeedbackToast.info("Name Updated");
                          });
                          Navigator.of(context).pop();
                        } else {
                          FeedbackToast.error("Name can't be empty");
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
