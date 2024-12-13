import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/user_provider.dart';
import '../../services/icon_provider.dart';

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.number});
  final String number;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: CircleAvatar(
        backgroundColor: Colors.transparent,
        backgroundImage: AssetImage(IconProvider.getAvatar(number)),
        radius: 50,
      ),
      onTap: () {
        Provider.of<UserProvider>(context, listen: false).editPic(number);
        Navigator.pop(context);
      },
    );
  }
}
