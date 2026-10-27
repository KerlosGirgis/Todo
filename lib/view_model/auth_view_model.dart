import 'package:flutter/foundation.dart';
import 'package:todo/core/result.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/database_service.dart';
import 'package:todo/services/device_service.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/services/verse_service.dart';
import 'package:todo/view_model/user_view_model.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

class AuthViewModel with ChangeNotifier {
  AuthViewModel(
    this._userViewModel, {
    AuthenticationService? authService,
    LockService? lockService,
    DatabaseService? databaseService,
    DeviceService? deviceService,
    VerseService? verseService,
  })  : _authService = authService ?? AuthenticationService(),
        _lockService = lockService ?? LockService(),
        _dbService = databaseService ?? DatabaseService(),
        _deviceService = deviceService ?? DeviceService(),
        _verseService = verseService ?? VerseService();

  AuthStatus _status = AuthStatus.unauthenticated;
  AuthStatus get status => _status;

  /// Whether the app has been unlocked since it started, so that its pages
  /// are open, under the lock page whenever it locks again.
  bool _opened = false;
  bool get opened => _opened;

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

  final AuthenticationService _authService;
  final LockService _lockService;
  final DatabaseService _dbService;
  final DeviceService _deviceService;
  final VerseService _verseService;

  /// Loaded as the app unlocks, as the home page opens on the user's start
  /// page, in their theme. It also has what the app is locked with.
  final UserViewModel _userViewModel;

  Future<void> initializeApp() async {
    // One at a time, as the fingerprint can only be asked for once at a
    // time.
    if (_status == AuthStatus.initializing) return;
    _status = AuthStatus.initializing;
    notifyListeners();
    if (await _unlocksAsItOpens()) {
      await _open();
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> retryAuthentication() async {
    await initializeApp();
  }

  /// Opens the app with [password], for an app locked with one.
  Future<Result> unlock(String password) async {
    final result = await checkPassword(password);
    if (result is Success) await _open();
    return result;
  }

  /// Checks [password] against the App Lock's, as the lock page does, for
  /// the dialogs that ask for it again.
  Future<Result> checkPassword(String password) async {
    final check = await _lockService.checkPassword(password);
    if (check.matched) return Success("Unlocked");
    if (check.wait > Duration.zero) {
      return Failure("Too many tries. Try again in ${_inWords(check.wait)}.");
    }
    return Failure("Wrong password");
  }

  /// [wait], rounded up to whole seconds, minutes or hours, as "1 minute".
  static String _inWords(Duration wait) {
    String count(int n, String unit) => "$n $unit${n == 1 ? "" : "s"}";
    final seconds = (wait.inMilliseconds / 1000).ceil();
    if (seconds < 60) return count(seconds, "second");
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return count(minutes, "minute");
    return count((minutes / 60).ceil(), "hour");
  }

  /// Called as the app is put away, so that it can tell how long it's been
  /// gone when it comes back.
  void appHidden() {
    if (_status != AuthStatus.authenticated) return;
    _awaySince = DateTime.now();
    _awayFor
      ..reset()
      ..start();
    _awaySinceBoot = null;
    _deviceService.sinceBoot().then((time) => _awaySinceBoot = time,
        onError: (Object e) {});
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

  Future<void> _open() async {
    if (!_opened) {
      await _dbService.openDb();
      await _verseService.loadVerses();
      await _userViewModel.get();
      _opened = true;
    }
    _status = AuthStatus.authenticated;
    notifyListeners();
  }
}
