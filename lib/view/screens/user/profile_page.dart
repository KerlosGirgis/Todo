import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/view_model/user_view_model.dart';
import 'package:todo/view/screens/user/edit_name_dialog.dart';
import 'package:todo/view/widgets/settings_button.dart';
import '../../../services/avatar_manager.dart';
import 'avatars_list_dialog.dart';
import '../../widgets/button.dart';
import '../../widgets/indicator.dart';
import 'reset_plot_dialog.dart';

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
                    color: user.colorManager.appTitle,
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
                      color: user.colorManager.appTitle,
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
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: user.user.pic
                                              .startsWith("0")
                                          ? AssetImage(AvatarManager.getAvatar(
                                              user.user.pic))
                                          : FileImage(File(user.user.pic))
                                              as ImageProvider,
                                      radius:
                                          MediaQuery.sizeOf(context).width / 4,
                                      backgroundColor: Colors.transparent,
                                    ),
                                    Positioned(
                                      right:
                                          MediaQuery.sizeOf(context).width / 30,
                                      bottom:
                                          MediaQuery.sizeOf(context).width / 30,
                                      child: SizedBox(
                                        width:
                                            MediaQuery.sizeOf(context).width /
                                                10,
                                        height:
                                            MediaQuery.sizeOf(context).width /
                                                10,
                                        child: FloatingActionButton(
                                          backgroundColor: user.colorManager
                                              .editPicButtonBackground,
                                          elevation: 3,
                                          shape: const CircleBorder(),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                elevation: 2,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          25),
                                                ),
                                                backgroundColor: user
                                                    .colorManager
                                                    .pageBackground,
                                                content: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: GestureDetector(
                                                        child: CircleAvatar(
                                                          backgroundImage:
                                                              AssetImage(
                                                                  AvatarManager
                                                                      .getAvatar(
                                                                          "000")),
                                                          radius:
                                                              MediaQuery.sizeOf(
                                                                          context)
                                                                      .width /
                                                                  7,
                                                          backgroundColor:
                                                              Colors
                                                                  .transparent,
                                                        ),
                                                        onTap: () {
                                                          showDialog(
                                                            context: context,
                                                            builder: (context) =>
                                                                AvatarsListDialog(),
                                                          ).then((_) {
                                                            if (context
                                                                .mounted) {
                                                              Navigator.pop(
                                                                  context);
                                                            }
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: GestureDetector(
                                                        child: CircleAvatar(
                                                          backgroundImage:
                                                              AssetImage(
                                                                  "assets/person.png"),
                                                          radius:
                                                              MediaQuery.sizeOf(
                                                                          context)
                                                                      .width /
                                                                  7,
                                                        ),
                                                        onTap: () async {
                                                          user.pickAndSaveImage();
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          child: Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                            size: MediaQuery.sizeOf(context)
                                                    .width /
                                                15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height / 90)),
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
                                            user.colorManager.profilePageName),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height / 33)),
                          AspectRatio(
                            aspectRatio: 2,
                            child: Row(
                              spacing: MediaQuery.sizeOf(context).width / 10,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: MediaQuery.sizeOf(context).width / 1.8,
                                  height:
                                      MediaQuery.sizeOf(context).height / 4.5,
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        overflow: TextOverflow
                                                            .ellipsis)),
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        overflow: TextOverflow
                                                            .ellipsis)),
                                                PieChartSectionData(
                                                    color: Colors.grey,
                                                    value: user.user.unFinished
                                                        .toDouble(),
                                                    title:
                                                        "${((user.user.unFinished / (user.user.finished + user.user.unFinished)) * 100).floor()}%",
                                                    radius: 50,
                                                    titleStyle: const TextStyle(
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        overflow: TextOverflow
                                                            .ellipsis))
                                              ],
                                            ),
                                    ),
                                    onLongPress: () {
                                      showDialog(
                                          context: context,
                                          builder: (builder) {
                                            return ResetPlotDialog();
                                          });
                                    },
                                  ),
                                ),
                                SizedBox(
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
                                        textColor: user.colorManager.appTitle,
                                      ),
                                      Indicator(
                                        color: Colors.grey,
                                        text: 'UnFinished',
                                        isSquare: true,
                                        textColor: user.colorManager.appTitle,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height / 33)),
                          AspectRatio(
                            aspectRatio: 1.7,
                            child: SizedBox(
                              height: MediaQuery.sizeOf(context).height / 3.4,
                              width: MediaQuery.sizeOf(context).width,
                              child: PageView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  Padding(
                                    padding:EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height*.001),
                                    child: Column(
                                      spacing:
                                          MediaQuery.sizeOf(context).height / 50,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                                right: MediaQuery.sizeOf(context)
                                                        .width /
                                                    30,
                                                left: MediaQuery.sizeOf(context)
                                                        .width /
                                                    30),
                                            child: Row(
                                              spacing: MediaQuery.sizeOf(context)
                                                      .width /
                                                  50,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeTheme();
                                                      },
                                                      label: "Dark\nMode",
                                                      status: user.user.theme == 1
                                                          ? true
                                                          : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeCount();
                                                      },
                                                      label: "Word\nCount",
                                                      status: user.user.count == 1
                                                          ? true
                                                          : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeAutoSave();
                                                      },
                                                      label: "Auto\nSave",
                                                      status:
                                                          user.user.autoSave == 1
                                                              ? true
                                                              : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                                right: MediaQuery.sizeOf(context)
                                                        .width /
                                                    30,
                                                left: MediaQuery.sizeOf(context)
                                                        .width /
                                                    30),
                                            child: Row(
                                              spacing: MediaQuery.sizeOf(context)
                                                      .width /
                                                  50,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeFont();
                                                      },
                                                      label: "Casual\nFont",
                                                      status:
                                                          user.user.casual == 1
                                                              ? true
                                                              : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeVerse();
                                                      },
                                                      label: "Daily\nVerse",
                                                      status: user.user.verse == 1
                                                          ? true
                                                          : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeLock();
                                                      },
                                                      label: "App\nLock",
                                                      status: user.isEnabled
                                                          ? true
                                                          : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          "Start Page",
                                          style: TextStyle(
                                            fontSize: 26,
                                            color: user.colorManager.appTitle,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: SegmentedButton<int>(
                                          segments: const [
                                            ButtonSegment(
                                              value: 0,
                                              label: Text("Todo"),
                                              icon: Icon(Icons.checklist_sharp),
                                            ),
                                            ButtonSegment(
                                              value: 1,
                                              label: Text("Notes"),
                                              icon: Icon(Icons.edit_note_sharp),
                                            )
                                          ],
                                          selected: {user.user.startPage},
                                          emptySelectionAllowed: false,
                                          onSelectionChanged: (v) => user.changeStartPage(v.first),

                                          style: ButtonStyle(
                                            shape: WidgetStateProperty.all(
                                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),

                                            padding: WidgetStateProperty.all(
                                              EdgeInsets.symmetric(horizontal: MediaQuery.widthOf(context)/7, vertical: 15),
                                            ),

                                            side: WidgetStateProperty.resolveWith((states) {
                                              return BorderSide(
                                                color: user.colorManager.homePageText!.withValues(alpha: 0.35),
                                              );
                                            }),

                                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                                              return states.contains(WidgetState.selected)
                                                  ? user.colorManager.homePageText!.withValues(alpha: 0.18)
                                                  : Colors.transparent;
                                            }),

                                            foregroundColor: WidgetStateProperty.resolveWith((states) {
                                              return states.contains(WidgetState.selected)
                                                  ? user.colorManager.homePageText
                                                  : user.colorManager.homePageText!.withValues(alpha: 0.6);
                                            }),
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          "Task description lines",
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 26,
                                            color: user.colorManager.appTitle,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: SegmentedButton<int>(
                                          segments: const [
                                            ButtonSegment(
                                              value: 0,
                                              label: Text("off"),
                                            ),
                                            ButtonSegment(
                                              value: 1,
                                              label: Text("1"),
                                            ),
                                            ButtonSegment(
                                              value: 2,
                                              label: Text("2"),
                                            ),
                                            ButtonSegment(
                                              value: 3,
                                              label: Text("3"),
                                            ),
                                            ButtonSegment(
                                              value: 4,
                                              label: Text("4"),
                                            ),
                                            ButtonSegment(
                                              value: 5,
                                              label: Text("5"),
                                            ),
                                          ],
                                          selected: {user.user.descLines},
                                          emptySelectionAllowed: false,
                                          onSelectionChanged: (v) => user.setDescLines(v.first),

                                          style: ButtonStyle(
                                            shape: WidgetStateProperty.all(
                                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),

                                            padding: WidgetStateProperty.all(
                                              EdgeInsets.symmetric(vertical: 15),
                                            ),

                                            side: WidgetStateProperty.resolveWith((states) {
                                              return BorderSide(
                                                color: user.colorManager.homePageText!.withValues(alpha: 0.35),
                                              );
                                            }),

                                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                                              return states.contains(WidgetState.selected)
                                                  ? user.colorManager.homePageText!.withValues(alpha: 0.18)
                                                  : Colors.transparent;
                                            }),

                                            foregroundColor: WidgetStateProperty.resolveWith((states) {
                                              return states.contains(WidgetState.selected)
                                                  ? user.colorManager.homePageText
                                                  : user.colorManager.homePageText!.withValues(alpha: 0.6);
                                            }),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      AutoSizeText(
                                        "Notes Font Size",
                                        minFontSize: 10,
                                        style: TextStyle(
                                            overflow: TextOverflow.ellipsis,
                                            fontSize: 28,
                                            color: user
                                                .colorManager.homePageText),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            flex: 10,
                                            child: Slider(
                                                activeColor:
                                                    const Color(0xff3D5AFE),
                                                value: user.tempNotesTextSize,
                                                min: .25,
                                                max: 2,
                                                onChanged: (v) {
                                                  user.setTempNotesSize(v);
                                                }),
                                          ),
                                          Expanded(
                                              flex: 1,
                                              child: Text(
                                                maxLines: 1,
                                                user.tempNotesTextSize
                                                    .toStringAsPrecision(2),
                                                style: TextStyle(
                                                    fontSize: 22,
                                                    color: user.colorManager
                                                        .homePageText),
                                              ))
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Button(
                                              onPressed: () {
                                                user.setNotesTextSize();
                                              },
                                              label: "Apply",
                                              status: double.parse(user
                                                      .tempNotesTextSize
                                                      .toStringAsPrecision(
                                                          2)) !=
                                                  user.user.notesTextSize,
                                              fontSize: 24,
                                              size: 1)
                                        ],
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SafeArea(
                  child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: [
                          Padding(
                              padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.sizeOf(context).height / 15)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          backgroundImage: user.user.pic
                                                  .startsWith("0")
                                              ? AssetImage(AvatarManager.getAvatar(
                                                  user.user.pic))
                                              : FileImage(File(user.user.pic))
                                                  as ImageProvider,
                                          radius:
                                              MediaQuery.sizeOf(context).height /
                                                  4,
                                          backgroundColor: Colors.transparent,
                                        ),
                                        Positioned(
                                          right:
                                              MediaQuery.sizeOf(context).width /
                                                  50, // Adjust dynamically
                                          bottom:
                                              MediaQuery.sizeOf(context).height /
                                                  50,
                                          child: SizedBox(
                                            width: MediaQuery.sizeOf(context)
                                                    .height /
                                                10, // Proportional size
                                            height: MediaQuery.sizeOf(context)
                                                    .height /
                                                10,
                                            child: FloatingActionButton(
                                              shape:
                                                  const CircleBorder(), // Ensures circular shape
                                              backgroundColor: user.colorManager
                                                  .editPicButtonBackground,
                                              elevation: 3,
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                        elevation: 2,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              25),
                                                    ),
                                                    backgroundColor: user
                                                        .colorManager
                                                        .pageBackground,
                                                    content: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceEvenly,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Expanded(
                                                          child: GestureDetector(
                                                            child: CircleAvatar(
                                                              backgroundImage:
                                                                  AssetImage(AvatarManager
                                                                      .getAvatar(
                                                                          "000")),
                                                              radius: MediaQuery
                                                                          .sizeOf(
                                                                              context)
                                                                      .height /
                                                                  7,
                                                              backgroundColor:
                                                                  Colors
                                                                      .transparent,
                                                            ),
                                                            onTap: () {
                                                              showDialog(
                                                                context: context,
                                                                builder: (context) =>
                                                                    AvatarsListDialog(),
                                                              ).then((_) {
                                                                if (context
                                                                    .mounted) {
                                                                  Navigator.pop(
                                                                      context);
                                                                }
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: GestureDetector(
                                                            child: CircleAvatar(
                                                              backgroundImage:
                                                                  AssetImage(
                                                                      "assets/person.png"),
                                                              radius: MediaQuery
                                                                          .sizeOf(
                                                                              context)
                                                                      .height /
                                                                  7,
                                                            ),
                                                            onTap: () async {
                                                              user.pickAndSaveImage();
                                                              Navigator.pop(
                                                                  context);
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                                size: MediaQuery.sizeOf(context)
                                                        .height /
                                                    20, // Dynamic icon size
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onLongPress: () {
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return const EditNameDialog();
                                                  });
                                            },
                                            child: SizedBox(
                                              width: MediaQuery.sizeOf(context)
                                                      .width /
                                                  4, // Slightly larger in landscape
                                              child: AutoSizeText(
                                                user.user.name,
                                                minFontSize:
                                                    25, // Reduced slightly for landscape
                                                maxLines: 1,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  overflow: TextOverflow.ellipsis,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize:
                                                      35, // Adjusted for landscape
                                                  color: user.colorManager
                                                      .profilePageName,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: MediaQuery.sizeOf(context).width / 4,
                                      height:
                                          MediaQuery.sizeOf(context).height / 2,
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
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.white,
                                                            overflow: TextOverflow
                                                                .ellipsis)),
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
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.white,
                                                            overflow: TextOverflow
                                                                .ellipsis)),
                                                    PieChartSectionData(
                                                        color: Colors.grey,
                                                        value: user
                                                            .user.unFinished
                                                            .toDouble(),
                                                        title:
                                                            "${((user.user.unFinished / (user.user.finished + user.user.unFinished)) * 100).floor()}%",
                                                        radius: 50,
                                                        titleStyle:
                                                            const TextStyle(
                                                                fontSize: 22,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    Colors.white,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis))
                                                  ],
                                                ),
                                        ),
                                        onLongPress: () {
                                          showDialog(
                                              context: context,
                                              builder: (builder) {
                                                return ResetPlotDialog();
                                              });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  width: MediaQuery.sizeOf(context).width / 2,
                                  height:
                                      MediaQuery.sizeOf(context).height / 1.50,
                                  child: PageView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        spacing:
                                            MediaQuery.sizeOf(context).height /
                                                30,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              spacing: MediaQuery.sizeOf(context)
                                                      .width /
                                                  80,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeTheme();
                                                      },
                                                      label: "Dark\nMode",
                                                      status: user.user.theme == 1
                                                          ? true
                                                          : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeCount();
                                                      },
                                                      label: "Word\nCount",
                                                      status: user.user.count == 1
                                                          ? true
                                                          : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeAutoSave();
                                                      },
                                                      label: "Auto\nSave",
                                                      status:
                                                          user.user.autoSave == 1
                                                              ? true
                                                              : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Row(
                                              spacing: MediaQuery.sizeOf(context)
                                                      .width /
                                                  80,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeFont();
                                                      },
                                                      label: "Casual\nFont",
                                                      status:
                                                          user.user.casual == 1
                                                              ? true
                                                              : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeVerse();
                                                      },
                                                      label: "Daily\nVerse",
                                                      status: user.user.verse == 1
                                                          ? true
                                                          : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                                Expanded(
                                                  child: SettingsButton(
                                                      onPressed: () {
                                                        Provider.of<UserViewModel>(
                                                                context,
                                                                listen: false)
                                                            .changeLock();
                                                      },
                                                      label: "App\nLock",
                                                      status: user.isEnabled
                                                          ? true
                                                          : false,
                                                      fontSize: 22,
                                                      size: 1.5),
                                                ),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              "Start Page",
                                              style: TextStyle(
                                                fontSize: 26,
                                                color: user.colorManager.appTitle,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Padding(padding: EdgeInsets.only(bottom: 10)),
                                          Flexible(
                                            child: SegmentedButton<int>(
                                              segments: const [
                                                ButtonSegment(
                                                  value: 0,
                                                  label: Text("Todo"),
                                                  icon: Icon(Icons.checklist_sharp),
                                                ),
                                                ButtonSegment(
                                                  value: 1,
                                                  label: Text("Notes"),
                                                  icon: Icon(Icons.edit_note_sharp),
                                                )
                                              ],
                                              selected: {user.user.startPage},
                                              emptySelectionAllowed: false,
                                              onSelectionChanged: (v) => user.changeStartPage(v.first),

                                              style: ButtonStyle(
                                                shape: WidgetStateProperty.all(
                                                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),

                                                padding: WidgetStateProperty.all(
                                                  EdgeInsets.symmetric(horizontal: MediaQuery.widthOf(context)/15, vertical: 10),
                                                ),

                                                side: WidgetStateProperty.resolveWith((states) {
                                                  return BorderSide(
                                                    color: user.colorManager.homePageText!.withValues(alpha: 0.35),
                                                  );
                                                }),

                                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                                  return states.contains(WidgetState.selected)
                                                      ? user.colorManager.homePageText!.withValues(alpha: 0.18)
                                                      : Colors.transparent;
                                                }),

                                                foregroundColor: WidgetStateProperty.resolveWith((states) {
                                                  return states.contains(WidgetState.selected)
                                                      ? user.colorManager.homePageText
                                                      : user.colorManager.homePageText!.withValues(alpha: 0.6);
                                                }),
                                              ),
                                            ),
                                          ),
                                          Padding(padding: EdgeInsets.only(bottom: 10)),
                                          Flexible(
                                            child: Text(
                                              "Task description lines",
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 26,
                                                color: user.colorManager.appTitle,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Padding(padding: EdgeInsets.only(bottom: 10)),
                                          Flexible(
                                            child: SegmentedButton<int>(
                                              segments: const [
                                                ButtonSegment(
                                                  value: 0,
                                                  label: Text("off"),
                                                ),
                                                ButtonSegment(
                                                  value: 1,
                                                  label: Text("1"),
                                                ),
                                                ButtonSegment(
                                                  value: 2,
                                                  label: Text("2"),
                                                ),
                                                ButtonSegment(
                                                  value: 3,
                                                  label: Text("3"),
                                                ),
                                                ButtonSegment(
                                                  value: 4,
                                                  label: Text("4"),
                                                ),
                                                ButtonSegment(
                                                  value: 5,
                                                  label: Text("5"),
                                                ),
                                              ],
                                              selected: {user.user.descLines},
                                              emptySelectionAllowed: false,
                                              onSelectionChanged: (v) => user.setDescLines(v.first),

                                              style: ButtonStyle(
                                                shape: WidgetStateProperty.all(
                                                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),

                                                padding: WidgetStateProperty.all(
                                                  EdgeInsets.symmetric(vertical: 15),
                                                ),

                                                side: WidgetStateProperty.resolveWith((states) {
                                                  return BorderSide(
                                                    color: user.colorManager.homePageText!.withValues(alpha: 0.35),
                                                  );
                                                }),

                                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                                  return states.contains(WidgetState.selected)
                                                      ? user.colorManager.homePageText!.withValues(alpha: 0.18)
                                                      : Colors.transparent;
                                                }),

                                                foregroundColor: WidgetStateProperty.resolveWith((states) {
                                                  return states.contains(WidgetState.selected)
                                                      ? user.colorManager.homePageText
                                                      : user.colorManager.homePageText!.withValues(alpha: 0.6);
                                                }),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          AutoSizeText(
                                            "Notes Font Size",
                                            minFontSize: 10,
                                            style: TextStyle(
                                                overflow: TextOverflow.ellipsis,
                                                fontSize: 28,
                                                color: user
                                                    .colorManager.homePageText),
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                flex: 10,
                                                child: Slider(
                                                    activeColor:
                                                        const Color(0xff3D5AFE),
                                                    value: user.tempNotesTextSize,
                                                    min: .25,
                                                    max: 2,
                                                    onChanged: (v) {
                                                      user.setTempNotesSize(v);
                                                    }),
                                              ),
                                              Expanded(
                                                  flex: 1,
                                                  child: Text(
                                                    maxLines: 1,
                                                    user.tempNotesTextSize
                                                        .toStringAsPrecision(2),
                                                    style: TextStyle(
                                                        fontSize: 22,
                                                        color: user.colorManager
                                                            .homePageText),
                                                  ))
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Button(
                                                  onPressed: () {
                                                    user.setNotesTextSize();
                                                  },
                                                  label: "Apply",
                                                  status: double.parse(user
                                                          .tempNotesTextSize
                                                          .toStringAsPrecision(
                                                              2)) !=
                                                      user.user.notesTextSize,
                                                  fontSize: 24,
                                                  size: 1)
                                            ],
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ));
      },
    );
  }
}
