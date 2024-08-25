import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/services/color_provider.dart';
import 'package:todo/services/database_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user, required this.colorProvider,
  });
  final ColorProvider colorProvider;
  final UserProfile user;
  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {

  File? imageFile;
  @override
  void initState() {
    if(widget.user.pic.isNotEmpty){
      setState(() {
        imageFile = File(widget.user.pic);
      });
    }
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
      setState(() {
        imageFile = savedImage;
      });
      DatabaseService().updateUser(UserProfile(id: widget.user.id,firstName: widget.user.firstName, lastName: widget.user.lastName, pic: imageFile!.path, theme: widget.user.theme));
    }
  }

  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.colorProvider.homePageBackground,
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
                    backgroundImage: imageFile?.path.compareTo("0")!=0? FileImage(imageFile!): const AssetImage("assets/avatar.png"),
                    radius: 100,
                    backgroundColor: Colors.transparent,
                  ),
                  Positioned(
                    bottom: 3,
                    right: 15,
                    child: IconButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.colorProvider.editPicButtonBackground,
                      ),
                        onPressed: () {
                        _pickAndSaveImage();
                        },
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blue,
                        )),
                  )
                ],
              )
            ],
          ),
          const Padding(padding: EdgeInsets.only(bottom: 10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${widget.user.firstName} ${widget.user.lastName}",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 40,
                    color: widget.colorProvider.profilePageName),
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
                  controller: firstNameController,
                  decoration: InputDecoration(
                    hintStyle: TextStyle(color: widget.colorProvider.profilePageText),
                      hintText: "First Name",
                      label: const Text("First Name"),
                      labelStyle: TextStyle(color: widget.colorProvider.profilePageText) ,
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
                  controller: lastNameController,
                  decoration: InputDecoration(
                      hintText: "Last Name",
                      hintStyle:  TextStyle(color: widget.colorProvider.profilePageText),
                      label: const Text("Last Name"),
                      labelStyle: TextStyle(color: widget.colorProvider.profilePageText) ,
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
                  backgroundColor: widget.colorProvider.profilePageButtonsBackground
                ),
                  onPressed: () {
                    setState(() {
                      widget.user.firstName = firstNameController.text;
                      widget.user.lastName = lastNameController.text;
                    });
                    DatabaseService().updateUser(widget.user);
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
                      backgroundColor: widget.colorProvider.profilePageButtonsBackground
                  ),
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
      ),
    ));
  }
}
