import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:todo/pages/notes_page.dart';
import 'package:todo/pages/profile_page.dart';
import 'package:todo/pages/todo_page.dart';

import '../models/user_profile.dart';
import '../services/color_provider.dart';
import '../services/database_service.dart';
import '../services/icon_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    getUser();
    super.initState();
  }

  List<UserProfile> user = [];
  bool isUserLoading = false;
  late ColorProvider colorProvider;
  void getUser() async {
    setState(() {
      isUserLoading = true;
    });
    user = await DatabaseService().getUser();
    if (user.isEmpty) {
      await DatabaseService().insertUser(
          UserProfile(firstName: "user", lastName: "", pic: "000", theme: 1));
      user = await DatabaseService().getUser();
    }
    colorProvider = ColorProvider(user.first.theme);
    setState(() {
      isUserLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return isUserLoading
        ? const SizedBox.shrink()
        : Scaffold(
            backgroundColor: colorProvider.pageBackground,
            appBar: AppBar(
              backgroundColor: colorProvider.pageBackground,
              title: Text(
                "Notes",
                style: TextStyle(
                  fontSize: 30,
                  color: colorProvider.appTitle,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                Row(
                  children: [
                    GestureDetector(
                      child: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        backgroundImage: user.first.pic
                                    .substring(0, 1)
                                    .compareTo("0") ==
                                0
                            ? AssetImage(IconProvider.getAvatar(user.first.pic))
                            : FileImage(File(user.first.pic)),
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
                                    colorProvider.profileAlertBackground,
                                title: CircleAvatar(
                                  radius: 130,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: user.first.pic
                                              .substring(0, 1)
                                              .compareTo("0") ==
                                          0
                                      ? AssetImage(IconProvider.getAvatar(
                                          user.first.pic))
                                      : FileImage(File(user.first.pic)),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Expanded(
                                            child: Text(
                                          "${user.first.firstName} ${user.first.lastName}",
                                          maxLines: 2,
                                          overflow: TextOverflow.clip,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 42),
                                        ))
                                      ],
                                    ),
                                    const Padding(
                                        padding: EdgeInsets.only(bottom: 10)),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  user.first.theme == 0
                                                      ? Colors.white
                                                      : Colors.black12,
                                            ),
                                            onPressed: () {
                                              if (user.first.theme == 0) {
                                                user.first.theme = 1;
                                                DatabaseService()
                                                    .updateUser(user.first)
                                                    .then((onValue) {
                                                  getUser();
                                                });
                                              } else {
                                                user.first.theme = 0;
                                                DatabaseService()
                                                    .updateUser(user.first)
                                                    .then((onValue) {
                                                  getUser();
                                                });
                                              }
                                              Navigator.pop(context);
                                            },
                                            child: Icon(user.first.theme == 1
                                                ? Icons.dark_mode_sharp
                                                : Icons.light_mode_sharp)),
                                        const Padding(
                                            padding:
                                                EdgeInsets.only(right: 30)),
                                        ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                PageRouteBuilder(
                                                  pageBuilder: (context,
                                                          animation,
                                                          secondaryAnimation) =>
                                                      ProfilePage(
                                                          user: user.first),
                                                  transitionsBuilder: (context,
                                                      animation,
                                                      secondaryAnimation,
                                                      child) {
                                                    const begin =
                                                        Offset(0.0, 1.0);
                                                    const end = Offset.zero;
                                                    const curve = Curves.ease;
                                                    var tween = Tween(
                                                            begin: begin,
                                                            end: end)
                                                        .chain(CurveTween(
                                                            curve: curve));
                                                    var offsetAnimation =
                                                        animation.drive(tween);
                                                    return SlideTransition(
                                                        position:
                                                            offsetAnimation,
                                                        child: child);
                                                  },
                                                ),
                                              ).then((e) {
                                                setState(() {
                                                  getUser();
                                                });
                                              });
                                            },
                                            child: const Icon(Icons.edit))
                                      ],
                                    )
                                  ],
                                ),
                              );
                            });
                      },
                    ),
                    const Padding(padding: EdgeInsets.only(right: 18))
                  ],
                )
              ],
            ),
            body: MediaQuery.of(context).size.width > 720
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation,
                                                  secondaryAnimation) =>
                                              const NotesPage(),
                                          transitionsBuilder: (context,
                                              animation,
                                              secondaryAnimation,
                                              child) {
                                            const begin = Offset(1.0, 0.0);
                                            const end = Offset.zero;
                                            const curve = Curves.ease;
                                            var tween = Tween(
                                                    begin: begin, end: end)
                                                .chain(
                                                    CurveTween(curve: curve));
                                            var offsetAnimation =
                                                animation.drive(tween);
                                            return SlideTransition(
                                                position: offsetAnimation,
                                                child: child);
                                          },
                                        ),
                                      );
                                    },
                                    icon: Image.asset(
                                      "assets/HomeIcons/notes.png",
                                      scale: 3,
                                    )),
                                Text(
                                  "Notes",
                                  style: TextStyle(
                                      color: colorProvider.homePageText,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Column(
                              children: [
                                IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation,
                                                  secondaryAnimation) =>
                                              const TodoPage(),
                                          transitionsBuilder: (context,
                                              animation,
                                              secondaryAnimation,
                                              child) {
                                            const begin = Offset(1.0, 0.0);
                                            const end = Offset.zero;
                                            const curve = Curves.ease;
                                            var tween = Tween(
                                                    begin: begin, end: end)
                                                .chain(
                                                    CurveTween(curve: curve));
                                            var offsetAnimation =
                                                animation.drive(tween);
                                            return SlideTransition(
                                                position: offsetAnimation,
                                                child: child);
                                          },
                                        ),
                                      );
                                    },
                                    icon: Image.asset(
                                      "assets/HomeIcons/todo.png",
                                      scale: 3,
                                    )),
                                Text(
                                  "ToDo",
                                  style: TextStyle(
                                      color: colorProvider.homePageText,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Column(
                              children: [
                                IconButton(
                                    onPressed: () {},
                                    icon: Image.asset(
                                      "assets/HomeIcons/diary.png",
                                      scale: 3,
                                    )),
                                Text(
                                  "Diary",
                                  style: TextStyle(
                                      color: colorProvider.homePageText,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Column(
                              children: [
                                IconButton(
                                    onPressed: () {},
                                    icon: Image.asset(
                                      "assets/HomeIcons/habitTracker.png",
                                      scale: 3,
                                    )),
                                Text(
                                  "Habits",
                                  style: TextStyle(
                                      color: colorProvider.homePageText,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Column(
                              children: [
                                IconButton(
                                    onPressed: () {},
                                    icon: Image.asset(
                                      "assets/HomeIcons/sticky_note.png",
                                      scale: 3,
                                    )),
                                Text(
                                  "Sticky Note",
                                  style: TextStyle(
                                      color: colorProvider.homePageText,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(padding: EdgeInsets.only(bottom: 50)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation,
                                                  secondaryAnimation) =>
                                              const NotesPage(),
                                          transitionsBuilder: (context,
                                              animation,
                                              secondaryAnimation,
                                              child) {
                                            const begin = Offset(1.0, 0.0);
                                            const end = Offset.zero;
                                            const curve = Curves.ease;
                                            var tween = Tween(
                                                    begin: begin, end: end)
                                                .chain(
                                                    CurveTween(curve: curve));
                                            var offsetAnimation =
                                                animation.drive(tween);
                                            return SlideTransition(
                                                position: offsetAnimation,
                                                child: child);
                                          },
                                        ),
                                      );
                                    },
                                    icon: Image.asset(
                                      "assets/HomeIcons/notes.png",
                                      scale: 3,
                                    )),
                                Text(
                                  "Notes",
                                  style: TextStyle(
                                      color: colorProvider.homePageText,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Column(
                              children: [
                                IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation,
                                                  secondaryAnimation) =>
                                              const TodoPage(),
                                          transitionsBuilder: (context,
                                              animation,
                                              secondaryAnimation,
                                              child) {
                                            const begin = Offset(1.0, 0.0);
                                            const end = Offset.zero;
                                            const curve = Curves.ease;
                                            var tween = Tween(
                                                    begin: begin, end: end)
                                                .chain(
                                                    CurveTween(curve: curve));
                                            var offsetAnimation =
                                                animation.drive(tween);
                                            return SlideTransition(
                                                position: offsetAnimation,
                                                child: child);
                                          },
                                        ),
                                      );
                                    },
                                    icon: Image.asset(
                                      "assets/HomeIcons/todo.png",
                                      scale: 3,
                                    )),
                                Text(
                                  "ToDo",
                                  style: TextStyle(
                                      color: colorProvider.homePageText,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            )
                          ],
                        ),
                        const Padding(padding: EdgeInsets.only(bottom: 15)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                IconButton(
                                    onPressed: () {},
                                    icon: Image.asset(
                                      "assets/HomeIcons/diary.png",
                                      scale: 3,
                                    )),
                                Text(
                                  "Diary",
                                  style: TextStyle(
                                      color: colorProvider.homePageText,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Column(
                              children: [
                                IconButton(
                                    onPressed: () {},
                                    icon: Image.asset(
                                      "assets/HomeIcons/habitTracker.png",
                                      scale: 3,
                                    )),
                                Text(
                                  "Habits",
                                  style: TextStyle(
                                      color: colorProvider.homePageText,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.only(bottom: 20)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                    onPressed: () {},
                                    icon: Image.asset(
                                      "assets/HomeIcons/sticky_note.png",
                                      scale: 3,
                                    )),
                                AutoSizeText(
                                  "Sticky Note",
                                  style: TextStyle(
                                      color: colorProvider.homePageText,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  minFontSize: 18,
                                )
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
          );
  }
}
