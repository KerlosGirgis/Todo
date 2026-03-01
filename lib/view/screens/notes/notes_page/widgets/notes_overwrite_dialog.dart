import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../view_model/notes_view_model.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/button.dart';

class NotesOverwriteDialog extends StatefulWidget {
  const NotesOverwriteDialog({super.key});

  @override
  State<NotesOverwriteDialog> createState() => _NotesOverwriteDialogState();
}

class _NotesOverwriteDialogState extends State<NotesOverwriteDialog> {
  bool overwrite = true;
  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(builder: (context, user, child) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 2,
        scrollable: true,
        backgroundColor: user.colorManager.pageBackground,
        title: Row(
          mainAxisSize: MainAxisSize.min,
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
                  Icons.settings_backup_restore_rounded,
                  color: user.colorManager.dialogIcon,
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Text(
                "Restore",
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    color: user.colorManager.wB),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(
                  Icons.close,
                  color: user.colorManager.dialogExitIcon,
                ),
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
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          RadioGroup(
            groupValue: overwrite,
              onChanged: (v) {
                setState(() {
                  overwrite = v ?? false;
                });
              },
              child: Column(
                children: [
                  RadioListTile(
                    title: Text(
                      "Overwrite existing notes",
                      style: TextStyle(color: user.colorManager.wB),
                    ),
                    value: true,
                    activeColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  RadioListTile(
                    title: Text(
                      "Keep existing notes",
                      style: TextStyle(color: user.colorManager.wB),
                    ),
                    value: false,
                    activeColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ],
              )),
        ]),
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
                  onPressed: () {
                    Provider.of<NotesViewModel>(context, listen: false)
                        .restore(overwrite)
                        .then((v) {
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    });
                  },
                  label: 'Import',
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
