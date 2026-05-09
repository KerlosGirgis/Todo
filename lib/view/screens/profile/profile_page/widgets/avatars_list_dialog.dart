import 'package:flutter/material.dart';
import 'package:todo/core/extensions/theme_extensions.dart';

import 'avatar.dart';

class AvatarsListDialog extends StatelessWidget {
  const AvatarsListDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          backgroundColor: context.colors.pageBackground,
          scrollable: true,
          content: Column(
            spacing: MediaQuery.sizeOf(context).height / 90,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                spacing: MediaQuery.sizeOf(context).width / 90,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Avatar(number: "000"),
                  Avatar(number: "001"),
                ],
              ),
              Row(
                spacing: MediaQuery.sizeOf(context).width / 90,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Avatar(number: "002"),
                  Avatar(number: "003"),
                ],
              ),
              Row(
                spacing: MediaQuery.sizeOf(context).width / 90,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Avatar(number: "004"),
                  Avatar(number: "005"),
                ],
              ),
              Row(
                spacing: MediaQuery.sizeOf(context).width / 90,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Avatar(number: "006"),
                  Avatar(number: "007"),
                ],
              ),
              Row(
                spacing: MediaQuery.sizeOf(context).width / 90,
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
  }
}
