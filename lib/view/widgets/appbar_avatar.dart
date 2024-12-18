import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/provider/user_provider.dart';
import 'package:todo/services/verse_manager.dart';

import '../../services/icon_provider.dart';

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
                            SizedBox(
                              width: MediaQuery.of(context).size.width/1.5,
                              child: Text(
                                user.user.name,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white, fontSize: 42),
                              ),
                            ),
                          ],
                        ),
                        Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height/60)),
                        Center(
                          child: GestureDetector(
                            onLongPress: (){
                              Clipboard.setData(ClipboardData(text: VerseManager.getDailyVerse())).then((_) {
                                Fluttertoast.showToast(
                                    msg: "Verse copied to clipboard",
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                    backgroundColor:
                                    user.colorProvider.cardBackground,
                                    textColor: user.colorProvider.appTitle,
                                    fontSize: 19.0);
                              });
                            },
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      maxLines: 1,
                                      //overflow: TextOverflow.visible,
                                      "🕯️Verse Of The Day🕯️",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      VerseManager.getDailyVerse(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
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