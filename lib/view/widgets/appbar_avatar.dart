import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:todo/core/ui/feedback_toast.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:todo/services/verse_service.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/utils/avatar_utils.dart';

class AppbarAvatar extends StatelessWidget {
  const AppbarAvatar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(
      builder: (context, user, child) {
        return GestureDetector(
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xff3D5AFE), Colors.blueAccent],
              ),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.black,
              backgroundImage: user.user.pic.startsWith("0")
                  ? AssetImage(AvatarUtils.getAvatar(user.user.pic))
                  : FileImage(File(user.user.pic)) as ImageProvider,
            ),
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
                          context.colors.cardBackground,
                      title: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [
                                  Color(0xff3D5AFE),
                                  Colors.transparent,
                                ],
                                stops: [0.6, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xff3D5AFE).withValues(alpha: 0.4),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundImage: user.user.pic.startsWith("0")
                                    ? AssetImage(AvatarUtils.getAvatar(user.user.pic))
                                    : FileImage(File(user.user.pic)) as ImageProvider,
                                radius: MediaQuery.of(context).orientation == Orientation.portrait
                                    ? MediaQuery.sizeOf(context).width / 4
                                    : MediaQuery.sizeOf(context).height / 4,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
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
                                            text: VerseService.getDailyVerse()))
                                        .then((_) {
                                      FeedbackToast.info("Verse copied to clipboard");
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
                                            VerseService.getDailyVerse(),
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
