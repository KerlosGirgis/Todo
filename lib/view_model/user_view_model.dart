import 'package:flutter/foundation.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/avatar.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/models/verse.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/device_service.dart';
import 'package:todo/services/home_widget_service.dart';
import 'package:todo/services/image_service.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/services/verse_service.dart';
import 'package:todo/repositories/user_repository.dart';
import '../core/result.dart';

class UserViewModel with ChangeNotifier {
  UserViewModel({
    UserRepository? repository,
    HomeWidgetService? homeWidgetService,
    ImageService? imageService,
    LockService? lockService,
    AuthenticationService? authService,
    DeviceService? deviceService,
    VerseService? verseService,
  })  : _userRepository = repository ?? UserRepository(),
        _homeWidgetService = homeWidgetService ?? HomeWidgetService(),
        _imageService = imageService ?? ImageService(),
        _lockService = lockService ?? LockService(),
        _authService = authService ?? AuthenticationService(),
        _deviceService = deviceService ?? DeviceService(),
        _verseService = verseService ?? VerseService();

  UserProfile _user = UserProfile(
      name: "user",
      avatar: BundledAvatar.fallback,
      darkTheme:
          PlatformDispatcher.instance.platformBrightness == Brightness.dark,
      autoSave: true,
      casualFont: false,
      showVerse: true,
      wordCount: false,
      finished: 0,
      unfinished: 0,
      notesTextSize: 1,
      startPage: StartPage.tasks,
      descLines: 2,
      tasksTitleSize: 1,
      tasksDescSize: 1,
      notesTitleSize: 1);
  UserProfile get user => _user;

  /// What the app asks for each time it opens.
  AppLock _appLock = AppLock.off;
  AppLock get appLock => _appLock;

  /// The fewest characters an App Lock password can have.
  static const minPasswordLength = 4;

  /// Today's verse, or null when the user has turned the daily verse off.
  Verse? get dailyVerse =>
      user.showVerse ? Verse.parse(_verseService.getDailyVerse()) : null;

  final UserRepository _userRepository;
  final HomeWidgetService _homeWidgetService;
  final ImageService _imageService;
  final LockService _lockService;
  final AuthenticationService _authService;
  final DeviceService _deviceService;
  final VerseService _verseService;

  Future<void> get() async {
    List<UserProfile> users = await _userRepository.getUser();
    if (users.isEmpty) {
      _userRepository.insertUser(user);
      users = await _userRepository.getUser();
    }
    _user = users.first;
    _setAppLock(await _lockService.getLock());
    notifyListeners();
  }

  /// Sets what the app is locked with, keeping the app out of the recent
  /// apps while it's locked, as they'd show anyone its last screen.
  void _setAppLock(AppLock lock) {
    _appLock = lock;
    // Not worth failing over: the lock holds either way.
    _deviceService.hideFromRecents(lock != AppLock.off).ignore();
  }

  /// Saves [user] as the profile.
  Future<void> _save(UserProfile user) async {
    _user = user;
    await _userRepository.updateUser(user);
    notifyListeners();
  }

  Future<void> editName(String name) => _save(user.copyWith(name: name));

  Future<void> editPic(Avatar avatar) => _save(user.copyWith(avatar: avatar));

  Future<void> changeTheme() => _save(user.copyWith(darkTheme: !user.darkTheme));

  Future<void> changeAutoSave() =>
      _save(user.copyWith(autoSave: !user.autoSave));

  Future<void> changeStartPage(StartPage startPage) =>
      _save(user.copyWith(startPage: startPage));

  Future<void> changeFont() async {
    final casualFont = !user.casualFont;
    _user = user.copyWith(casualFont: casualFont);
    await _userRepository.updateUser(user);
    _homeWidgetService.setCasualFont(casualFont);
    notifyListeners();
  }

  Future<void> changeCount() =>
      _save(user.copyWith(wordCount: !user.wordCount));

  Future<void> changeVerse() =>
      _save(user.copyWith(showVerse: !user.showVerse));

  Future<void> resetPlot() =>
      _save(user.copyWith(unfinished: 0, finished: 0));

  /// Turns the App Lock off, once it lets the user through: with their
  /// fingerprint, or [password], whichever the app is locked with.
  Future<Result> turnOffAppLock({String? password}) async {
    if (!await _authService.passesAppLock(password: password)) {
      return Failure("Authentication Failed");
    }
    await _lockService.disableLock();
    _setAppLock(AppLock.off);
    notifyListeners();
    return Info("Lock Disabled");
  }

  /// Locks the app with the user's fingerprint, once the lock it has now lets
  /// them through, and their fingerprint shows that it works.
  Future<Result> lockWithFingerprint({String? password}) async {
    if (!await _authService.passesAppLock(password: password) ||
        !await _authService.authenticate()) {
      return Failure("Authentication Failed");
    }
    await _lockService.enableLock();
    _setAppLock(AppLock.fingerprint);
    notifyListeners();
    return Success("Fingerprint Lock Enabled");
  }

  /// Locks the app with [newPassword], once the lock it has now lets the user
  /// through: their fingerprint, or [password]. For an app locked with a
  /// password already, this changes it.
  Future<Result> lockWithPassword(String newPassword,
      {String? password}) async {
    if (newPassword.length < minPasswordLength) {
      return Failure("Use at least $minPasswordLength characters");
    }
    if (!await _authService.passesAppLock(password: password)) {
      return Failure("Authentication Failed");
    }
    final changing = _appLock == AppLock.password;
    await _lockService.enableLock(password: newPassword);
    _setAppLock(AppLock.password);
    notifyListeners();
    return Success(changing ? "Password Changed" : "Password Lock Enabled");
  }

  Future<Result> setNotesTextSize(double size) async {
    if (size >= 0.25 && size <= 2) {
      _user = user.copyWith(notesTextSize: size);
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
      await _save(user.copyWith(notesTitleSize: size));
      return Success("Font Changed");
    } else {
      return Failure("Enter Valid Value");
    }
  }

  Future<Result> setTasksTitleSize(double size) async {
    if (size >= 0.25 && size <= 2) {
      await _save(user.copyWith(tasksTitleSize: size));
      return Success("Font Changed");
    } else {
      return Failure("Enter Valid Value");
    }
  }

  Future<Result> setTasksDescSize(double size) async {
    if (size >= 0.25 && size <= 2) {
      await _save(user.copyWith(tasksDescSize: size));
      return Success("Font Changed");
    } else {
      return Failure("Enter Valid Value");
    }
  }

  Future<void> pickAndSaveImage() async {
    final avatar = user.avatar;
    final path = await _imageService.pickProfilePicture(
        replacing: avatar is PhotoAvatar ? avatar.path : null);
    if (path != null) {
      editPic(PhotoAvatar(path));
    }
  }

  Future<void> setDescLines(int numOfLines) async {
    if (numOfLines >= 0 && numOfLines < 10) {
      await _save(user.copyWith(descLines: numOfLines));
    }
  }
}
