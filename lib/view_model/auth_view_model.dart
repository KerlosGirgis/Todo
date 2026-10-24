import 'package:flutter/foundation.dart';
import 'package:todo/services/authentication_service.dart';
import 'package:todo/services/database_service.dart';
import 'package:todo/services/verse_service.dart';
import 'package:todo/view_model/user_view_model.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

class AuthViewModel with ChangeNotifier {
  AuthViewModel(this._userViewModel);

  AuthStatus _status = AuthStatus.unauthenticated;
  AuthStatus get status => _status;

  final AuthenticationService _authService = AuthenticationService();
  final DatabaseService _dbService = DatabaseService();

  /// Loaded as the app unlocks, as the home page opens on the user's start
  /// page, in their theme.
  final UserViewModel _userViewModel;

  Future<void> initializeApp() async {
    _status = AuthStatus.initializing;
    notifyListeners();
    final bool isAuthSuccess = await _authService.initializeApp();
    if (isAuthSuccess) {
      await _dbService.openDb();
      await VerseService.loadVerses();
      await _userViewModel.get();
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> retryAuthentication() async {
    await initializeApp();
  }
}
