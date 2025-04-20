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
      builder: (context, user, child) {
        return GestureDetector(
          child: CircleAvatar(
            backgroundColor: Colors.transparent,
            backgroundImage: user.user.pic.substring(0, 1).compareTo("0") == 0
                ? AssetImage(IconProvider.getAvatar(user.user.pic))
                : FileImage(File(user.user.pic)),
            radius: 18,
          ),
          onTap: () {
            showGeneralDialog(
              useRootNavigator: true,
              context: context,
              barrierDismissible: true,
              barrierLabel:
                  MaterialLocalizations.of(context).modalBarrierDismissLabel,
              pageBuilder: (BuildContext context, Animation<double> animation,
                  Animation<double> secondaryAnimation) {
                return StatefulBuilder(
                  builder: (BuildContext context, setState) {
                    return AlertDialog(
                      scrollable: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      backgroundColor:
                          user.colorManager.profileAlertBackground,
                      title: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 130,
                            backgroundColor: Colors.transparent,
                            backgroundImage:
                                user.user.pic.substring(0, 1).compareTo("0") ==
                                        0
                                    ? AssetImage(
                                        IconProvider.getAvatar(user.user.pic))
                                    : FileImage(File(user.user.pic)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Text(
                                  user.user.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 42),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          user.user.verse == 1
                              ? GestureDetector(
                                  onLongPress: () {
                                    Clipboard.setData(ClipboardData(
                                            text: VerseManager.getDailyVerse()))
                                        .then((_) {
                                      Fluttertoast.showToast(
                                          msg: "Verse copied to clipboard",
                                          toastLength: Toast.LENGTH_SHORT,
                                          gravity: ToastGravity.BOTTOM,
                                          backgroundColor:
                                              const Color(0xff1E1E1E),
                                          textColor: Colors.white,
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
                                          Row(
                                            children: [
                                              Expanded(
                                                child: const Text(
                                                  "🕯️Bible Verse🕯️",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blueAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
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
                                )
                              : const SizedBox.shrink()
                        ],
                      ),
                    );
                  },
                );
              },
              transitionBuilder:
                  (context, animation, secondaryAnimation, child) {
                var fadeAnimation = CurvedAnimation(
                    parent: animation, curve: Curves.easeInOutSine);
                var scaleAnimation =
                    Tween<double>(begin: 0.95, end: 1).animate(fadeAnimation);
                return FadeTransition(
                  opacity: fadeAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: child,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
