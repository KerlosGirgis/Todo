import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/tasks_view_model.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../widgets/button.dart';

class TasksOverwriteDialog extends StatefulWidget {
  const TasksOverwriteDialog({super.key});

  @override
  State<TasksOverwriteDialog> createState() => _TasksOverwriteDialogState();
}

class _TasksOverwriteDialogState extends State<TasksOverwriteDialog> {
  bool overwrite = true;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      scrollable: true,
      backgroundColor: context.colors.pageBackground,
      title: Row(
        mainAxisSize: MainAxisSize.min,
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
                Icons.settings_backup_restore_rounded,
                color: context.colors.dialogIcon,
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
                  color: context.colors.wB),
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
                color: context.colors.dialogExitIcon,
              ),
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
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        RadioGroup(
            onChanged: (v) {
              setState(() {
                overwrite = v ?? false;
              });
            },
            groupValue: overwrite,
            child: Column(
              children: [
                RadioListTile(
                  title: Text(
                    "Overwrite existing Tasks",
                    style: TextStyle(color: context.colors.wB),
                  ),
                  value: true,
                  activeColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                RadioListTile(
                  title: Text(
                    "Keep existing Tasks",
                    style: TextStyle(color: context.colors.wB),
                  ),
                  value: false,
                  activeColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ],
            ))
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
                  Provider.of<TasksViewModel>(context, listen: false)
                      .restore(overwrite)
                      .then((result) {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                    if (result is Success) {
                      FeedbackToast.success(result.message);
                    } else if (result is Failure) {
                      FeedbackToast.error(result.message);
                    } else if (result is Info) {
                      FeedbackToast.info(result.message);
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
  }
}
