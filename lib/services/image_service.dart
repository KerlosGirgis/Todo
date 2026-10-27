import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  /// Has the user pick a photo from the gallery and crop it to a circle,
  /// then keeps it in the app's storage, deleting the photo at [replacing],
  /// if there's one. The kept photo's path, or null when the user backs out.
  Future<String?> pickProfilePicture({String? replacing}) async {
    final image = await _pickImage();
    if (image == null) return null;
    final croppedImage = await _cropImage(image);
    if (croppedImage == null) return null;
    final savedImage = await _saveImageToAppStorage(croppedImage, replacing);
    return savedImage.path;
  }

  Future<File?> _pickImage() async {
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

  Future<File?> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarColor: const Color(0xff000000),
          statusBarLight: false,
          backgroundColor: const Color(0xff000000),
          toolbarWidgetColor: const Color(0xffffffff),
          activeControlsWidgetColor: const Color(0xff3D5AFE),
          initAspectRatio: CropAspectRatioPreset.original,
          cropStyle: CropStyle.circle,
          lockAspectRatio: false,
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }

  Future<File> _saveImageToAppStorage(File image, String? replacing) async {
    final appDir = await getApplicationDocumentsDirectory();

    final fileName = image.path.split('/').last;
    if (replacing != null) {
      final oldFile = File(replacing);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    }
    final savedImage = await image.copy('${appDir.path}/$fileName');

    return savedImage;
  }
}
