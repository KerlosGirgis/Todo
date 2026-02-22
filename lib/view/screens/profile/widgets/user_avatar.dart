import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../services/avatar_manager.dart';
import '../../../../view_model/user_view_model.dart';
import 'avatars_list_dialog.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(builder: (context, user, child) {
      return Stack(
        children: [
          CircleAvatar(
            backgroundImage: user.user.pic.startsWith("0")
                ? AssetImage(AvatarManager.getAvatar(user.user.pic))
                : FileImage(File(user.user.pic)) as ImageProvider,
            radius: MediaQuery.of(context).orientation == Orientation.portrait
                ? MediaQuery.sizeOf(context).width / 4
                : MediaQuery.sizeOf(context).height / 4,
            backgroundColor: Colors.transparent,
          ),
          Positioned(
            right: MediaQuery.sizeOf(context).width / 50,
            bottom: MediaQuery.sizeOf(context).height / 50,
            child: SizedBox(
              width: MediaQuery.of(context).orientation == Orientation.portrait
                  ? MediaQuery.sizeOf(context).width / 10
                  : MediaQuery.sizeOf(context).height / 10,
              height: MediaQuery.of(context).orientation == Orientation.portrait
                  ? MediaQuery.sizeOf(context).width / 10
                  : MediaQuery.sizeOf(context).height / 10,
              child: FloatingActionButton(
                backgroundColor: Colors.white,
                elevation: 3,
                shape: const CircleBorder(),
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) =>
                          StatefulBuilder(builder: (context, setState) {
                            return AlertDialog(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              backgroundColor: user.colorManager.pageBackground,
                              content: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      child: CircleAvatar(
                                        backgroundImage: AssetImage(
                                            AvatarManager.getAvatar("000")),
                                        radius:
                                            MediaQuery.sizeOf(context).width /
                                                7,
                                        backgroundColor: Colors.transparent,
                                      ),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) =>
                                              AvatarsListDialog(),
                                        ).then((_) {
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      child: CircleAvatar(
                                        backgroundImage:
                                            AssetImage("assets/person.png"),
                                        radius:
                                            MediaQuery.sizeOf(context).width /
                                                7,
                                      ),
                                      onTap: () async {
                                        user.pickAndSaveImage();
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }));
                },
                child: Icon(
                  Icons.edit,
                  color: Colors.blue,
                  size:
                      MediaQuery.of(context).orientation == Orientation.portrait
                          ? MediaQuery.sizeOf(context).width / 15
                          : MediaQuery.sizeOf(context).height / 20,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
