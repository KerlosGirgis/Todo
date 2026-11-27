import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../models/app_lock.dart';
import '../models/user_profile.dart';
import '../services/authentication_service.dart';
import '../services/database_service.dart';
import '../services/device_service.dart';
import '../services/lock_service.dart';
import '../services/verse_service.dart';
import 'user_view_model.dart';

enum AuthStatus {
  initializing,
  authenticated,
  unauthenticated,

  /// The app couldn't open the tasks and notes, once the App Lock, if it
  /// has one, let the user through. They can try again.
  failed,
}

class AuthViewModel with ChangeNotifier {
  /// `onOpened` reads in what the app's pages show, once the app has opened.
  AuthViewModel(
    this._userViewModel, {
    AuthenticationService? authService,
    LockService? lockService,
    DatabaseService? databaseService,
    DeviceService? deviceService,
    VerseService? verseService,
    this._onOpened,
  }) : _lockService = lockService ?? LockService(),
       _dbService = databaseService ?? DatabaseService(),
       _deviceService = deviceService ?? DeviceService(),
       _verseService = verseService ?? VerseService() {
    // Against the same lock as this, given or made here.
    _authService =
        authService ?? AuthenticationService(lockService: _lockService);
  }

  AuthStatus _status = AuthStatus.unauthenticated;
  AuthStatus get status => _status;

  /// Whether the app has been unlocked since it started, so that its pages
  /// are open, under the lock page whenever it locks again.
  bool _opened = false;
  bool get opened => _opened;

  /// The page the app opened on: the start page the profile had as the app
  /// first opened, which the home page keeps to while the app runs. A start
  /// page picked in the settings since is for the next time the app starts,
  /// so the page under the settings stays as it was. The to-do page until
  /// the app has opened.
  StartPage get openedOn => _openedOn;
  StartPage _openedOn = StartPage.tasks;

  /// What the app is locked with, which the lock page asks for.
  AppLock get lock => _userViewModel.appLock;

  /// How long the app can be away before it has to be unlocked again: long
  /// enough to pick a file or a photo in another app and come back.
  static const _relockAfter = Duration(minutes: 1);

  /// When the app was put away, by the phone's clock, which can be turned
  /// back; how long it's been away, by the app's own, which can't, but stops
  /// while the phone sleeps; and when, by the time since the phone started,
  /// which does neither, but has to be asked the phone for. Null while the
  /// app is open.
  DateTime? _awaySince;
  final _awayFor = Stopwatch();
  Duration? _awaySinceBoot;

  late final AuthenticationService _authService;
  final LockService _lockService;
  final DatabaseService _dbService;
  final DeviceService _deviceService;
  final VerseService _verseService;

  /// Loaded as the app unlocks, as the home page opens on the user's start
  /// page, in their theme. It also has what the app is locked with.
  final UserViewModel _userViewModel;

  /// Reads in what the app's pages show, whichever page it opens on, as
  /// the home screen's widgets and the settings show it too: see [_open].
  final Future<void> Function()? _onOpened;

  Future<void> initializeApp() async {
    // One at a time, as the fingerprint can only be asked for once at a
    // time.
    if (_status == AuthStatus.initializing) return;
    _status = AuthStatus.initializing;
    notifyListeners();
    _status = !await _unlocksAsItOpens()
        ? AuthStatus.unauthenticated
        : await _open()
        ? AuthStatus.authenticated
        // Says so, for the user to try again, rather than opening for
        // good.
        : AuthStatus.failed;
    notifyListeners();
  }

  Future<void> retryAuthentication() async {
    await initializeApp();
  }

  /// Opens the app with [password], for an app locked with one, which
  /// unlocks the database's key too. The dialogs that ask for the password
  /// again have it checked by what they ask for it for: see
  /// [AuthenticationService.passAppLock].
  Future<Result> unlock(String password) async {
    final PasswordCheck check;
    try {
      check = await _lockService.checkPassword(password);
    } catch (e) {
      return const Failure(AuthenticationService.uncheckable);
    }
    if (check.matched) {
      // The lock page stays, for the user to try again.
      if (!await _open(key: check.key)) return const Failure(_unopenable);
      _status = AuthStatus.authenticated;
      notifyListeners();
    }
    return AuthenticationService.resultOf(check);
  }

  static const _unopenable = "Couldn't open your tasks and notes. Try again.";

  /// Called as the app is put away, so that it can tell how long it's been
  /// gone when it comes back.
  void appHidden() {
    if (_status != AuthStatus.authenticated) return;
    _awaySince = DateTime.now();
    _awayFor
      ..reset()
      ..start();
    _awaySinceBoot = null;
    _deviceService.sinceBoot().then(
      (time) => _awaySinceBoot = time,
      onError: (Object e) {},
    );
  }

  /// Called as the app comes back: locks it again, if it has a lock, once
  /// it's been away for [_relockAfter].
  void appShown() {
    final awaySince = _awaySince;
    final awaySinceBoot = _awaySinceBoot;
    _awaySince = null;
    _awayFor.stop();
    if (awaySince == null ||
        _status != AuthStatus.authenticated ||
        _userViewModel.appLock == AppLock.off) {
      return;
    }
    final away = DateTime.now().difference(awaySince);
    if (away.isNegative ||
        away >= _relockAfter ||
        _awayFor.elapsed >= _relockAfter) {
      // Straight away, before the app's pages are drawn again.
      _lockAgain();
    } else if (awaySinceBoot != null) {
      // The phone's clock may have been turned back, to hide how long it's
      // been, which the time since it started shows.
      _deviceService.sinceBoot().then((now) {
        if (now - awaySinceBoot >= _relockAfter &&
            _status == AuthStatus.authenticated) {
          _lockAgain();
        }
      }, onError: (Object e) {});
    }
  }

  void _lockAgain() => initializeApp();

  /// Puts the app away from the lock page it's locked again with, leaving
  /// the pages under it as they are, unsaved writing and all.
  void putAway() => _deviceService.moveToBack().ignore();

  /// Whether the app can open straight away: when it isn't locked, or once
  /// the user's fingerprint unlocks it. An app locked with a password stays
  /// locked, for the lock page to ask for it.
  Future<bool> _unlocksAsItOpens() async {
    try {
      await _userViewModel.loadAppLock();
      return switch (lock) {
        AppLock.off => true,
        AppLock.fingerprint => await _authService.authenticateApp(),
        AppLock.password => false,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Initialization Error: $e');
      }
      return false;
    }
  }

  /// Opens the app the first time it's unlocked: the database, with [key],
  /// the one the App Lock's password unlocked, if it's locked with one, then
  /// the verses and the profile, whose start page it opens on, and then has
  /// [_onOpened] read in what the pages show. Whether it's open; not when the
  /// database won't open, as when its key is gone, which is left for the
  /// user to try again rather than opening for good.
  Future<bool> _open({String? key}) async {
    if (_opened) return true;
    try {
      await _dbService.openDb(key: key);
      await _verseService.loadVerses();
      await _userViewModel.get();
    } catch (e) {
      if (kDebugMode) {
        print("Couldn't open the app: $e");
      }
      return false;
    }
    _opened = true;
    _openedOn = _userViewModel.user.startPage;
    // Not waited for, as the page the app opens on reads in its own, nor
    // keeping the app from opening should it fail.
    if (_onOpened case final onOpened?) Future.sync(onOpened).ignore();
    return true;
  }
}
