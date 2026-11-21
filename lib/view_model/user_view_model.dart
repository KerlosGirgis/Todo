import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../models/app_lock.dart';
import '../models/avatar.dart';
import '../models/user_profile.dart';
import '../models/verse.dart';
import '../services/authentication_service.dart';
import '../services/database_service.dart';
import '../services/device_service.dart';
import '../services/image_service.dart';
import '../services/lock_service.dart';
import '../services/verse_service.dart';
import '../repositories/user_repository.dart';
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
  }) : _userRepository = repository ?? UserRepository(),
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
    notesTitleSize: 1,
  );
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

  /// The saves in hand, which go one at a time, in order, so that each
  /// changes the profile as the one before it left it.
  Future<void> _saving = Future.value();

  static const _unsaved = Failure("Couldn't change the setting");
  static const _avatarUnchanged = Failure("Couldn't change the avatar");

  /// Saves the profile [change] makes of it, as the saves before it leave
  /// it, then shows it, doing [along] as well: only once it's saved, so the
  /// pages show what's kept. Nothing's saved when [change] gives null, for
  /// a profile it leaves as it is, as a notification rebuilds every page
  /// that shows the profile. [saved] once it's saved, null when there was
  /// nothing to save, and [failure] when it can't be, which leaves the
  /// profile as it was.
  Future<Result?> _save(
    UserProfile? Function(UserProfile user) change, {
    Result? saved,
    Failure failure = _unsaved,
    VoidCallback? along,
  }) {
    final saving = _saving.then((_) async {
      final changed = change(_user);
      if (changed == null) return null;
      try {
        await _userRepository.updateUser(changed);
      } catch (e) {
        return failure;
      }
      _user = changed;
      along?.call();
      notifyListeners();
      return saved;
    });
    _saving = saving;
    return saving;
  }

  /// Renames the user to [name], without the spaces at either end.
  Future<Result> rename(String name) async {
    name = name.trim();
    if (name.isEmpty) return Failure("Name can't be empty");
    // Counted as the name's field counts them, by what reads as one.
    if (name.characters.length > maxNameLength) {
      return Failure("Use at most $maxNameLength characters");
    }
    return await _save(
          (user) => user.copyWith(name: name),
          failure: const Failure("Couldn't change the name"),
        ) ??
        const Info("Name Updated");
  }

  /// Has [avatar] stand for the user. A photo of their own that stood for
  /// them before is deleted, but only once the profile has the new avatar:
  /// until then, it's the one the profile points at. Why it couldn't be
  /// changed, or null.
  Future<Result?> setAvatar(Avatar avatar) async {
    Avatar? replaced;
    final result = await _save((user) {
      if (user.avatar == avatar) return null;
      replaced = user.avatar;
      return user.copyWith(avatar: avatar);
    }, failure: _avatarUnchanged);
    if (replaced case PhotoAvatar(:final path) when result == null) {
      await _deletePhoto(path);
    }
    return result;
  }

  /// Has the user pick a photo of their own for their avatar, in place of
  /// whichever stands for them now. Why it couldn't be changed, or null, as
  /// when they back out.
  Future<Result?> pickPhoto() async {
    final String? path;
    try {
      path = await _imageService.pickProfilePicture();
    } catch (e) {
      return _avatarUnchanged;
    }
    if (path == null) return null;
    final result = await setAvatar(PhotoAvatar(path));
    // A copy the profile doesn't point at isn't kept.
    if (result != null) await _deletePhoto(path);
    return result;
  }

  /// Deletes the photo at [path], one the user picked, if it can.
  Future<void> _deletePhoto(String path) async {
    try {
      await _imageService.deletePhoto(path);
    } catch (e) {
      // Left behind, which only takes up a little room.
    }
  }

  // Each of these says why it couldn't save the setting, or gives null.

  Future<Result?> setDarkTheme(bool darkTheme) => _save(
    (user) => user.darkTheme == darkTheme
        ? null
        : user.copyWith(darkTheme: darkTheme),
  );

  Future<Result?> setAmoledTheme(bool amoled) => _save(
    (user) =>
        user.amoledTheme == amoled ? null : user.copyWith(amoledTheme: amoled),
  );

  Future<Result?> setAutoSave(bool autoSave) => _save(
    (user) =>
        user.autoSave == autoSave ? null : user.copyWith(autoSave: autoSave),
  );

  Future<Result?> setStartPage(StartPage startPage) => _save(
    (user) => user.startPage == startPage
        ? null
        : user.copyWith(startPage: startPage),
  );

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
  /// and now, in place of a view its menu has switched to. Should it not be
  /// saved, the page shows the tasks as it did.
  Future<Result?> setTasksView(TasksView view) async {
    final result = await _save(
      (user) => user.tasksView == view ? null : user.copyWith(tasksView: view),
      along: () => _tasksViewForNow = null,
    );
    // The view the settings pick already, in place of one the menu has
    // switched to: nothing to save, only the page to show it again.
    if (result == null && _tasksViewForNow != null) {
      _tasksViewForNow = null;
      notifyListeners();
    }
    return result;
  }

  /// Puts notes in the handwritten font, or back in the regular one. The
  /// home screen's note widget has a font of its own: see WidgetsViewModel.
  Future<Result?> setCasualFont(bool casualFont) => _save(
    (user) => user.casualFont == casualFont
        ? null
        : user.copyWith(casualFont: casualFont),
  );

  Future<Result?> setWordCount(bool wordCount) => _save(
    (user) => user.wordCount == wordCount
        ? null
        : user.copyWith(wordCount: wordCount),
  );

  Future<Result?> setShowVerse(bool showVerse) => _save(
    (user) => user.showVerse == showVerse
        ? null
        : user.copyWith(showVerse: showVerse),
  );

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
        final newPassword = await askForNewPassword(
          minLength: minPasswordLength,
        );
        if (newPassword == null) return null;
        return _lockWithPassword(newPassword, password: password);
    }
  }

  /// Turns the App Lock off, once it lets the user through: with their
  /// fingerprint, or [password], whichever the app is locked with.
  Future<Result> _turnOffAppLock({String? password}) async {
    if (!await _authService.passesAppLock(password: password)) {
      return Failure("Authentication failed");
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
      return Failure("Authentication failed");
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
  Future<Result> _lockWithPassword(
    String newPassword, {
    String? password,
  }) async {
    if (newPassword.length < minPasswordLength) {
      return Failure("Use at least $minPasswordLength characters");
    }
    if (!await _authService.passesAppLock(password: password)) {
      return Failure("Authentication failed");
    }
    final changing = _appLock == AppLock.password;
    if (!await _withKey(
      (key) => _lockService.enableLock(password: newPassword, key: key),
    )) {
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

  Future<Result?> setNotesTextSize(double size) => _setTextSize(
    size,
    (user) => user.notesTextSize,
    (user) => user.copyWith(notesTextSize: size),
  );

  Future<Result?> setNotesTitleSize(double size) => _setTextSize(
    size,
    (user) => user.notesTitleSize,
    (user) => user.copyWith(notesTitleSize: size),
  );

  Future<Result?> setTasksTitleSize(double size) => _setTextSize(
    size,
    (user) => user.tasksTitleSize,
    (user) => user.copyWith(tasksTitleSize: size),
  );

  Future<Result?> setTasksDescSize(double size) => _setTextSize(
    size,
    (user) => user.tasksDescSize,
    (user) => user.copyWith(tasksDescSize: size),
  );

  /// Saves [size], one of the text sizes on offer, as [change] sets it,
  /// unless it's the size [current] reads already: then there's nothing to
  /// say.
  Future<Result?> _setTextSize(
    double size,
    double Function(UserProfile user) current,
    UserProfile Function(UserProfile user) change,
  ) async {
    if (!_isTextSize(size)) {
      return const Failure("That text size isn't on offer");
    }
    return _save(
      (user) => current(user) == size ? null : change(user),
      saved: const Success("Text Size Changed"),
      failure: const Failure("Couldn't change the text size"),
    );
  }

  /// Shows [lines] lines of a task's description before "Show More", or the
  /// whole of it for 0. Why it couldn't be saved, or null.
  Future<Result?> setDescLines(int lines) async {
    if (lines < 0 || lines > maxDescLines) {
      return const Failure("That number of lines isn't on offer");
    }
    return _save(
      (user) =>
          user.descLines == lines ? null : user.copyWith(descLines: lines),
    );
  }
}
