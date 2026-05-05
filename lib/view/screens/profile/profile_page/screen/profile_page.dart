import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:todo/view_model/user_view_model.dart';
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
    return Consumer<UserViewModel>(
      builder: (context, user, child) {
        return Scaffold(
            appBar: AppBar(
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 40,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.arrow_back,
                    color: user.colorManager.wB,
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
                        style: ToastificationStyle.flat
                      );
                    },
                    icon: Icon(
                      Icons.info_outline_rounded,
                      color: user.colorManager.wB,
                    ))
              ],
            ),
            backgroundColor: user.colorManager.pageBackground,
            body: MediaQuery.of(context).orientation == Orientation.portrait ||
                    MediaQuery.sizeOf(context).aspectRatio < 1.5
                ? SafeArea(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: [
                          AspectRatio(
                            aspectRatio: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                UserAvatar(),
                              ],
                            ),
                          ),
                          Padding(
                              padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.sizeOf(context).height / 90)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              UserName(),
                            ],
                          ),
                          Padding(
                              padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.sizeOf(context).height / 33)),
                          AspectRatio(
                            aspectRatio: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Flexible(
                                  child: Chart(),
                                ),
                                Flexible(
                                  child: SizedBox(
                                    width: MediaQuery.sizeOf(context).width / 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Indicator(
                                          color: Color(0xff3D5AFE),
                                          text: 'Finished',
                                          isSquare: false,
                                          textColor: user.colorManager.wB,
                                          size: 25,
                                        ),
                                        Padding(
                                            padding: EdgeInsets.only(
                                                bottom:
                                                    MediaQuery.sizeOf(context)
                                                            .height /
                                                        90)),
                                        Indicator(
                                          color: user.colorManager.wB!
                                              .withValues(alpha: 0.4),
                                          text: 'UnFinished',
                                          isSquare: false,
                                          textColor: user.colorManager.wB,
                                          size: 25,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                              padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.sizeOf(context).height / 33)),
                          AspectRatio(
                            aspectRatio: 1.6,
                            child: SettingsPageView(),
                          ),
                        ],
                      ),
                    ),
                  )
                : SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
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
                          child: Chart(),
                        ),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width / 2,
                            height: MediaQuery.sizeOf(context).height / 1.50,
                            child: SettingsPageView(),
                          ),
                        ),
                      ],
                    ),
                  ));
      },
    );
  }
}
