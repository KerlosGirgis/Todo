import 'dart:io';
import 'dart:ui' show Color;

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/theme/palette.dart';

class ImageService {
  /// Has the user pick a photo from the gallery and crop it to a circle,
  /// then keeps a copy of it in the app's storage. The copy's path, or null
  /// when the user backs out.
  Future<String?> pickProfilePicture() async {
    final image = await _pickImage();
    if (image == null) return null;
    final croppedImage = await _cropImage(image);
    if (croppedImage == null) return null;
    final savedImage = await _saveImageToAppStorage(croppedImage);
    return savedImage.path;
  }

  /// Deletes the photo at [path], one [pickProfilePicture] kept, if it's
  /// still there. Never a file outside the app's own storage.
  Future<void> deletePhoto(String path) async {
    final appDir = await getApplicationDocumentsDirectory();
    if (!p.isWithin(appDir.path, path)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<File?> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    return pickedFile == null ? null : File(pickedFile.path);
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
          activeControlsWidgetColor: AppPalette.accent,
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

  Future<File> _saveImageToAppStorage(File image) async {
    final appDir = await getApplicationDocumentsDirectory();
    return image.copy(p.join(appDir.path, p.basename(image.path)));
  }
}
