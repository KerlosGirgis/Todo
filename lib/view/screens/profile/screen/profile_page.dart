import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
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
              surfaceTintColor: user.colorManager.pageBackground,
              toolbarHeight: 40,
              backgroundColor: user.colorManager.pageBackground,
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
                    onPressed: () async {
                      Fluttertoast.showToast(
                          msg: "Developed with ❤️ by Kerlos Girgis",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.blue,
                          textColor: Colors.white,
                          fontSize: 18.0);
                    },
                    icon: Icon(
                      Icons.question_mark,
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
                          Padding(padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height / 90)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              UserName(),
                            ],
                          ),
                          Padding(padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height / 33)),
                          AspectRatio(
                            aspectRatio: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Indicator(
                                          color: Colors.blue,
                                          text: 'Finished',
                                          isSquare: true,
                                          textColor: user.colorManager.wB,
                                        ),
                                        Indicator(
                                          color: Colors.grey,
                                          text: 'UnFinished',
                                          isSquare: true,
                                          textColor: user.colorManager.wB,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height / 33)),
                          AspectRatio(
                            aspectRatio: 1.7,
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
                          height:
                              MediaQuery.sizeOf(context).height / 1.50,
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



