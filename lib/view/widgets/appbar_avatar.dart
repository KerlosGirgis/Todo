import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo/provider/user_provider.dart';

import '../../services/icon_provider.dart';
import '../pages/profile_page.dart';

class AppbarAvatar extends StatelessWidget {
  const AppbarAvatar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context,user,child) {
        return GestureDetector(
          child: CircleAvatar(
            backgroundColor: Colors.transparent,
            backgroundImage: user.user.pic
                .substring(0, 1)
                .compareTo("0") ==
                0
                ? AssetImage(IconProvider.getAvatar(user.user.pic))
                : FileImage(File(user.user.pic)),
            radius: 18,
          ),
          onTap: () {
            showDialog(
                useRootNavigator: true,
                context: context,
                builder: (e) {
                  return AlertDialog(
                    scrollable: true,
                    backgroundColor:
                    user.colorProvider.profileAlertBackground,
                    title: CircleAvatar(
                      radius: 130,
                      backgroundColor: Colors.transparent,
                      backgroundImage: user.user.pic
                          .substring(0, 1)
                          .compareTo("0") ==
                          0
                          ? AssetImage(
                          IconProvider.getAvatar(user.user.pic))
                          : FileImage(File(user.user.pic)),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                                child: Text(
                                  "${user.user.firstName} ${user.user.lastName}",
                                  maxLines: 2,
                                  overflow: TextOverflow.clip,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 42),
                                ))
                          ],
                        ),
                      ],
                    ),
                  );
                });
          },
        );
      },
    );
  }
}