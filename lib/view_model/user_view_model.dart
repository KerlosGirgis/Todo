import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/avatar.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/models/verse.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/database_service.dart';
import 'package:todo/services/device_service.dart';
import 'package:todo/services/home_widget_service.dart';
import 'package:todo/services/image_service.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/services/verse_service.dart';
import 'package:todo/repositories/user_repository.dart';
import '../core/prompts.dart';
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
    DatabaseService? databaseService,
  })  : _userRepository = repository ?? UserRepository(),
        _homeWidgetService = homeWidgetService ?? HomeWidgetService(),
        _imageService = imageService ?? ImageService(),
        _lockService = lockService ?? LockService(),
        _authService =
            authService ?? AuthenticationService(lockService: lockService),
        _deviceService = deviceService ?? DeviceService(),
        _verseService = verseService ?? VerseService(),
        _dbService = databaseService ?? DatabaseService();

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

  /// The most characters a name can have.
  static const maxNameLength = 20;

  /// The text sizes on offer, as multiples of the default ones: from a
  /// quarter to twice the size, in eighths.
  static const minTextSize = 0.25;
  static const maxTextSize = 2.0;
  static const textSizeStep = 0.125;

  /// The most lines of a task's description that can show before "Show
  /// More".
  static const maxDescLines = 5;

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
  final DatabaseService _dbService;

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

  /// Reads what the app is locked with, which, unlike the profile, needs
  /// nothing opened first, as the app checks it before it opens.
  Future<void> loadAppLock() async {
    final lock = await _lockService.getLock();
    final changed = lock != _appLock;
    _setAppLock(lock);
    if (changed) notifyListeners();
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

  /// Saves the profile with [change], unless [unchanged]: a notification
  /// rebuilds every page that shows the profile.
  Future<void> _set(bool unchanged, UserProfile Function() change) async {
    if (!unchanged) await _save(change());
  }

  /// Renames the user to [name], without the spaces at either end.
  Future<Result> rename(String name) async {
    name = name.trim();
    if (name.isEmpty) return Failure("Name can't be empty");
    // Counted as the name's field counts them, by what reads as one.
    if (name.characters.length > maxNameLength) {
      return Failure("Use at most $maxNameLength characters");
    }
    await _save(user.copyWith(name: name));
    return Info("Name Updated");
  }

  Future<void> setAvatar(Avatar avatar) =>
      _set(avatar == user.avatar, () => user.copyWith(avatar: avatar));

  /// Has the user pick a photo of their own for their avatar, in place of
  /// the one they picked before, if they did.
  Future<void> pickPhoto() async {
    final avatar = user.avatar;
    final path = await _imageService.pickProfilePicture(
        replacing: avatar is PhotoAvatar ? avatar.path : null);
    if (path != null) {
      setAvatar(PhotoAvatar(path));
    }
  }

  Future<void> setDarkTheme(bool darkTheme) => _set(
      darkTheme == user.darkTheme, () => user.copyWith(darkTheme: darkTheme));

  Future<void> setAutoSave(bool autoSave) => _set(
      autoSave == user.autoSave, () => user.copyWith(autoSave: autoSave));

  Future<void> setStartPage(StartPage startPage) => _set(
      startPage == user.startPage, () => user.copyWith(startPage: startPage));

  /// Puts notes, and the home screen's widget, in the handwritten font, or
  /// back in the regular one.
  Future<void> setCasualFont(bool casualFont) async {
    if (casualFont == user.casualFont) return;
    _user = user.copyWith(casualFont: casualFont);
    await _userRepository.updateUser(user);
    _homeWidgetService.setCasualFont(casualFont);
    notifyListeners();
  }

  Future<void> setWordCount(bool wordCount) => _set(
      wordCount == user.wordCount, () => user.copyWith(wordCount: wordCount));

  Future<void> setShowVerse(bool showVerse) => _set(
      showVerse == user.showVerse, () => user.copyWith(showVerse: showVerse));

  Future<void> resetPlot() =>
      _save(user.copyWith(unfinished: 0, finished: 0));

  /// Changes what the app is locked with to [lock], once the lock it has now
  /// lets the user through: their fingerprint, or the password
  /// [askForPassword] gets from them. A password lock takes a new password
  /// from [askForNewPassword]; for an app locked with one already, this
  /// changes it. Null if the user cancels.
  Future<Result?> changeAppLock(
    AppLock lock, {
    required PasswordPrompt askForPassword,
    required NewPasswordPrompt askForNewPassword,
  }) async {
    String? password;
    if (_appLock == AppLock.password) {
      password = await askForPassword();
      if (password == null) return null;
    }
    switch (lock) {
      case AppLock.off:
        return _turnOffAppLock(password: password);
      case AppLock.fingerprint:
        return _lockWithFingerprint(password: password);
      case AppLock.password:
        final newPassword =
            await askForNewPassword(minLength: minPasswordLength);
        if (newPassword == null) return null;
        return _lockWithPassword(newPassword, password: password);
    }
  }

  /// Turns the App Lock off, once it lets the user through: with their
  /// fingerprint, or [password], whichever the app is locked with.
  Future<Result> _turnOffAppLock({String? password}) async {
    if (!await _authService.passesAppLock(password: password)) {
      return Failure("Authentication Failed");
    }
    if (!await _withKey((key) => _lockService.disableLock(key: key))) {
      return Failure(_unchangeable);
    }
    _setAppLock(AppLock.off);
    notifyListeners();
    return Info("Lock Disabled");
  }

  /// Locks the app with the user's fingerprint, once the lock it has now lets
  /// them through, and their fingerprint shows that it works.
  Future<Result> _lockWithFingerprint({String? password}) async {
    if (!await _authService.passesAppLock(password: password) ||
        !await _authService.authenticate()) {
      return Failure("Authentication Failed");
    }
    if (!await _withKey((key) => _lockService.enableLock(key: key))) {
      return Failure(_unchangeable);
    }
    _setAppLock(AppLock.fingerprint);
    notifyListeners();
    return Success("Fingerprint Lock Enabled");
  }

  /// Locks the app with [newPassword], once the lock it has now lets the user
  /// through: their fingerprint, or [password]. For an app locked with a
  /// password already, this changes it.
  Future<Result> _lockWithPassword(String newPassword,
      {String? password}) async {
    if (newPassword.length < minPasswordLength) {
      return Failure("Use at least $minPasswordLength characters");
    }
    if (!await _authService.passesAppLock(password: password)) {
      return Failure("Authentication Failed");
    }
    final changing = _appLock == AppLock.password;
    if (!await _withKey(
        (key) => _lockService.enableLock(password: newPassword, key: key))) {
      return Failure(_unchangeable);
    }
    _setAppLock(AppLock.password);
    notifyListeners();
    return Success(changing ? "Password Changed" : "Password Lock Enabled");
  }

  static const _unchangeable = "Couldn't change the App Lock";

  /// Changes the lock with [change], given the database's key, which the
  /// lock keeps as it is, or a password locks: the one it's open with.
  /// Whether it did.
  Future<bool> _withKey(Future<void> Function(String key) change) async {
    final key = _dbService.key;
    if (key == null) return false;
    try {
      await change(key);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Whether [size] is one of the text sizes on offer.
  static bool _isTextSize(double size) =>
      size >= minTextSize && size <= maxTextSize;

  Future<Result> setNotesTextSize(double size) async {
    if (_isTextSize(size)) {
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
    if (_isTextSize(size)) {
      await _save(user.copyWith(notesTitleSize: size));
      return Success("Font Changed");
    } else {
      return Failure("Enter Valid Value");
    }
  }

  Future<Result> setTasksTitleSize(double size) async {
    if (_isTextSize(size)) {
      await _save(user.copyWith(tasksTitleSize: size));
      return Success("Font Changed");
    } else {
      return Failure("Enter Valid Value");
    }
  }

  Future<Result> setTasksDescSize(double size) async {
    if (_isTextSize(size)) {
      await _save(user.copyWith(tasksDescSize: size));
      return Success("Font Changed");
    } else {
      return Failure("Enter Valid Value");
    }
  }

  /// Shows [lines] lines of a task's description before "Show More", or the
  /// whole of it for 0.
  Future<void> setDescLines(int lines) async {
    if (lines >= 0 && lines <= maxDescLines) {
      await _set(
          lines == user.descLines, () => user.copyWith(descLines: lines));
    }
  }
}
