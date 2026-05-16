import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../../../../../core/extensions/theme_extensions.dart';
import '../widgets/chart.dart';
import '../widgets/settings_page_view.dart';
import '../widgets/user_avatar.dart';
import '../widgets/indicator.dart';
import '../widgets/username.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
  });

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 40,
          forceMaterialTransparency: true,
          leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(
                Icons.arrow_back,
                color: context.colors.wB,
                size: 32,
              )),
          actions: [
            IconButton(
                onPressed: () {
                  toastification.show(
                      title: Text(
                        "Developed with ❤️ by Kerlos Girgis",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      type: ToastificationType.info,
                      autoCloseDuration: const Duration(seconds: 5),
                      dragToClose: true,
                      alignment: AlignmentGeometry.directional(0, 1),
                      style: ToastificationStyle.flat);
                },
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: context.colors.wB,
                ))
          ],
        ),
        backgroundColor: context.colors.pageBackground,
        extendBodyBehindAppBar: true,
        body: MediaQuery.of(context).orientation == Orientation.portrait ||
                MediaQuery.sizeOf(context).aspectRatio < 1.5
            ? SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          UserAvatar(),
                        ],
                      ),
                    ),
                    Flexible(
                      flex: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          UserName(),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Expanded(
                            child: Chart(),
                          ),
                          Expanded(
                            child: Column(
                              spacing: MediaQuery.heightOf(context) / 90,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Indicator(
                                  color: Color(0xff3D5AFE),
                                  text: 'Finished',
                                  isSquare: false,
                                  textColor: context.colors.wB,
                                  size: 25,
                                ),
                                Indicator(
                                  color: context.colors.wB
                                      .withValues(alpha: 0.4),
                                  text: 'UnFinished',
                                  isSquare: false,
                                  textColor: context.colors.wB,
                                  size: 25,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: SettingsPageView(),
                    ),
                  ],
                ),
              )
            : SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          UserAvatar(),
                          UserName(),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Chart(),
                    ),
                    Expanded(
                      flex: 2,
                      child: SettingsPageView(),
                    ),
                  ],
                ),
              ));
  }
}
