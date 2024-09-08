import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:todo/pages/avatar.dart';
import 'package:todo/provider/user_provider.dart';

import '../services/icon_provider.dart';

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
    super.initState();
  }

  //final picker = ImagePicker();
  pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kDebugMode) {
        print("file returned");
      }
      return File(pickedFile.path);
    }
    return null;
  }

  saveImageToAppStorage(File image) async {
    final appDir = await getApplicationDocumentsDirectory();

    final fileName = image.path.split('/').last;

    final savedImage = await image.copy('${appDir.path}/$fileName');

    return savedImage;
  }

  _pickAndSaveImage() async {
    final image = await pickImage();
    if (image != null) {
      final savedImage = await saveImageToAppStorage(image);
        Provider.of<UserProvider>(context, listen: false).editPic(savedImage!.path);
    }
  }

  _saveAvatar(String avatarNum) async {
    Provider.of<UserProvider>(context, listen: false).editPic(avatarNum);
  }
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(builder: (context,user,child) {
      return Scaffold(
          backgroundColor: user.colorProvider.pageBackground,
          body: SingleChildScrollView(
              child: Column(
                children: [
                  const Padding(padding: EdgeInsets.only(bottom: 80)),
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
                                ? AssetImage(IconProvider.getAvatar(user.user.pic))
                                : FileImage(File(user.user.pic)),
                            radius: 100,
                            backgroundColor: Colors.transparent,
                          ),
                          Positioned(
                            bottom: 3,
                            right: 15,
                            child: IconButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  user.colorProvider.editPicButtonBackground,
                                ),
                                onPressed: () {
                                  showDialog(context: context, builder: (builder){
                                    return AlertDialog(
                                      backgroundColor: user.colorProvider.addTaskAlertBackground,
                                      content: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                child:
                                                CircleAvatar(
                                                  backgroundImage:
                                                  AssetImage(
                                                      IconProvider.getAvatar("000")),
                                                  radius: 50,
                                                  backgroundColor: Colors.transparent,
                                                ),
                                                onTap: () {
                                                  showDialog(
                                                      context: context,
                                                      builder: (builder) {
                                                        return AlertDialog(
                                                          backgroundColor: user.colorProvider.addTaskAlertBackground,
                                                          scrollable: true,
                                                          content: Column(
                                                            mainAxisSize:
                                                            MainAxisSize.min,
                                                            children: [
                                                              Row(
                                                                mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                                children: [
                                                                  Avatar(saveAvatar: _saveAvatar, number: "000"),
                                                                  const Padding(
                                                                      padding: EdgeInsets.only(
                                                                          right:
                                                                          10)),
                                                                  Avatar(saveAvatar: _saveAvatar, number: "001"),
                                                                ],
                                                              ),
                                                              const Padding(
                                                                  padding: EdgeInsets
                                                                      .only(
                                                                      bottom:
                                                                      10)),
                                                              Row(
                                                                mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                                children: [
                                                                  Avatar(saveAvatar: _saveAvatar, number: "002"),
                                                                  const Padding(
                                                                      padding: EdgeInsets.only(
                                                                          right:
                                                                          10)),
                                                          Avatar(saveAvatar: _saveAvatar, number: "003"),
                                                                ],
                                                              ),
                                                              const Padding(
                                                                  padding: EdgeInsets
                                                                      .only(
                                                                      bottom:
                                                                      10)),
                                                              Row(
                                                                mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                                children: [
                                                                  Avatar(saveAvatar: _saveAvatar, number: "004"),
                                                                  const Padding(
                                                                      padding: EdgeInsets.only(
                                                                          right:
                                                                          10)),
                                                                  Avatar(saveAvatar: _saveAvatar, number: "005"),
                                                                ],
                                                              ),
                                                              const Padding(
                                                                  padding: EdgeInsets
                                                                      .only(
                                                                      bottom:
                                                                      10)),
                                                              Row(
                                                                mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                                children: [
                                                                  Avatar(saveAvatar: _saveAvatar, number: "006"),
                                                                  const Padding(
                                                                      padding: EdgeInsets.only(
                                                                          right:
                                                                          10)),
                                                                  Avatar(saveAvatar: _saveAvatar, number: "007"),
                                                                ],
                                                              ),
                                                              const Padding(
                                                                  padding: EdgeInsets
                                                                      .only(
                                                                      bottom:
                                                                      10)),
                                                              Row(
                                                                mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                                children: [
                                                                  Avatar(saveAvatar: _saveAvatar, number: "008"),
                                                                  const Padding(
                                                                      padding: EdgeInsets.only(
                                                                          right:
                                                                          10)),
                                                                  Avatar(saveAvatar: _saveAvatar, number: "009"),
                                                                ],
                                                              )
                                                            ],
                                                          ),
                                                        );
                                                      }).then((onValue){
                                                    Navigator.pop(context);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          const Padding(padding: EdgeInsets.only(right: 15)),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                child:
                                                const CircleAvatar(
                                                  backgroundImage:
                                                  AssetImage(
                                                      "assets/person.png"),
                                                  radius: 50,
                                                ),
                                                onTap: () async{
                                                  _pickAndSaveImage();
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
                  const Padding(padding: EdgeInsets.only(bottom: 10)),
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
                  const Padding(padding: EdgeInsets.only(bottom: 50)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 350,
                        child: TextFormField(
                          style: TextStyle(color: user.colorProvider.profilePageText),
                          maxLines: 1,
                          maxLength: 7,
                          controller: firstNameController,
                          decoration: InputDecoration(
                              hintStyle:
                              TextStyle(color: user.colorProvider.profilePageText),
                              hintText: "First Name",
                              label: const Text("First Name"),
                              labelStyle:
                              TextStyle(color: user.colorProvider.profilePageText),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13))),
                        ),
                      )
                    ],
                  ),
                  const Padding(padding: EdgeInsets.only(bottom: 50)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 350,
                        child: TextFormField(
                          style: TextStyle(color: user.colorProvider.profilePageText),
                          maxLines: 1,
                          maxLength: 7,
                          controller: lastNameController,
                          decoration: InputDecoration(
                              hintText: "Last Name",
                              hintStyle:
                              TextStyle(color: user.colorProvider.profilePageText),
                              label: const Text("Last Name"),
                              labelStyle:
                              TextStyle(color: user.colorProvider.profilePageText),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13))),
                        ),
                      )
                    ],
                  ),
                  const Padding(padding: EdgeInsets.only(bottom: 100)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                              user.colorProvider.profilePageButtonsBackground),
                          onPressed: () {
                            Provider.of<UserProvider>(context, listen: false).editFirstName(firstNameController.text);
                            Provider.of<UserProvider>(context, listen: false).editLastName(lastNameController.text);
                          },
                          child: const Text(
                            "Save",
                            style: TextStyle(fontSize: 42),
                          ))
                    ],
                  ),
                  const Padding(padding: EdgeInsets.only(bottom: 20)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                              user.colorProvider.profilePageButtonsBackground),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Back",
                            style: TextStyle(fontSize: 42),
                          ))
                    ],
                  ),
                ],
              )));
    },
    );
  }
}
