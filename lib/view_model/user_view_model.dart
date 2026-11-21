import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/models/avatar.dart';
import 'package:todo/models/user_profile.dart';
import 'package:todo/models/verse.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/database_service.dart';
import 'package:todo/services/device_service.dart';
import 'package:todo/services/image_service.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/services/verse_service.dart';
import 'package:todo/repositories/user_repository.dart';
import '../core/prompts.dart';
import '../core/result.dart';

class UserViewModel with ChangeNotifier {
  UserViewModel({
    UserRepository? repository,
    ImageService? imageService,
    LockService? lockService,
    AuthenticationService? authService,
    DeviceService? deviceService,
    VerseService? verseService,
    DatabaseService? databaseService,
  })  : _userRepository = repository ?? UserRepository(),
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
      amoledTheme: false,
      autoSave: true,
      casualFont: false,
      showVerse: true,
      wordCount: false,
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
  final ImageService _imageService;
  final LockService _lockService;
  final AuthenticationService _authService;
  final DeviceService _deviceService;
  final VerseService _verseService;
  final DatabaseService _dbService;

  Future<void> get() async {
    List<UserProfile> users = await _userRepository.getUser();
    if (users.isEmpty) {
      await _userRepository.insertUser(user);
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

  /// Has [avatar] stand for the user. A photo of their own that stood for
  /// them before is deleted, but only once the profile has the new avatar:
  /// until then, it's the one the profile points at.
  Future<void> setAvatar(Avatar avatar) async {
    final old = user.avatar;
    if (avatar == old) return;
    await _save(user.copyWith(avatar: avatar));
    if (old is PhotoAvatar) {
      try {
        await _imageService.deletePhoto(old.path);
      } catch (e) {
        // Left behind, which only takes up a little room.
      }
    }
  }

  /// Has the user pick a photo of their own for their avatar, in place of
  /// whichever stands for them now.
  Future<void> pickPhoto() async {
    final path = await _imageService.pickProfilePicture();
    if (path != null) await setAvatar(PhotoAvatar(path));
  }

  Future<void> setDarkTheme(bool darkTheme) => _set(
      darkTheme == user.darkTheme, () => user.copyWith(darkTheme: darkTheme));

  Future<void> setAmoledTheme(bool amoled) => _set(
      amoled == user.amoledTheme, () => user.copyWith(amoledTheme: amoled));

  Future<void> setAutoSave(bool autoSave) => _set(
      autoSave == user.autoSave, () => user.copyWith(autoSave: autoSave));

  Future<void> setStartPage(StartPage startPage) => _set(
      startPage == user.startPage, () => user.copyWith(startPage: startPage));

  /// The view the to-do page's menu has switched to, away from the one the
  /// settings pick, which lasts until the app closes or the setting
  /// changes. Never saved, so the page opens with the settings' view.
  TasksView? _tasksViewForNow;

  /// How the to-do page shows the tasks: as its menu has switched them for
  /// now, or else as the settings pick.
  TasksView get shownTasksView => _tasksViewForNow ?? user.tasksView;

  /// Shows the tasks as [view] for now, as the to-do page's menu does,
  /// without saving it.
  void showTasksAs(TasksView view) {
    if (view == shownTasksView) return;
    _tasksViewForNow = view == user.tasksView ? null : view;
    notifyListeners();
  }

  /// Has the to-do page list the tasks, or map them, each time it opens,
  /// and now, in place of a view its menu has switched to.
  Future<void> setTasksView(TasksView view) async {
    final shown = shownTasksView;
    _tasksViewForNow = null;
    if (view != user.tasksView) {
      await _save(user.copyWith(tasksView: view));
    } else if (view != shown) {
      notifyListeners();
    }
  }

  /// Puts notes in the handwritten font, or back in the regular one. The
  /// home screen's note widget has a font of its own: see WidgetsViewModel.
  Future<void> setCasualFont(bool casualFont) => _set(
      casualFont == user.casualFont,
      () => user.copyWith(casualFont: casualFont));

  Future<void> setWordCount(bool wordCount) => _set(
      wordCount == user.wordCount, () => user.copyWith(wordCount: wordCount));

  Future<void> setShowVerse(bool showVerse) => _set(
      showVerse == user.showVerse, () => user.copyWith(showVerse: showVerse));

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
      await _save(user.copyWith(notesTextSize: size));
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
