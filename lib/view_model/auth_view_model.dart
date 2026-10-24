import 'package:flutter/foundation.dart';
import 'package:todo/core/result.dart';
import 'package:todo/models/app_lock.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/database_service.dart';
import 'package:todo/services/lock_service.dart';
import 'package:todo/services/verse_service.dart';
import 'package:todo/view_model/user_view_model.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

class AuthViewModel with ChangeNotifier {
  AuthViewModel(this._userViewModel);

  AuthStatus _status = AuthStatus.unauthenticated;
  AuthStatus get status => _status;

  /// What the app is locked with, which the lock page asks for.
  AppLock _lock = AppLock.off;
  AppLock get lock => _lock;

  final AuthenticationService _authService = AuthenticationService();
  final LockService _lockService = LockService();
  final DatabaseService _dbService = DatabaseService();

  /// Loaded as the app unlocks, as the home page opens on the user's start
  /// page, in their theme.
  final UserViewModel _userViewModel;

  Future<void> initializeApp() async {
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
      final seconds = (check.wait.inMilliseconds / 1000).ceil();
      return Failure("Too many tries. "
          "Try again in $seconds ${seconds == 1 ? "second" : "seconds"}.");
    }
    return Failure("Wrong password");
  }

  /// Whether the app can open straight away: when it isn't locked, or once
  /// the user's fingerprint unlocks it. An app locked with a password stays
  /// locked, for the lock page to ask for it.
  Future<bool> _unlocksAsItOpens() async {
    try {
      _lock = await _lockService.getLock();
      return switch (_lock) {
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
    await _dbService.openDb();
    await VerseService.loadVerses();
    await _userViewModel.get();
    _status = AuthStatus.authenticated;
    notifyListeners();
  }
}
