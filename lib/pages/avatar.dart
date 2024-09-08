import 'package:flutter/material.dart';

import '../services/icon_provider.dart';

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.saveAvatar, required this.number});
  final Function saveAvatar;
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
        saveAvatar(number);
        Navigator.pop(context);
      },
    );
  }
}
