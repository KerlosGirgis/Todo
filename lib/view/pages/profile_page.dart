import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:todo/view/widgets/avatar.dart';
import 'package:todo/provider/user_provider.dart';

import '../../services/icon_provider.dart';
import '../widgets/button.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
  });
  //final ColorProvider colorProvider;
  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    firstNameController.text=Provider.of<UserProvider>(context, listen: false).user.firstName;
    lastNameController.text=Provider.of<UserProvider>(context, listen: false).user.lastName;
    super.initState();
  }


  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
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
                IconButton(onPressed: (){
                  Fluttertoast.showToast(
                      msg: "Developed with ❤️ by Kerlos Girgis",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.blue,
                      textColor:
                      user.colorProvider.appTitle,
                      fontSize: 18.0);
                }, icon: Icon(Icons.question_mark,color: user.colorProvider.appTitle,))
              ],
            ),
            backgroundColor: user.colorProvider.pageBackground,
            body: SingleChildScrollView(
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
                                                                content: const Column(
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
                                                          Navigator.pop(
                                                              context);
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
                            bottom: MediaQuery.of(context).size.height / 90)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${user.user.firstName} ${user.user.lastName}",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 40,
                              color: user.colorProvider.profilePageName),
                        )
                      ],
                    ),
                    Padding(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height / 50)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 1.3,
                          child: TextFormField(
                            style: TextStyle(
                                color: user.colorProvider.profilePageText),
                            maxLines: 1,
                            maxLength: 7,
                            controller: firstNameController,
                            decoration: InputDecoration(
                                hintStyle: TextStyle(
                                    color: user.colorProvider.profilePageText),
                                hintText: "First Name",
                                label: const Text("First Name"),
                                labelStyle: TextStyle(
                                    color: user.colorProvider.profilePageText),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13))),
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
                          width: MediaQuery.of(context).size.width / 1.3,
                          child: TextFormField(
                            style: TextStyle(
                                color: user.colorProvider.profilePageText),
                            maxLines: 1,
                            maxLength: 7,
                            controller: lastNameController,
                            decoration: InputDecoration(
                                hintText: "Last Name",
                                hintStyle: TextStyle(
                                    color: user.colorProvider.profilePageText),
                                label: const Text("Last Name"),
                                labelStyle: TextStyle(
                                    color: user.colorProvider.profilePageText),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13))),
                          ),
                        )
                      ],
                    ),
                    Padding(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height / 50)),
                    Row(
                      children: [
                        const Spacer(flex: 1,),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Dark Mode",
                              style: TextStyle(
                                  color: user.colorProvider.appTitle, fontSize: 32),
                            ),
                            Padding(
                                padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(context).size.height / 50)),
                            Text(
                              "Auto Save",
                              style: TextStyle(
                                  color: user.colorProvider.appTitle, fontSize: 32),
                            ),
                            Padding(
                                padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(context).size.height / 50)),
                            Text(
                              "Casual Font",
                              style: TextStyle(
                                  color: user.colorProvider.appTitle, fontSize: 32),
                            ),
                          ],
                        ),
                        const Spacer(flex: 1,),
                        Column(
                          children: [
                            Switch(
                                value: user.user.theme == 1 ? true : false,
                                onChanged: (value) {
                                  Provider.of<UserProvider>(context, listen: false)
                                      .changeTheme();
                                }),
                            Padding(
                                padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(context).size.height / 50)),
                            Switch(
                                value: user.user.autoSave == 1 ? true : false,
                                onChanged: (value) {
                                  Provider.of<UserProvider>(context, listen: false)
                                      .changeAutoSave();
                                }),
                            Padding(
                                padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(context).size.height / 50)),
                            Switch(
                                value: user.user.casual == 1 ? true : false,
                                onChanged: (value) {
                                  Provider.of<UserProvider>(context, listen: false).changeFont();
                                }),
                          ],
                        ),
                        const Spacer(
                          flex: 1,
                        ),
                      ],
                    ),
                    Padding(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height / 11.5)),
                    //if(firstNameController.text.compareTo(user.user.firstName)!=0||lastNameController.text.compareTo(user.user.lastName)!=0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Button(
                          onPressed: () {
                            Provider.of<UserProvider>(context, listen: false)
                                .editFirstName(firstNameController.text);
                            Provider.of<UserProvider>(context, listen: false)
                                .editLastName(lastNameController.text);
                          },
                          label: 'Save',
                          fontSize: 42,
                          status: firstNameController.text.compareTo(user.user.firstName)!=0||lastNameController.text.compareTo(user.user.lastName)!=0,
                          size: 1.5,
                        )
                      ],
                    ),
                    Padding(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height / 40)),
                  ],
                )));
      },
    );
  }
}
