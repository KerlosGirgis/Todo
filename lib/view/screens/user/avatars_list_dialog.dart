import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/user_view_model.dart';

import '../../widgets/avatar.dart';

class AvatarsListDialog extends StatelessWidget {
  const AvatarsListDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(
      builder: (context, user,child) {
        return StatefulBuilder(builder: (context,setState) {
          return AlertDialog(
            backgroundColor: user
                .colorManager
                .addTaskAlertBackground,
            scrollable:
            true,
            content:
            Column(
              spacing: MediaQuery.sizeOf(context).height/90,
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Row(
                  spacing: MediaQuery.sizeOf(context).width/90,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(number: "000"),
                    Avatar(number: "001"),
                  ],
                ),
                Row(
                  spacing: MediaQuery.sizeOf(context).width/90,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(number: "002"),
                    Avatar(number: "003"),
                  ],
                ),
                Row(
                  spacing: MediaQuery.sizeOf(context).width/90,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(number: "004"),
                    Avatar(number: "005"),
                  ],
                ),
                Row(
                  spacing: MediaQuery.sizeOf(context).width/90,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(number: "006"),
                    Avatar(number: "007"),
                  ],
                ),
                Row(
                  spacing: MediaQuery.sizeOf(context).width/90,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(number: "008"),
                    Avatar(number: "009"),
                  ],
                )
              ],
            ),
          );
        },
        );
      },
    );
  }
}