import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/view/widgets/avatar.dart';
import 'package:todo/provider/user_provider.dart';
import 'package:todo/view/widgets/edit_name_dialog.dart';
import 'package:todo/view/widgets/settings_button.dart';
import '../../services/icon_provider.dart';
import '../../services/verse_manager.dart';

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
                    onPressed: () {
                      Fluttertoast.showToast(
                          msg: "Developed with ❤️ by Kerlos Girgis",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.blue,
                          textColor: user.colorProvider.appTitle,
                          fontSize: 18.0);
                    },
                    icon: Icon(
                      Icons.question_mark,
                      color: user.colorProvider.appTitle,
                    ))
              ],
            ),
            backgroundColor: user.colorProvider.pageBackground,
            body: MediaQuery.of(context).orientation==Orientation.portrait?SingleChildScrollView(
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
                                  backgroundColor: user
                                      .colorProvider.editPicButtonBackground,
                                ),
                                onPressed: () {
                                  showDialog(
                                      context: context,
                                      builder: (builder) {
                                        return AlertDialog(
                                          backgroundColor: user.colorProvider
                                              .addTaskAlertBackground,
                                          content: Row(
                                            mainAxisSize: MainAxisSize.min,
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
                                                      AssetImage(
                                                          IconProvider
                                                              .getAvatar(
                                                              "000")),
                                                      radius: 50,
                                                      backgroundColor:
                                                      Colors.transparent,
                                                    ),
                                                    onTap: () {
                                                      showDialog(
                                                          context: context,
                                                          builder: (builder) {
                                                            return AlertDialog(
                                                              backgroundColor: user
                                                                  .colorProvider
                                                                  .addTaskAlertBackground,
                                                              scrollable:
                                                              true,
                                                              content:
                                                              const Column(
                                                                mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                                children: [
                                                                  Row(
                                                                    mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                    children: [
                                                                      Avatar(
                                                                          number:
                                                                          "000"),
                                                                      Padding(
                                                                          padding:
                                                                          EdgeInsets.only(right: 10)),
                                                                      Avatar(
                                                                          number:
                                                                          "001"),
                                                                    ],
                                                                  ),
                                                                  Padding(
                                                                      padding:
                                                                      EdgeInsets.only(bottom: 10)),
                                                                  Row(
                                                                    mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                    children: [
                                                                      Avatar(
                                                                          number:
                                                                          "002"),
                                                                      Padding(
                                                                          padding:
                                                                          EdgeInsets.only(right: 10)),
                                                                      Avatar(
                                                                          number:
                                                                          "003"),
                                                                    ],
                                                                  ),
                                                                  Padding(
                                                                      padding:
                                                                      EdgeInsets.only(bottom: 10)),
                                                                  Row(
                                                                    mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                    children: [
                                                                      Avatar(
                                                                          number:
                                                                          "004"),
                                                                      Padding(
                                                                          padding:
                                                                          EdgeInsets.only(right: 10)),
                                                                      Avatar(
                                                                          number:
                                                                          "005"),
                                                                    ],
                                                                  ),
                                                                  Padding(
                                                                      padding:
                                                                      EdgeInsets.only(bottom: 10)),
                                                                  Row(
                                                                    mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                    children: [
                                                                      Avatar(
                                                                          number:
                                                                          "006"),
                                                                      Padding(
                                                                          padding:
                                                                          EdgeInsets.only(right: 10)),
                                                                      Avatar(
                                                                          number:
                                                                          "007"),
                                                                    ],
                                                                  ),
                                                                  Padding(
                                                                      padding:
                                                                      EdgeInsets.only(bottom: 10)),
                                                                  Row(
                                                                    mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                    children: [
                                                                      Avatar(
                                                                          number:
                                                                          "008"),
                                                                      Padding(
                                                                          padding:
                                                                          EdgeInsets.only(right: 10)),
                                                                      Avatar(
                                                                          number:
                                                                          "009"),
                                                                    ],
                                                                  )
                                                                ],
                                                              ),
                                                            );
                                                          }).then((onValue) {
                                                        if (context.mounted) {
                                                          Navigator.pop(
                                                              context);
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const Padding(
                                                  padding: EdgeInsets.only(
                                                      right: 15)),
                                              Column(
                                                mainAxisSize:
                                                MainAxisSize.min,
                                                children: [
                                                  GestureDetector(
                                                    child: const CircleAvatar(
                                                      backgroundImage: AssetImage(
                                                          "assets/person.png"),
                                                      radius: 50,
                                                    ),
                                                    onTap: () async {
                                                      user.pickAndSaveImage();
                                                      Navigator.pop(context);
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
                          bottom: MediaQuery.of(context).size.height / 60)),
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
                        child: Text(
                          user.user.name,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 40,
                              color: user.colorProvider.profilePageName),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).size.height / 50)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: MediaQuery.sizeOf(context).width/1.1,
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
                                children: [
                                  const Text(
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
                      ),
                    ],
                  ),
                  Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).size.height / 40)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2,),
                      SettingsButton(onPressed: (){
                        Provider.of<UserProvider>(context,
                            listen: false)
                            .changeTheme();
                      }, label: "Dark Mode", status: user.user.theme == 1 ? true : false, fontSize: 22, size: 1.5),
                      const Spacer(flex: 1,),
                      SettingsButton(onPressed: (){
                        Provider.of<UserProvider>(context,
                            listen: false)
                            .changeAutoSave();
                      }, label: "Auto Save", status: user.user.autoSave == 1 ? true : false, fontSize: 22, size: 1.5),
                      const Spacer(flex: 2,),
                    ],
                  ),
                  Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).size.height / 40)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2,),
                      SettingsButton(onPressed: (){
                        Provider.of<UserProvider>(context,
                            listen: false)
                            .changeFont();
                      }, label: "Casual Font", status: user.user.casual == 1 ? true : false, fontSize: 22, size: 1.5),
                      const Spacer(flex: 1,),
                      SettingsButton(onPressed: (){
                        Provider.of<UserProvider>(context,
                            listen: false)
                            .changeLock();
                      }, label: "App Lock", status: user.isEnabled ? true : false, fontSize: 22, size: 1.5),
                      const Spacer(flex: 2,),
                    ],
                  )
                ],
              ),
            ):
            SingleChildScrollView(
              child: Column(
                children: [
                  Padding(padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height/10)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 1,),
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
                                      backgroundColor: user
                                          .colorProvider.editPicButtonBackground,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                          context: context,
                                          builder: (builder) {
                                            return AlertDialog(
                                              backgroundColor: user.colorProvider
                                                  .addTaskAlertBackground,
                                              content: Row(
                                                mainAxisSize: MainAxisSize.min,
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
                                                          AssetImage(
                                                              IconProvider
                                                                  .getAvatar(
                                                                  "000")),
                                                          radius: 50,
                                                          backgroundColor:
                                                          Colors.transparent,
                                                        ),
                                                        onTap: () {
                                                          showDialog(
                                                              context: context,
                                                              builder: (builder) {
                                                                return AlertDialog(
                                                                  backgroundColor: user
                                                                      .colorProvider
                                                                      .addTaskAlertBackground,
                                                                  scrollable:
                                                                  true,
                                                                  content:
                                                                  const Column(
                                                                    mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                    children: [
                                                                      Row(
                                                                        mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                        children: [
                                                                          Avatar(
                                                                              number:
                                                                              "000"),
                                                                          Padding(
                                                                              padding:
                                                                              EdgeInsets.only(right: 10)),
                                                                          Avatar(
                                                                              number:
                                                                              "001"),
                                                                        ],
                                                                      ),
                                                                      Padding(
                                                                          padding:
                                                                          EdgeInsets.only(bottom: 10)),
                                                                      Row(
                                                                        mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                        children: [
                                                                          Avatar(
                                                                              number:
                                                                              "002"),
                                                                          Padding(
                                                                              padding:
                                                                              EdgeInsets.only(right: 10)),
                                                                          Avatar(
                                                                              number:
                                                                              "003"),
                                                                        ],
                                                                      ),
                                                                      Padding(
                                                                          padding:
                                                                          EdgeInsets.only(bottom: 10)),
                                                                      Row(
                                                                        mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                        children: [
                                                                          Avatar(
                                                                              number:
                                                                              "004"),
                                                                          Padding(
                                                                              padding:
                                                                              EdgeInsets.only(right: 10)),
                                                                          Avatar(
                                                                              number:
                                                                              "005"),
                                                                        ],
                                                                      ),
                                                                      Padding(
                                                                          padding:
                                                                          EdgeInsets.only(bottom: 10)),
                                                                      Row(
                                                                        mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                        children: [
                                                                          Avatar(
                                                                              number:
                                                                              "006"),
                                                                          Padding(
                                                                              padding:
                                                                              EdgeInsets.only(right: 10)),
                                                                          Avatar(
                                                                              number:
                                                                              "007"),
                                                                        ],
                                                                      ),
                                                                      Padding(
                                                                          padding:
                                                                          EdgeInsets.only(bottom: 10)),
                                                                      Row(
                                                                        mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                        children: [
                                                                          Avatar(
                                                                              number:
                                                                              "008"),
                                                                          Padding(
                                                                              padding:
                                                                              EdgeInsets.only(right: 10)),
                                                                          Avatar(
                                                                              number:
                                                                              "009"),
                                                                        ],
                                                                      )
                                                                    ],
                                                                  ),
                                                                );
                                                              }).then((onValue) {
                                                            if (context.mounted) {
                                                              Navigator.pop(
                                                                  context);
                                                            }
                                                          });
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  const Padding(
                                                      padding: EdgeInsets.only(
                                                          right: 15)),
                                                  Column(
                                                    mainAxisSize:
                                                    MainAxisSize.min,
                                                    children: [
                                                      GestureDetector(
                                                        child: const CircleAvatar(
                                                          backgroundImage: AssetImage(
                                                              "assets/person.png"),
                                                          radius: 50,
                                                        ),
                                                        onTap: () async {
                                                          user.pickAndSaveImage();
                                                          Navigator.pop(context);
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
                                child: Text(
                                  user.user.name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 40,
                                      color: user.colorProvider.profilePageName),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(flex: 1,),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: MediaQuery.sizeOf(context).width/2.9,
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
                                    children: [
                                      const Text(
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
                          ),
                        ],
                      ),
                      const Spacer(flex: 1,),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                              padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).size.height / 40)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SettingsButton(onPressed: (){
                                Provider.of<UserProvider>(context,
                                    listen: false)
                                    .changeTheme();
                              }, label: "Dark Mode", status: user.user.theme == 1 ? true : false, fontSize: 22, size: 1.5),
                              Padding(
                                  padding: EdgeInsets.only(
                                      right: MediaQuery.of(context).size.height / 40)),
                              SettingsButton(onPressed: (){
                                Provider.of<UserProvider>(context,
                                    listen: false)
                                    .changeAutoSave();
                              }, label: "Auto Save", status: user.user.autoSave == 1 ? true : false, fontSize: 22, size: 1.5),
                            ],
                          ),
                          Padding(
                              padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).size.height / 40)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SettingsButton(onPressed: (){
                                Provider.of<UserProvider>(context,
                                    listen: false)
                                    .changeFont();
                              }, label: "Casual Font", status: user.user.casual == 1 ? true : false, fontSize: 22, size: 1.5),
                              Padding(
                                  padding: EdgeInsets.only(
                                      right: MediaQuery.of(context).size.height / 40)),
                              SettingsButton(onPressed: (){
                                Provider.of<UserProvider>(context,
                                    listen: false)
                                    .changeLock();
                              }, label: "App Lock", status: user.isEnabled ? true : false, fontSize: 22, size: 1.5),
                            ],
                          )
                        ],
                      ),
                      const Spacer(flex: 1,),
                    ],
                  ),
                ],
              ),
            ));
      },
    );
  }
}
