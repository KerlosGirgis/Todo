import 'package:flutter/foundation.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/home_widget_service.dart';
import 'package:todo/services/image_service.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/services/verse_service.dart';
import 'package:todo/repositories/user_repository.dart';
import '../core/result.dart';

class UserViewModel with ChangeNotifier {
  UserProfile _user = UserProfile(
      name: "user",
      pic: "000",
      theme: PlatformDispatcher.instance.platformBrightness == Brightness.dark
          ? 1
          : 0,
      autoSave: 1,
      casual: 0,
      verse: 1,
      count: 0,
      finished: 0,
      unFinished: 0,
      notesTextSize: 1,
      startPage: 0,
      descLines: 2,
      tasksTitleSize: 1,
      tasksDescSize: 1,
      notesTitleSize: 1);
  UserProfile get user => _user;

  /// Whether the app is locked with the user's fingerprint.
  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  /// Today's verse, or null when the user has turned the daily verse off.
  String? get dailyVerse =>
      user.verse == 1 ? VerseService.getDailyVerse() : null;

  final UserRepository _userRepository = UserRepository();
  final HomeWidgetService _homeWidgetService = HomeWidgetService();
  final ImageService _imageService = ImageService();

  Future<void> get() async {
    List<UserProfile> users = await _userRepository.getUser();
    if (users.isEmpty) {
      _userRepository.insertUser(user);
      users = await _userRepository.getUser();
    }
    _user = users.first;
    _isEnabled = await LockService().isLockEnabled();
    notifyListeners();
  }

  Future<void> editName(String name) async {
    user.name = name;
    await _userRepository.updateUser(user);
    notifyListeners();
  }

  Future<void> editPic(String pic) async {
    user.pic = pic;
    await _userRepository.updateUser(user);
    notifyListeners();
  }

  Future<void> changeTheme() async {
    if (user.theme == 1) {
      user.theme = 0;
      await _userRepository.updateUser(user);
      notifyListeners();
    } else {
      user.theme = 1;
      await _userRepository.updateUser(user);
      notifyListeners();
    }
  }

  Future<void> changeAutoSave() async {
    if (user.autoSave == 1) {
      user.autoSave = 0;
      await _userRepository.updateUser(user);
      notifyListeners();
    } else {
      user.autoSave = 1;
      await _userRepository.updateUser(user);
      notifyListeners();
    }
  }

  Future<void> changeStartPage(int startPage) async {
    user.startPage = startPage;
    await _userRepository.updateUser(user);
    notifyListeners();
  }

  Future<void> changeFont() async {
    if (user.casual == 1) {
      user.casual = 0;
      await _userRepository.updateUser(user);
      _homeWidgetService.setCasualFont(false);
      notifyListeners();
    } else {
      user.casual = 1;
      await _userRepository.updateUser(user);
      _homeWidgetService.setCasualFont(true);
      notifyListeners();
    }
  }

  Future<void> changeCount() async {
    if (user.count == 1) {
      user.count = 0;
      await _userRepository.updateUser(user);
      notifyListeners();
    } else {
      user.count = 1;
      await _userRepository.updateUser(user);
      notifyListeners();
    }
  }

  Future<void> changeVerse() async {
    if (user.verse == 1) {
      user.verse = 0;
      await _userRepository.updateUser(user);
      notifyListeners();
    } else {
      user.verse = 1;
      await _userRepository.updateUser(user);
      notifyListeners();
    }
  }

  Future<void> resetPlot() async {
    user.unFinished = 0;
    user.finished = 0;
    await _userRepository.updateUser(user);
    notifyListeners();
  }

  Future<Result> changeLock() async {
    final bool auth = await AuthenticationService().authenticate();
    if (auth) {
      if (_isEnabled) {
        await LockService().disableLock();
        _isEnabled = false;
        notifyListeners();
        return Info("Lock Disabled");
      } else {
        await LockService().enableLock();
        _isEnabled = true;
        notifyListeners();
        return Success("Lock Enabled");
      }
    } else {
      return Failure("Authentication Failed");
    }
  }

  Future<Result> setNotesTextSize(double size) async {
    if (size >= 0.25 && size <= 2) {
      user.notesTextSize = size;
      await _homeWidgetService.setTextSize(user.notesTextSize);
      await _userRepository.updateUser(user);
      notifyListeners();
      return Success("Font Changed");
    } else {
      return Failure("Enter Valid Value");
    }
  }

  Future<Result> setNotesTitleSize(double size) async {
    if (size >= 0.25 && size <= 2) {
      user.notesTitleSize = size;
      await _userRepository.updateUser(user);
      notifyListeners();
      return Success("Font Changed");
    } else {
      return Failure("Enter Valid Value");
    }
  }

  Future<Result> setTasksTitleSize(double size) async {
    if (size >= 0.25 && size <= 2) {
      user.tasksTitleSize = size;
      await _userRepository.updateUser(user);
      notifyListeners();
      return Success("Font Changed");
    } else {
      return Failure("Enter Valid Value");
    }
  }

  Future<Result> setTasksDescSize(double size) async {
    if (size >= 0.25 && size <= 2) {
      user.tasksDescSize = size;
      await _userRepository.updateUser(user);
      notifyListeners();
      return Success("Font Changed");
    } else {
      return Failure("Enter Valid Value");
    }
  }

  Future<void> pickAndSaveImage() async {
    final path = await _imageService.pickProfilePicture(replacing: user.pic);
    if (path != null) {
      editPic(path);
    }
  }

  Future<void> setDescLines(int numOfLines) async {
    if (numOfLines >= 0 && numOfLines < 10) {
      user.descLines = numOfLines;
      await _userRepository.updateUser(user);
      notifyListeners();
    }
  }
}
