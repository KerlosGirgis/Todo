import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/view/widgets/avatar.dart';
import 'package:todo/provider/user_provider.dart';
import 'package:todo/view/widgets/edit_name_dialog.dart';
import 'package:todo/view/widgets/settings_button.dart';
import '../../services/icon_provider.dart';
import '../widgets/button.dart';
import '../widgets/indicator.dart';

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
    return Consumer<UserProvider>(
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
                    color: user.colorProvider.appTitle,
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
                      color: user.colorProvider.appTitle,
                    ))
              ],
            ),
            backgroundColor: user.colorProvider.pageBackground,
            body: MediaQuery.of(context).orientation == Orientation.portrait
                ? SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  backgroundImage: user.user.pic
                                              .substring(0, 1)
                                              .compareTo("0") ==
                                          0
                                      ? AssetImage(
                                          IconProvider.getAvatar(user.user.pic))
                                      : FileImage(File(user.user.pic)),
                                  radius: 100,
                                  backgroundColor: Colors.transparent,
                                ),
                                Positioned(
                                  bottom: 3,
                                  right: 15,
                                  child: IconButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: user.colorProvider
                                            .editPicButtonBackground,
                                      ),
                                      onPressed: () {
                                        showDialog(
                                            context: context,
                                            builder: (builder) {
                                              return AlertDialog(
                                                backgroundColor: user
                                                    .colorProvider
                                                    .addTaskAlertBackground,
                                                content: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        GestureDetector(
                                                          child: CircleAvatar(
                                                            backgroundImage:
                                                                AssetImage(IconProvider
                                                                    .getAvatar(
                                                                        "000")),
                                                            radius: 50,
                                                            backgroundColor:
                                                                Colors
                                                                    .transparent,
                                                          ),
                                                          onTap: () {
                                                            showDialog(
                                                                    context:
                                                                        context,
                                                                    builder:
                                                                        (builder) {
                                                                      return AlertDialog(
                                                                        backgroundColor: user
                                                                            .colorProvider
                                                                            .addTaskAlertBackground,
                                                                        scrollable:
                                                                            true,
                                                                        content:
                                                                            const Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Avatar(number: "000"),
                                                                                Padding(padding: EdgeInsets.only(right: 10)),
                                                                                Avatar(number: "001"),
                                                                              ],
                                                                            ),
                                                                            Padding(padding: EdgeInsets.only(bottom: 10)),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Avatar(number: "002"),
                                                                                Padding(padding: EdgeInsets.only(right: 10)),
                                                                                Avatar(number: "003"),
                                                                              ],
                                                                            ),
                                                                            Padding(padding: EdgeInsets.only(bottom: 10)),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Avatar(number: "004"),
                                                                                Padding(padding: EdgeInsets.only(right: 10)),
                                                                                Avatar(number: "005"),
                                                                              ],
                                                                            ),
                                                                            Padding(padding: EdgeInsets.only(bottom: 10)),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Avatar(number: "006"),
                                                                                Padding(padding: EdgeInsets.only(right: 10)),
                                                                                Avatar(number: "007"),
                                                                              ],
                                                                            ),
                                                                            Padding(padding: EdgeInsets.only(bottom: 10)),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Avatar(number: "008"),
                                                                                Padding(padding: EdgeInsets.only(right: 10)),
                                                                                Avatar(number: "009"),
                                                                              ],
                                                                            )
                                                                          ],
                                                                        ),
                                                                      );
                                                                    })
                                                                .then(
                                                                    (onValue) {
                                                              if (context
                                                                  .mounted) {
                                                                Navigator.pop(
                                                                    context);
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                    const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                right: 15)),
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        GestureDetector(
                                                          child:
                                                              const CircleAvatar(
                                                            backgroundImage:
                                                                AssetImage(
                                                                    "assets/person.png"),
                                                            radius: 50,
                                                          ),
                                                          onTap: () async {
                                                            user.pickAndSaveImage();
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                        ),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              );
                                            });
                                        //_pickAndSaveImage();
                                      },
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      )),
                                ),
                              ],
                            )
                          ],
                        ),
                        Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).size.height / 60)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onLongPress: () {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return const EditNameDialog();
                                    });
                              },
                              child: SizedBox(
                                width: MediaQuery.sizeOf(context).width / 1.1,
                                child: AutoSizeText(
                                  user.user.name,
                                  minFontSize: 30,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      overflow: TextOverflow.clip,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 40,
                                      color:
                                          user.colorProvider.profilePageName),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).size.height / 30)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: MediaQuery.sizeOf(context).width / 1.8,
                              height: MediaQuery.sizeOf(context).height / 4.5,
                              child: GestureDetector(
                                child: PieChart(
                                  user.user.unFinished == 0 &&
                                          user.user.finished == 0
                                      ? PieChartData(
                                          startDegreeOffset: 15,
                                          sectionsSpace: 0,
                                          centerSpaceRadius: 40,
                                          sections: [
                                            PieChartSectionData(
                                                color: Colors.grey,
                                                value: 1,
                                                title: " ",
                                                radius: 60,
                                                titleStyle: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                          ],
                                        )
                                      : PieChartData(
                                          startDegreeOffset: 15,
                                          sectionsSpace: 0,
                                          centerSpaceRadius: 40,
                                          sections: [
                                            PieChartSectionData(
                                                color: Colors.blue,
                                                value: user.user.finished
                                                    .toDouble(),
                                                title:
                                                    "${((user.user.finished / (user.user.finished + user.user.unFinished)) * 100).ceil()}%",
                                                radius: 60,
                                                titleStyle: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                            PieChartSectionData(
                                                color: Colors.grey,
                                                value: user.user.unFinished
                                                    .toDouble(),
                                                title:
                                                    "${((user.user.unFinished / (user.user.finished + user.user.unFinished)) * 100).floor()}%",
                                                radius: 50,
                                                titleStyle: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    overflow:
                                                        TextOverflow.ellipsis))
                                          ],
                                        ),
                                ),
                                onLongPress: () {
                                  showDialog(
                                      context: context,
                                      builder: (builder) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(25),
                                          ),
                                          backgroundColor: user.colorProvider
                                              .addTaskAlertBackground,
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: MediaQuery.sizeOf(context).width/1.1,
                                                  height: MediaQuery.sizeOf(context).height/10,
                                                  child: const AutoSizeText(
                                                "Are you sure you want to reset?",
                                                style:
                                                    TextStyle(fontSize: 26,fontWeight: FontWeight.w600),
                                                maxLines: 3,
                                                minFontSize: 16,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              )),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Button(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                    },
                                                    label: 'Cancel',
                                                    status: false,
                                                    fontSize: 22,
                                                    size: 1,
                                                  ),
                                                  const Spacer(
                                                    flex: 1,
                                                  ),
                                                  Button(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      user.resetPlot();
                                                    },
                                                    label: 'Reset',
                                                    status: true,
                                                    fontSize: 22,
                                                    size: 1,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      });
                                },
                              ),
                            ),
                            const Spacer(
                              flex: 2,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Indicator(
                                  color: Colors.blue,
                                  text: 'Finished',
                                  isSquare: true,
                                  textColor: user.colorProvider.appTitle,
                                ),
                                Indicator(
                                  color: Colors.grey,
                                  text: 'UnFinished',
                                  isSquare: true,
                                  textColor: user.colorProvider.appTitle,
                                ),
                              ],
                            ),
                            const Spacer(
                              flex: 1,
                            ),
                          ],
                        ),
                        Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).size.height / 20)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(
                              flex: 2,
                            ),
                            SettingsButton(
                                onPressed: () {
                                  Provider.of<UserProvider>(context,
                                          listen: false)
                                      .changeTheme();
                                },
                                label: "Dark Mode",
                                status: user.user.theme == 1 ? true : false,
                                fontSize: 22,
                                size: 1.5),
                            const Spacer(
                              flex: 1,
                            ),
                            SettingsButton(
                                onPressed: () {
                                  Provider.of<UserProvider>(context,
                                          listen: false)
                                      .changeCount();
                                },
                                label: "Word Count",
                                status: user.user.count == 1 ? true : false,
                                fontSize: 22,
                                size: 1.5),
                            const Spacer(
                              flex: 1,
                            ),
                            SettingsButton(
                                onPressed: () {
                                  Provider.of<UserProvider>(context,
                                          listen: false)
                                      .changeAutoSave();
                                },
                                label: "Auto Save",
                                status: user.user.autoSave == 1 ? true : false,
                                fontSize: 22,
                                size: 1.5),
                            const Spacer(
                              flex: 2,
                            ),
                          ],
                        ),
                        Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).size.height / 40)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(
                              flex: 2,
                            ),
                            SettingsButton(
                                onPressed: () {
                                  Provider.of<UserProvider>(context,
                                          listen: false)
                                      .changeFont();
                                },
                                label: "Casual Font",
                                status: user.user.casual == 1 ? true : false,
                                fontSize: 22,
                                size: 1.5),
                            const Spacer(
                              flex: 1,
                            ),
                            SettingsButton(
                                onPressed: () {
                                  Provider.of<UserProvider>(context,
                                          listen: false)
                                      .changeVerse();
                                },
                                label: "Enable V.O.T.D",
                                status: user.user.verse == 1 ? true : false,
                                fontSize: 22,
                                size: 1.5),
                            const Spacer(
                              flex: 1,
                            ),
                            SettingsButton(
                                onPressed: () {
                                  Provider.of<UserProvider>(context,
                                          listen: false)
                                      .changeLock();
                                },
                                label: "App Lock",
                                status: user.isEnabled ? true : false,
                                fontSize: 22,
                                size: 1.5),
                            const Spacer(
                              flex: 2,
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.sizeOf(context).height / 10)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(
                              flex: 1,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: user.user.pic
                                                  .substring(0, 1)
                                                  .compareTo("0") ==
                                              0
                                          ? AssetImage(IconProvider.getAvatar(
                                              user.user.pic))
                                          : FileImage(File(user.user.pic)),
                                      radius: 100,
                                      backgroundColor: Colors.transparent,
                                    ),
                                    Positioned(
                                      bottom: 3,
                                      right: 15,
                                      child: IconButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: user.colorProvider
                                                .editPicButtonBackground,
                                          ),
                                          onPressed: () {
                                            showDialog(
                                                context: context,
                                                builder: (builder) {
                                                  return AlertDialog(
                                                    backgroundColor: user
                                                        .colorProvider
                                                        .addTaskAlertBackground,
                                                    content: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            GestureDetector(
                                                              child:
                                                                  CircleAvatar(
                                                                backgroundImage:
                                                                    AssetImage(IconProvider
                                                                        .getAvatar(
                                                                            "000")),
                                                                radius: 50,
                                                                backgroundColor:
                                                                    Colors
                                                                        .transparent,
                                                              ),
                                                              onTap: () {
                                                                showDialog(
                                                                    context:
                                                                        context,
                                                                    builder:
                                                                        (builder) {
                                                                      return AlertDialog(
                                                                        backgroundColor: user
                                                                            .colorProvider
                                                                            .addTaskAlertBackground,
                                                                        scrollable:
                                                                            true,
                                                                        content:
                                                                            const Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Avatar(number: "000"),
                                                                                Padding(padding: EdgeInsets.only(right: 10)),
                                                                                Avatar(number: "001"),
                                                                              ],
                                                                            ),
                                                                            Padding(padding: EdgeInsets.only(bottom: 10)),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Avatar(number: "002"),
                                                                                Padding(padding: EdgeInsets.only(right: 10)),
                                                                                Avatar(number: "003"),
                                                                              ],
                                                                            ),
                                                                            Padding(padding: EdgeInsets.only(bottom: 10)),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Avatar(number: "004"),
                                                                                Padding(padding: EdgeInsets.only(right: 10)),
                                                                                Avatar(number: "005"),
                                                                              ],
                                                                            ),
                                                                            Padding(padding: EdgeInsets.only(bottom: 10)),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Avatar(number: "006"),
                                                                                Padding(padding: EdgeInsets.only(right: 10)),
                                                                                Avatar(number: "007"),
                                                                              ],
                                                                            ),
                                                                            Padding(padding: EdgeInsets.only(bottom: 10)),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Avatar(number: "008"),
                                                                                Padding(padding: EdgeInsets.only(right: 10)),
                                                                                Avatar(number: "009"),
                                                                              ],
                                                                            )
                                                                          ],
                                                                        ),
                                                                      );
                                                                    }).then((onValue) {
                                                                  if (context
                                                                      .mounted) {
                                                                    Navigator.pop(
                                                                        context);
                                                                  }
                                                                });
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                        const Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                                    right: 15)),
                                                        Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            GestureDetector(
                                                              child:
                                                                  const CircleAvatar(
                                                                backgroundImage:
                                                                    AssetImage(
                                                                        "assets/person.png"),
                                                                radius: 50,
                                                              ),
                                                              onTap: () async {
                                                                user.pickAndSaveImage();
                                                                Navigator.pop(
                                                                    context);
                                                              },
                                                            ),
                                                          ],
                                                        )
                                                      ],
                                                    ),
                                                  );
                                                });
                                            //_pickAndSaveImage();
                                          },
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                          )),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onLongPress: () {
                                        showDialog(
                                            context: context,
                                            builder: (context) {
                                              return const EditNameDialog();
                                            });
                                      },
                                      child: SizedBox(
                                        width:
                                            MediaQuery.sizeOf(context).width /
                                                4.4,
                                        child: AutoSizeText(
                                          user.user.name,
                                          minFontSize: 30,
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              overflow: TextOverflow.clip,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 40,
                                              color: user.colorProvider
                                                  .profilePageName),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(
                              flex: 1,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: MediaQuery.sizeOf(context).width / 4,
                                  height: MediaQuery.sizeOf(context).height / 2,
                                  child: GestureDetector(
                                    child: PieChart(
                                      user.user.unFinished == 0 &&
                                          user.user.finished == 0
                                          ? PieChartData(
                                        startDegreeOffset: 15,
                                        sectionsSpace: 0,
                                        centerSpaceRadius: 40,
                                        sections: [
                                          PieChartSectionData(
                                              color: Colors.grey,
                                              value: 1,
                                              title: " ",
                                              radius: 60,
                                              titleStyle: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  overflow:
                                                  TextOverflow.ellipsis)),
                                        ],
                                      )
                                          : PieChartData(
                                        startDegreeOffset: 15,
                                        sectionsSpace: 0,
                                        centerSpaceRadius: 40,
                                        sections: [
                                          PieChartSectionData(
                                              color: Colors.blue,
                                              value: user.user.finished
                                                  .toDouble(),
                                              title:
                                              "${((user.user.finished / (user.user.finished + user.user.unFinished)) * 100).ceil()}%",
                                              radius: 60,
                                              titleStyle: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  overflow:
                                                  TextOverflow.ellipsis)),
                                          PieChartSectionData(
                                              color: Colors.grey,
                                              value: user.user.unFinished
                                                  .toDouble(),
                                              title:
                                              "${((user.user.unFinished / (user.user.finished + user.user.unFinished)) * 100).floor()}%",
                                              radius: 50,
                                              titleStyle: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  overflow:
                                                  TextOverflow.ellipsis))
                                        ],
                                      ),
                                    ),
                                    onLongPress: () {
                                      showDialog(
                                          context: context,
                                          builder: (builder) {
                                            return AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(25),
                                              ),
                                              backgroundColor: user.colorProvider
                                                  .addTaskAlertBackground,
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                      width: MediaQuery.sizeOf(context).width/3,
                                                      height: MediaQuery.sizeOf(context).height/5,
                                                      child: const AutoSizeText(
                                                        "Are you sure you want to reset?",
                                                        style:
                                                        TextStyle(fontSize: 26,fontWeight: FontWeight.w600),
                                                        maxLines: 3,
                                                        minFontSize: 16,
                                                        overflow:
                                                        TextOverflow.ellipsis,
                                                      )),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Button(
                                                        onPressed: () {
                                                          Navigator.pop(context);
                                                        },
                                                        label: 'Cancel',
                                                        status: false,
                                                        fontSize: 22,
                                                        size: 1,
                                                      ),
                                                      const Spacer(
                                                        flex: 1,
                                                      ),
                                                      Button(
                                                        onPressed: () {
                                                          Navigator.pop(context);
                                                          user.resetPlot();
                                                        },
                                                        label: 'Reset',
                                                        status: true,
                                                        fontSize: 22,
                                                        size: 1,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(
                              flex: 1,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                    padding: EdgeInsets.only(
                                        bottom:
                                            MediaQuery.of(context).size.height /
                                                40)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SettingsButton(
                                        onPressed: () {
                                          Provider.of<UserProvider>(context,
                                                  listen: false)
                                              .changeTheme();
                                        },
                                        label: "Dark Mode",
                                        status:
                                            user.user.theme == 1 ? true : false,
                                        fontSize: 22,
                                        size: 1.5),
                                    Padding(
                                        padding: EdgeInsets.only(
                                            right: MediaQuery.of(context)
                                                    .size
                                                    .width /
                                                60)),
                                    SettingsButton(
                                        onPressed: () {
                                          Provider.of<UserProvider>(context,
                                                  listen: false)
                                              .changeCount();
                                        },
                                        label: "Word Count",
                                        status:
                                            user.user.count == 1 ? true : false,
                                        fontSize: 22,
                                        size: 1.5),
                                    Padding(
                                        padding: EdgeInsets.only(
                                            right: MediaQuery.of(context)
                                                    .size
                                                    .width /
                                                60)),
                                    SettingsButton(
                                        onPressed: () {
                                          Provider.of<UserProvider>(context,
                                                  listen: false)
                                              .changeAutoSave();
                                        },
                                        label: "Auto Save",
                                        status: user.user.autoSave == 1
                                            ? true
                                            : false,
                                        fontSize: 22,
                                        size: 1.5),
                                  ],
                                ),
                                Padding(
                                    padding: EdgeInsets.only(
                                        bottom:
                                            MediaQuery.of(context).size.height /
                                                40)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SettingsButton(
                                        onPressed: () {
                                          Provider.of<UserProvider>(context,
                                                  listen: false)
                                              .changeFont();
                                        },
                                        label: "Casual Font",
                                        status: user.user.casual == 1
                                            ? true
                                            : false,
                                        fontSize: 22,
                                        size: 1.5),
                                    Padding(
                                        padding: EdgeInsets.only(
                                            right: MediaQuery.of(context)
                                                    .size
                                                    .width /
                                                60)),
                                    SettingsButton(
                                        onPressed: () {
                                          Provider.of<UserProvider>(context,
                                                  listen: false)
                                              .changeVerse();
                                        },
                                        label: "Enable V.O.T.D",
                                        status:
                                            user.user.verse == 1 ? true : false,
                                        fontSize: 22,
                                        size: 1.5),
                                    Padding(
                                        padding: EdgeInsets.only(
                                            right: MediaQuery.of(context)
                                                    .size
                                                    .width /
                                                60)),
                                    SettingsButton(
                                        onPressed: () {
                                          Provider.of<UserProvider>(context,
                                                  listen: false)
                                              .changeLock();
                                        },
                                        label: "App Lock",
                                        status: user.isEnabled ? true : false,
                                        fontSize: 22,
                                        size: 1.5),
                                  ],
                                )
                              ],
                            ),
                            const Spacer(
                              flex: 1,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ));
      },
    );
  }
}
