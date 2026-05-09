import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../view_model/user_view_model.dart';
import '../../../../../core/utils/avatar_utils.dart';

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.number});
  final String number;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        child: CircleAvatar(
          backgroundColor: Colors.transparent,
          backgroundImage: AssetImage(AvatarUtils.getAvatar(number)),
          radius: MediaQuery.orientationOf(context)==Orientation.portrait?MediaQuery.sizeOf(context).width/7:MediaQuery.sizeOf(context).height/7,
        ),
        onTap: () {
          Provider.of<UserViewModel>(context, listen: false).editPic(number);
          Navigator.pop(context);
        },
      ),
    );
  }
}
