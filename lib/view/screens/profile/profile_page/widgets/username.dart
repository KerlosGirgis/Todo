import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../view_model/user_view_model.dart';
import 'edit_name_dialog.dart';

class UserName extends StatelessWidget {
  const UserName({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(
        builder: (context, user, child) {
      return Flexible(
        child: GestureDetector(
          onLongPress: () {
            showDialog(
                context: context,
                builder: (context) {
                  return const EditNameDialog();
                });
          },
          child: AutoSizeText(
            user.user.name,
            minFontSize: 30,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
                overflow: TextOverflow.clip,
                fontWeight: FontWeight.bold,
                fontSize: 40,
                color:
                Color(0xff3D5AFE).withValues(alpha: 0.9)),
          ),
        ),
      );});
  }
}